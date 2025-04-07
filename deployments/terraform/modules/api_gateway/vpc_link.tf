# VPC Link for connecting API Gateway to private resources

# Create a Network Load Balancer (if not provided by another module)
resource "aws_lb" "internal_nlb" {
  count              = var.create_nlb ? 1 : 0
  name               = "${var.project_name}-${var.environment}-internal-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids

  enable_cross_zone_load_balancing = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-internal-nlb"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create a VPC Link to connect API Gateway to the NLB
resource "aws_api_gateway_vpc_link" "api_vpc_link" {
  name        = "${var.project_name}-${var.environment}-vpc-link"
  description = "VPC Link for ${var.project_name} ${var.environment} environment"
  target_arns = var.create_nlb ? [aws_lb.internal_nlb[0].arn] : [var.nlb_arn]
}

# Create a NLB listener for each service
resource "aws_lb_listener" "kyc_service" {
  count             = var.create_nlb ? 1 : 0
  load_balancer_arn = aws_lb.internal_nlb[0].arn
  port              = var.service_ports["kyc_service"]
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kyc_service[0].arn
  }
}

resource "aws_lb_listener" "user_service" {
  count             = var.create_nlb ? 1 : 0
  load_balancer_arn = aws_lb.internal_nlb[0].arn
  port              = var.service_ports["user_service"]
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.user_service[0].arn
  }
}

resource "aws_lb_listener" "account_service" {
  count             = var.create_nlb ? 1 : 0
  load_balancer_arn = aws_lb.internal_nlb[0].arn
  port              = var.service_ports["account_service"]
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.account_service[0].arn
  }
}

resource "aws_lb_listener" "trust_service" {
  count             = var.create_nlb ? 1 : 0
  load_balancer_arn = aws_lb.internal_nlb[0].arn
  port              = var.service_ports["trust_service"]
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.trust_service[0].arn
  }
}

resource "aws_lb_listener" "investment_service" {
  count             = var.create_nlb ? 1 : 0
  load_balancer_arn = aws_lb.internal_nlb[0].arn
  port              = var.service_ports["investment_service"]
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.investment_service[0].arn
  }
}

resource "aws_lb_listener" "document_service" {
  count             = var.create_nlb ? 1 : 0
  load_balancer_arn = aws_lb.internal_nlb[0].arn
  port              = var.service_ports["document_service"]
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.document_service[0].arn
  }
}

resource "aws_lb_listener" "notification_service" {
  count             = var.create_nlb ? 1 : 0
  load_balancer_arn = aws_lb.internal_nlb[0].arn
  port              = var.service_ports["notification_service"]
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.notification_service[0].arn
  }
}

# Create target groups for each service
resource "aws_lb_target_group" "kyc_service" {
  count       = var.create_nlb ? 1 : 0
  name        = "${var.project_name}-${var.environment}-kyc-tg"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/health"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "user_service" {
  count       = var.create_nlb ? 1 : 0
  name        = "${var.project_name}-${var.environment}-user-tg"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/health"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "account_service" {
  count       = var.create_nlb ? 1 : 0
  name        = "${var.project_name}-${var.environment}-account-tg"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/health"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "trust_service" {
  count       = var.create_nlb ? 1 : 0
  name        = "${var.project_name}-${var.environment}-trust-tg"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/health"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "investment_service" {
  count       = var.create_nlb ? 1 : 0
  name        = "${var.project_name}-${var.environment}-investment-tg"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/health"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "document_service" {
  count       = var.create_nlb ? 1 : 0
  name        = "${var.project_name}-${var.environment}-document-tg"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/health"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "notification_service" {
  count       = var.create_nlb ? 1 : 0
  name        = "${var.project_name}-${var.environment}-notification-tg"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/health"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}