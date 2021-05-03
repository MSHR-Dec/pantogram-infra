locals {
  network_modifier = ["public", "private"]
  server           = ["k3s-server01"]
  agent            = ["k3s-agent01", "k3s-agent02"]
  instances        = concat(local.server, local.agent)
}

// VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "k3s-vpc"
  }
}

// Subnet
resource "aws_subnet" "subnet" {
  count      = length(local.network_modifier)
  cidr_block = cidrsubnet(var.cidr, 8, count.index)
  vpc_id     = aws_vpc.vpc.id

  tags = {
    Name = format("k3s-%s", element(local.network_modifier, count.index))
  }
}

// Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "k3s-igw"
  }
}

// Nat Gateway
resource "aws_eip" "nat" {
  vpc = true

  tags = {
    Name = "k3s-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.subnet[index(local.network_modifier, "public")].id

  tags = {
    Name = "k3s-nat"
  }
}

// Route Table
resource "aws_route_table" "rtb" {
  count  = length(local.network_modifier)
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = format("k3s-%s", element(local.network_modifier, count.index))
  }
}

resource "aws_route" "route" {
  count                  = length(local.network_modifier)
  route_table_id         = aws_route_table.rtb[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = element(local.network_modifier, count.index) == "public" ? aws_internet_gateway.igw.id : null
  nat_gateway_id         = element(local.network_modifier, count.index) == "private" ? aws_nat_gateway.nat.id : null
}

resource "aws_route_table_association" "route_assoc" {
  count          = length(local.network_modifier)
  route_table_id = aws_route_table.rtb[count.index].id
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
  vpc_security_group_ids = can(regex("server", element(local.instances, count.index))) ? [aws_security_group.k3s[index(local.network_modifier, "public")].id] : [aws_security_group.k3s[index(local.network_modifier, "private")].id]
  subnet_id              = can(regex("server", element(local.instances, count.index))) ? aws_subnet.subnet[index(local.network_modifier, "public")].id : aws_subnet.subnet[index(local.network_modifier, "private")].id

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
  count  = length(local.network_modifier)
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = element(local.network_modifier, count.index) == "public" ? "k3s-server-sg" : "k3s-agent-sg"
  }
}

resource "aws_security_group_rule" "k3s_out" {
  count             = length(local.network_modifier)
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
  security_group_id = aws_security_group.k3s[index(local.network_modifier, "public")].id
  to_port           = 22
  type              = "ingress"
  cidr_blocks       = var.allow_ip
}

resource "aws_security_group_rule" "server_https" {
  from_port         = 6443
  protocol          = "tcp"
  security_group_id = aws_security_group.k3s[index(local.network_modifier, "public")].id
  to_port           = 6443
  type              = "ingress"
  cidr_blocks       = var.allow_ip
}

resource "aws_security_group_rule" "server_agent" {
  from_port                = 0
  protocol                 = "all"
  source_security_group_id = aws_security_group.k3s[index(local.network_modifier, "private")].id
  to_port                  = 65535
  type                     = "ingress"
  security_group_id        = aws_security_group.k3s[index(local.network_modifier, "public")].id
}

resource "aws_security_group_rule" "server_self" {
  from_port         = 0
  protocol          = "all"
  security_group_id = aws_security_group.k3s[index(local.network_modifier, "public")].id
  to_port           = 65535
  type              = "ingress"
  self              = true
}

// K3s Agent Inbound Rule
resource "aws_security_group_rule" "agent_server" {
  from_port                = 0
  protocol                 = "all"
  security_group_id        = aws_security_group.k3s[index(local.network_modifier, "private")].id
  to_port                  = 65535
  type                     = "ingress"
  source_security_group_id = aws_security_group.k3s[index(local.network_modifier, "public")].id
}

resource "aws_security_group_rule" "agent_self" {
  from_port         = 0
  protocol          = "all"
  security_group_id = aws_security_group.k3s[index(local.network_modifier, "private")].id
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
