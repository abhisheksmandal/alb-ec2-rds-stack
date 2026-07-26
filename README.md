# alb-ec2-rds-stack

Modular Terraform stack that provisions a VPC, an Application Load Balancer
with host-based routing, a fleet of EC2 instances, and a PostgreSQL RDS
instance — sized for a `dev` environment but structured to add more
environments later.

## Architecture

```
Internet
   │
   ▼
  ALB (public subnets)
   │  host-based routing: app.example.com -> frontend:3000
   │                       api.example.com -> backend:4000
   ▼
 EC2 instances (public or private subnets)
   │  each instance runs every service (frontend + backend)
   ▼
 RDS PostgreSQL (private subnets, EC2 security group only)
```

- **networking** — VPC, public/private subnets across `az_count` AZs, optional NAT Gateway(s)
- **alb** — Application Load Balancer, target groups per service, host-based listener rules, optional HTTPS/SNI
- **compute** — EC2 instances (public or private), security group scoped to the ALB and the app ports, optional SSM instance profile
- **database** — RDS PostgreSQL in private subnets, master password managed via Secrets Manager (`manage_master_user_password`), security group scoped to the EC2 instances

Modules live in `modules/`; the composed `dev` environment lives in
`environments/dev`. Application deployment onto the EC2 instances is a manual
step — see [RUNBOOK.md](RUNBOOK.md) for the full provisioning-to-deployment
walkthrough.

## Prerequisites

- Terraform >= 1.x, AWS provider ~> 5.100 (see `.terraform.lock.hcl`)
- AWS credentials configured (`aws configure` or equivalent) with permission to manage VPC/EC2/ELB/RDS/Secrets Manager
- An existing AMI ID for the target region (`ami_id` has no default)

## Usage

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: ami_id, ssh_allowed_cidr, ec2_subnet_type, etc.

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Right after apply, ALB target groups will show unhealthy — that's expected
until the app is deployed onto the instances. Continue with
[RUNBOOK.md](RUNBOOK.md) for the rest of the steps (retrieving DB
credentials, deploying the app, verifying target health, DNS, HTTPS).

## Key variables

| Variable | Default | Notes |
|---|---|---|
| `ami_id` | — | required, no default |
| `ssh_allowed_cidr` | — | required, only used when `ec2_subnet_type = "public"` |
| `ec2_subnet_type` | `"private"` | `"public"` or `"private"` |
| `enable_nat_gateway` | `false` | required for outbound internet if instances are private |
| `enable_ssm` | `false` | set `true` to reach private instances via SSM instead of SSH |
| `services` | frontend (:3000) + backend (:4000) | host-based routing config for the ALB |
| `enable_https` | `false` | requires `certificate_arn` |
| `db_instance_class` | `db.t3.micro` | bump for staging/prod |
| `db_multi_az` | `false` | set `true` for prod |

Full variable list with descriptions: `environments/dev/variables.tf`.
Example tfvars with prod-sizing comments: `environments/dev/terraform.tfvars.example`.

## Outputs

`alb_dns_name`, `alb_target_group_arns`, `rds_endpoint`,
`rds_master_user_secret_arn`, `vpc_id`, `public_subnet_ids`,
`private_subnet_ids`, `ec2_instance_ids`, `ec2_instance_private_ips`,
`ec2_instance_public_ips` — see `environments/dev/outputs.tf`.

## Notes

- The RDS master password is never set in Terraform — it's generated and
  stored in Secrets Manager. Retrieve it with the AWS CLI (see RUNBOOK Step 2).
- RDS is only reachable from the EC2 instances' security group — not from
  your local machine.
- There's no CI/CD wired up yet; application deployment onto EC2 is manual,
  per-instance (see RUNBOOK Step 4 and "Redeploying app changes").
