locals {
  cidr      = format("%s/24", var.nw_addr)
  k3s_sg    = ["k3s-server-sg", "k3s-agent-sg"]
  server    = ["k3s-server01"]
  agent     = ["k3s-agent01", "k3s-agent02"]
  instances = concat(local.server, local.agent)
}

// VPC
resource "aws_vpc" "vpc" {
  cidr_block           = local.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "k3s-vpc"
  }
}

// Subnet
resource "aws_subnet" "subnet" {
  count      = min(3, length(local.agent))
  cidr_block = cidrsubnet(local.cidr, 4, count.index)
  vpc_id     = aws_vpc.vpc.id

  tags = {
    Name = format("k3s-subnet-0%d", count.index + 1)
  }
}

// Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "k3s-igw"
  }
}

// Route Table
resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "k3s-rtb"
  }
}

resource "aws_route" "route" {
  route_table_id         = aws_route_table.rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "route_assoc" {
  count          = min(3, length(local.agent))
  route_table_id = aws_route_table.rtb.id
  subnet_id      = aws_subnet.subnet[count.index].id
}

// Route53
data "aws_route53_zone" "public" {
  name = var.domain
}

resource "aws_route53_zone" "private" {
  name = var.domain

  vpc {
    vpc_id = aws_vpc.vpc.id
  }
}

// ACM
resource "aws_route53_record" "acm" {
  for_each = {
    for dvo in aws_acm_certificate.acm.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  zone_id         = data.aws_route53_zone.public.zone_id
  ttl             = 300
  records         = [each.value.record]
}

resource "aws_acm_certificate" "acm" {
  domain_name               = var.domain
  subject_alternative_names = [format("*.%s", var.domain)]
  validation_method         = "DNS"

  tags = {
    Name = var.domain
  }
}

resource "aws_acm_certificate_validation" "acm" {
  certificate_arn         = aws_acm_certificate.acm.arn
  validation_record_fqdns = [for record in aws_route53_record.acm : record.fqdn]
}

// EC2
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "block-device-mapping.volume-type"
    values = ["gp2"]
  }
}

resource "aws_key_pair" "k3s" {
  key_name   = "k3s-key"
  public_key = var.public_key
}

resource "aws_instance" "instance" {
  count                  = length(local.instances)
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.k3s.id
  vpc_security_group_ids = can(regex("server", element(local.instances, count.index))) ? [aws_security_group.k3s[index(local.k3s_sg, "k3s-server-sg")].id] : [aws_security_group.k3s[index(local.k3s_sg, "k3s-agent-sg")].id]
  subnet_id              = aws_subnet.subnet[count.index % min(3, length(local.agent))].id

  root_block_device {
    volume_type = "gp2"
    volume_size = 32
  }

  tags = {
    Name = element(local.instances, count.index)
  }
}

resource "aws_eip" "k3s" {
  count = length(local.server)
  vpc   = true

  tags = {
    Name = format("%s-eip", element(local.server, count.index))
  }
}

resource "aws_eip_association" "k3s" {
  count         = length(local.server)
  instance_id   = aws_instance.instance[index(local.instances, element(local.server, count.index))].id
  allocation_id = aws_eip.k3s[count.index].id
}

// EC2 Security Group
resource "aws_security_group" "k3s" {
  count  = length(local.k3s_sg)
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = element(local.k3s_sg, count.index)
  }
}

resource "aws_security_group_rule" "k3s_out" {
  count             = length(local.k3s_sg)
  security_group_id = aws_security_group.k3s[count.index].id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
}

// K3s Server Inbound Rule
resource "aws_security_group_rule" "server_ssh" {
  from_port         = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.k3s[index(local.k3s_sg, "k3s-server-sg")].id
  to_port           = 22
  type              = "ingress"
  cidr_blocks       = var.allow_ip
}

resource "aws_security_group_rule" "server_https" {
  from_port         = 6443
  protocol          = "tcp"
  security_group_id = aws_security_group.k3s[index(local.k3s_sg, "k3s-server-sg")].id
  to_port           = 6443
  type              = "ingress"
  cidr_blocks       = var.allow_ip
}

resource "aws_security_group_rule" "server_agent" {
  from_port                = 0
  protocol                 = "all"
  source_security_group_id = aws_security_group.k3s[index(local.k3s_sg, "k3s-agent-sg")].id
  to_port                  = 65535
  type                     = "ingress"
  security_group_id        = aws_security_group.k3s[index(local.k3s_sg, "k3s-server-sg")].id
}

resource "aws_security_group_rule" "server_self" {
  from_port         = 0
  protocol          = "all"
  security_group_id = aws_security_group.k3s[index(local.k3s_sg, "k3s-server-sg")].id
  to_port           = 65535
  type              = "ingress"
  self              = true
}

// K3s Agent Inbound Rule
resource "aws_security_group_rule" "agent_server" {
  from_port                = 0
  protocol                 = "all"
  security_group_id        = aws_security_group.k3s[index(local.k3s_sg, "k3s-agent-sg")].id
  to_port                  = 65535
  type                     = "ingress"
  source_security_group_id = aws_security_group.k3s[index(local.k3s_sg, "k3s-server-sg")].id
}

resource "aws_security_group_rule" "agent_self" {
  from_port         = 0
  protocol          = "all"
  security_group_id = aws_security_group.k3s[index(local.k3s_sg, "k3s-agent-sg")].id
  to_port           = 65535
  type              = "ingress"
  self              = true
}

// EC2 Record
resource "aws_route53_record" "k3s_server" {
  count   = length(local.server)
  name    = element(local.server, count.index)
  type    = "A"
  zone_id = data.aws_route53_zone.public.zone_id
  ttl     = 300
  records = [aws_eip.k3s[count.index].public_ip]
}

resource "aws_route53_record" "k3s_agent" {
  count   = length(local.agent)
  name    = element(local.agent, count.index)
  type    = "A"
  zone_id = aws_route53_zone.private.zone_id
  ttl     = 300
  records = [aws_instance.instance[index(local.instances, element(local.agent, count.index))].private_ip]
}

// ALB
resource "aws_alb" "alb" {
  name                       = "k3s-alb"
  subnets                    = aws_subnet.subnet.*.id
  security_groups            = [aws_security_group.alb.id]
  internal                   = false
  enable_deletion_protection = false
}

resource "aws_alb_listener" "https" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2015-05"
  certificate_arn   = aws_acm_certificate.acm.arn

  default_action {
    target_group_arn = aws_alb_target_group.tg.arn
    type             = "forward"
  }
}

resource "aws_alb_listener_rule" "http" {
  listener_arn = aws_alb_listener.https.arn

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = ["*"]
    }
  }
}

resource "aws_alb_target_group" "tg" {
  name              = "k3s-tg"
  port              = var.node_port
  protocol          = "HTTP"
  proxy_protocol_v2 = false
  vpc_id            = aws_vpc.vpc.id

  health_check {
    interval            = 300
    path                = "/"
    port                = var.node_port
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = 302
  }
}

resource "aws_lb_target_group_attachment" "tg" {
  count            = length(local.agent)
  target_group_arn = aws_alb_target_group.tg.arn
  target_id        = aws_instance.instance[count.index].id
  port             = var.node_port
}

resource "aws_security_group" "alb" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "k3s-alb-sg"
  }
}

resource "aws_security_group_rule" "alb_out" {
  security_group_id = aws_security_group.alb.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "https" {
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  to_port           = 443
  type              = "ingress"
  cidr_blocks       = var.allow_ip
}

resource "aws_security_group_rule" "http" {
  from_port         = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  to_port           = 80
  type              = "ingress"
  cidr_blocks       = var.allow_ip
}

resource "aws_security_group_rule" "agent_alb" {
  from_port                = var.node_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.k3s[index(local.k3s_sg, "k3s-agent-sg")].id
  to_port                  = var.node_port
  type                     = "ingress"
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_route53_record" "alb" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = aws_alb.alb.dns_name
    zone_id                = aws_alb.alb.zone_id
    evaluate_target_health = true
  }
}
