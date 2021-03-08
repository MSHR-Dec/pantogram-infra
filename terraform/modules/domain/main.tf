// Hosted zone
data "aws_route53_zone" "public" {
  name = var.domain
}

resource "aws_route53_zone" "private" {
  name = var.domain

  vpc {
    vpc_id = var.vpc_id
  }
}

// Record
resource "aws_route53_record" "acm" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
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

// ACM
resource "aws_acm_certificate" "cert" {
  domain_name               = var.domain
  subject_alternative_names = [format("*.%s", var.domain)]
  validation_method         = "DNS"

  tags = {
    Name = var.domain
  }
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.acm : record.fqdn]
}
