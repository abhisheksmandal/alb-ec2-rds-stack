# Deployment Runbook — dev environment

What Terraform provisions vs. what you do by hand, and the order to do it in.
The application lives on GitHub with no CI/CD wired up yet, so app deployment
onto the EC2 instances is a manual, per-instance step.

## At a glance

| # | Step | Where | Tool |
|---|------|-------|------|
| 1 | Provision infrastructure | Local machine | Terraform |
| 2 | Retrieve DB credentials | Local machine | AWS CLI |
| 3 | Log into each EC2 instance | EC2 | SSH or SSM |
| 4 | Clone repo, install deps, start frontend (:3000) + backend (:4000) | EC2 (both instances) | git, npm, pm2/systemd |
| 5 | Verify ALB target health | Local machine | AWS CLI / console |
| 6 | Functional test via ALB (before DNS exists) | Local machine | curl with Host header |
| 7 | Point domains at the ALB | DNS provider | manual |
| 8 | (Optional) Enable HTTPS | Local machine + DNS provider | ACM + Terraform |

Infrastructure (step 1) and application setup (steps 2–4) are independent
concerns run in different places — Terraform never touches the app, and the
app setup never touches AWS resources beyond reading the DB secret and
connecting to RDS.

---

## Step 1 — Provision infrastructure with Terraform

```bash
cd environments/dev
terraform init
terraform plan -out=tfplan   # review before applying
terraform apply tfplan
```

Capture the outputs — you'll need them in later steps:

```bash
terraform output alb_dns_name
terraform output ec2_instance_ids
terraform output ec2_instance_private_ips
terraform output ec2_instance_public_ips        # only populated if ec2_subnet_type = "public"
terraform output rds_endpoint
terraform output rds_master_user_secret_arn
terraform output alb_target_group_arns
```

**Expected state right after apply:** the ALB's target groups will show
**unhealthy** for both `frontend` and `backend`. That's normal — nothing is
listening on ports 3000/4000 yet. They turn healthy once Step 4 is done.

---

## Step 2 — Retrieve the RDS master credentials

The DB password was never set in Terraform — AWS generated and stored it in
Secrets Manager (`manage_master_user_password`). Pull it from there:

```bash
aws secretsmanager get-secret-value \
  --secret-id "$(terraform output -raw rds_master_user_secret_arn)" \
  --region ap-south-1 \
  --query SecretString --output text | jq
```

This returns `{"username": "...", "password": "...", "host": "...", "port": 5432, ...}`.
The backend app needs these (plus `terraform output -raw rds_endpoint`) as
its DB connection config — export/inject them as environment variables in
Step 4, don't hardcode them into the repo.

---

## Step 3 — Log into each EC2 instance

How you get in depends on `ec2_subnet_type`:

**If `ec2_subnet_type = "public"`:**
```bash
ssh -i <your-key.pem> ec2-user@$(terraform output -json ec2_instance_public_ips | jq -r '.[0]')
```
(SSH is only open from the CIDR you set in `ssh_allowed_cidr`.)

**If `ec2_subnet_type = "private"`:** there's no SSH path. Use SSM Session
Manager instead — requires `enable_ssm = true` in your tfvars, and either
`enable_nat_gateway = true` or VPC interface endpoints for SSM (private
instances with no NAT can't reach SSM's endpoints either):
```bash
aws ssm start-session --target <instance-id> --region ap-south-1
```

You must repeat Step 4 on **both** instances — the ALB round-robins between
them and there's no shared filesystem or auto-provisioning between the two.

---

## Step 4 — Manual application setup (per instance)

Run this on each of the 2 instances:

```bash
# Runtime (adjust for your AMI / actual stack — example assumes Node.js on Amazon Linux)
sudo dnf install -y git nodejs   # or: curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -; sudo dnf install -y nodejs

# Get the app
git clone https://github.com/<org>/<repo>.git
cd <repo>

# Frontend — must listen on 0.0.0.0:3000, not 127.0.0.1:3000
cd frontend
npm install
npm run build   # if applicable
PORT=3000 HOST=0.0.0.0 pm2 start npm --name frontend -- start

# Backend — must listen on 0.0.0.0:4000
cd ../backend
npm install
export DB_HOST=<rds_endpoint host, no port>
export DB_PORT=5432
export DB_USER=<from Secrets Manager>
export DB_PASSWORD=<from Secrets Manager>
export DB_NAME=appdb
PORT=4000 HOST=0.0.0.0 pm2 start npm --name backend -- start

pm2 save   # survive reboot; pair with `pm2 startup` once per instance
```

Use whatever process manager/runtime actually matches the app (pm2, systemd
unit, Docker, etc.) — the two hard requirements from the infrastructure side
are: **bind to `0.0.0.0`** (not localhost) and **listen on the exact ports**
wired into `services` in `environments/dev/variables.tf` (3000 and 4000).

Verify locally before moving on:
```bash
curl -sf http://localhost:3000/ && echo frontend OK
curl -sf http://localhost:4000/ && echo backend OK
```

---

## Step 5 — Verify ALB target health

```bash
for tg in $(terraform output -json alb_target_group_arns | jq -r '.[]'); do
  aws elbv2 describe-target-health --target-group-arn "$tg" --region ap-south-1
done
```
Wait until both targets in both target groups show `"State": "healthy"`.
Health checks hit `health_check_path` (default `/`) on each service's port.

---

## Step 6 — Functional test via the ALB (before DNS exists)

Use the `Host` header to simulate the real domains against the raw ALB DNS name:

```bash
curl -H "Host: app.example.com" http://$(terraform output -raw alb_dns_name)/
curl -H "Host: api.example.com" http://$(terraform output -raw alb_dns_name)/
```

---

## Step 7 — Point domains at the ALB (manual, in your DNS provider)

Not managed by this Terraform config. In whichever DNS provider hosts the
zones:
```
app.example.com   CNAME/ALIAS  -> <alb_dns_name>
api.example.com   CNAME/ALIAS  -> <alb_dns_name>
```
Wait for propagation, then retest with the real domains (no `Host` header trick needed).

---

## Step 8 — (Optional) Enable HTTPS

Do this **after** infra is up and working over HTTP, or fold it into Step 1 —
either order works, but the ACM certificate must already be **issued and
validated** before Terraform references its ARN.

1. Request an ACM certificate in `ap-south-1` covering `app.example.com` (and
   `api.example.com`, either on the same cert via SAN or a second cert).
2. Complete DNS validation for the cert (add the CNAME records ACM gives you,
   in the same DNS provider as Step 7).
3. In `terraform.tfvars`:
   ```hcl
   enable_https                = true
   certificate_arn             = "arn:aws:acm:ap-south-1:...:certificate/..."
   additional_certificate_arns = ["arn:aws:acm:ap-south-1:...:certificate/..."]  # if using a second cert
   redirect_http_to_https      = true
   ```
4. `terraform plan` / `terraform apply` again — adds the 443 listener and
   listener rules; does not touch the running EC2 instances or RDS.
5. Retest with `https://`.

---

## Redeploying app changes (until CI/CD exists)

Repeat on **both** instances, since there's no shared deployment mechanism:
```bash
cd <repo>
git pull
npm install   # if dependencies changed
pm2 restart frontend   # or backend
```
This is manual and easy to let drift between the two instances — worth
automating (user-data, an AMI-baking pipeline, or CodeDeploy) once this
becomes routine.

---

## Gotchas

- **Bind to `0.0.0.0`, not `127.0.0.1`.** The security group already
  restricts inbound 3000/4000 to the ALB's security group only — but if the
  app only listens on loopback, neither the ALB nor anything else on the
  instance can reach it, and health checks will never pass.
- **No outbound internet ⇒ Step 4 can't run at all.** If
  `ec2_subnet_type = "private"` and `enable_nat_gateway = false`, the
  instances can't `git clone`, `npm install`, or reach Secrets Manager —
  this is the exact combination the Terraform `check` block warns about.
- **RDS isn't reachable from your laptop.** It's in private subnets with a
  security group that only allows the EC2 security group on 5432. Any DB
  setup/migrations must run from the EC2 instances themselves (Step 3/4),
  not from your local machine.
