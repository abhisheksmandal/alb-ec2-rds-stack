locals {
  redirect_http        = var.enable_https && var.redirect_http_to_https
  default_service      = one([for s in var.services : s if s.is_default])
  service_names        = [for s in var.services : s.name]
  host_routed_services = { for s in var.services : s.name => s if length(s.host_headers) > 0 }
}

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Allow inbound HTTP/HTTPS from the internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from allowed CIDRs"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.alb_allowed_cidrs
  }

  ingress {
    description = "HTTPS from allowed CIDRs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.alb_allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg"
  })
}

resource "aws_lb" "main" {
  name                       = "${var.name_prefix}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb"
  })
}

# One target group per service (e.g. frontend on :3000, backend on :4000),
# all fronted by the same ALB via host-based listener rules below.
resource "aws_lb_target_group" "service" {
  for_each = { for s in var.services : s.name => s }

  name     = "${var.name_prefix}-${each.value.name}-tg"
  port     = each.value.port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  deregistration_delay = each.value.deregistration_delay

  health_check {
    protocol            = "HTTP"
    path                = each.value.health_check_path
    port                = "traffic-port"
    healthy_threshold   = each.value.health_check_healthy_threshold
    unhealthy_threshold = each.value.health_check_unhealthy_threshold
    timeout             = each.value.health_check_timeout
    interval            = each.value.health_check_interval
    matcher             = each.value.health_check_matcher
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${each.value.name}-tg"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = local.redirect_http ? "redirect" : "forward"
    target_group_arn = local.redirect_http ? null : aws_lb_target_group.service[local.default_service.name].arn

    dynamic "redirect" {
      for_each = local.redirect_http ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}

# Only needed when the HTTP listener still forwards traffic itself — once it
# redirects everything to HTTPS, host-based routing happens on that listener.
resource "aws_lb_listener_rule" "http" {
  for_each = local.redirect_http ? {} : local.host_routed_services

  listener_arn = aws_lb_listener.http.arn
  priority     = index(local.service_names, each.key) + 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[each.key].arn
  }

  condition {
    host_header {
      values = each.value.host_headers
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[local.default_service.name].arn
  }
}

# Extra certificates for domains not covered by the primary certificate_arn
# (SNI — the ALB picks the right cert per Host header automatically).
resource "aws_lb_listener_certificate" "https_extra" {
  for_each = var.enable_https ? toset(var.additional_certificate_arns) : toset([])

  listener_arn    = aws_lb_listener.https[0].arn
  certificate_arn = each.value
}

resource "aws_lb_listener_rule" "https" {
  for_each = var.enable_https ? local.host_routed_services : {}

  listener_arn = aws_lb_listener.https[0].arn
  priority     = index(local.service_names, each.key) + 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[each.key].arn
  }

  condition {
    host_header {
      values = each.value.host_headers
    }
  }
}
