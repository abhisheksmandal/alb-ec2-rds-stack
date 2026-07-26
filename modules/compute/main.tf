locals {
  ec2_subnet_ids = var.ec2_subnet_type == "public" ? var.public_subnet_ids : var.private_subnet_ids
}

resource "aws_iam_role" "ssm" {
  count = var.enable_ssm ? 1 : 0
  name  = "${var.name_prefix}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ec2-ssm-role"
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.enable_ssm ? 1 : 0
  role       = aws_iam_role.ssm[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  count = var.enable_ssm ? 1 : 0
  name  = "${var.name_prefix}-ec2-ssm-profile"
  role  = aws_iam_role.ssm[0].name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ec2-ssm-profile"
  })
}

# Flags the case where private instances would have no outbound path at all.
# Non-blocking: surfaces as a warning during plan/apply instead of silently
# deploying instances that can't reach package repos or external APIs.
check "ec2_outbound_connectivity" {
  assert {
    condition     = !(var.ec2_subnet_type == "private" && var.enable_nat_gateway == false)
    error_message = "ec2_subnet_type = \"private\" with enable_nat_gateway = false: EC2 instances will have NO outbound internet access (no package updates, no external API calls). Set enable_nat_gateway = true, or set ec2_subnet_type = \"public\" if outbound access is required."
  }
}

resource "aws_security_group" "ec2" {
  name        = "${var.name_prefix}-ec2-sg"
  description = "Allow app-port traffic from the ALB only, plus optional SSH"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.app_ports
    content {
      description     = "App port ${ingress.value} from ALB"
      from_port       = ingress.value
      to_port         = ingress.value
      protocol        = "tcp"
      security_groups = [var.alb_security_group_id]
    }
  }

  dynamic "ingress" {
    for_each = var.ec2_subnet_type == "public" ? [1] : []
    content {
      description = "SSH from allowed CIDR"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.ssh_allowed_cidr]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ec2-sg"
  })
}

resource "aws_instance" "app" {
  count                       = var.instance_count
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = local.ec2_subnet_ids[count.index % length(local.ec2_subnet_ids)]
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = var.ec2_subnet_type == "public"
  key_name                    = var.key_name != "" ? var.key_name : null
  iam_instance_profile        = var.enable_ssm ? aws_iam_instance_profile.ssm[0].name : null

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-app-${count.index}"
  })
}
