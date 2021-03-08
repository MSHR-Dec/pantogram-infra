provider "kubernetes" {
  host                   = var.eks_endpoint
  cluster_ca_certificate = base64decode(var.eks_cacert)
  token                  = var.eks_token
}

data "aws_region" "current" {}

// Namespace
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

// AWS ALB Ingress Controller
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  automount_service_account_token = true

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.eks_oidc.arn
    }

    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
  }
}

resource "null_resource" "cert_manager" {
  triggers = {}

  provisioner "local-exec" {
    command = <<EOC
kubectl apply \
  --kubeconfig=${local_file.kube_config.filename} \
  --validate=false \
  -f https://github.com/jetstack/cert-manager/releases/download/${var.certmanager_version}/cert-manager.yaml
EOC
  }

  depends_on = [
    kubernetes_namespace.cert_manager,
    aws_iam_role.eks_oidc,
    kubernetes_service_account.aws_load_balancer_controller
  ]
}

resource "local_file" "aws_load_balancer_controller" {
  filename = "${path.module}/templates/aws_alb_ingress_controller.yaml"
  content = templatefile("${path.module}/templates/aws_alb_ingress_controller.yaml.tmpl", {
    alb_version = var.alb_version
    eks_name    = var.eks_name
    region      = data.aws_region.current.name
    vpc_id      = var.vpc_id
  })
}

resource "null_resource" "aws_load_balancer_controller" {
  triggers = {
    manifest = filesha256(local_file.aws_load_balancer_controller.filename)
  }

  provisioner "local-exec" {
    command = <<EOC
kubectl apply \
  --kubeconfig=${local_file.kube_config.filename} \
  -f ${local_file.aws_load_balancer_controller.filename}
EOC
  }

  depends_on = [
    null_resource.cert_manager
  ]
}

// IAM for AWS ALB Ingress Controller
resource "aws_iam_openid_connect_provider" "eks_oidc" {
  url = var.eks_oidc

  client_id_list = [
    "sts.amazonaws.com"
  ]
  thumbprint_list = [var.thumbprint]
}

data "aws_iam_policy_document" "eks_oidc" {
  statement {
    effect = "Allow"
    principals {
      identifiers = [aws_iam_openid_connect_provider.eks_oidc.arn]
      type        = "Federated"
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = format("%s:sub", replace(aws_iam_openid_connect_provider.eks_oidc.url, "https://", ""))
      values = [
        format("system:serviceaccount:%s:%s", "kube-system", "aws-load-balancer-controller")
      ]
    }
  }
}

resource "aws_iam_role" "eks_oidc" {
  name               = format("%s-%s-eks-oidc", var.env, var.prefix)
  assume_role_policy = data.aws_iam_policy_document.eks_oidc.json
}

resource "aws_iam_role_policy_attachment" "alb_management" {
  policy_arn = aws_iam_policy.alb_management.arn
  role       = aws_iam_role.eks_oidc.name
}

data "aws_iam_policy_document" "alb_management" {
  statement {
    actions = [
      "acm:DescribeCertificate",
      "acm:ListCertificates",
      "acm:GetCertificate",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVpcs",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:RevokeSecurityGroupIngress",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:SetWebACL",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "iam:CreateServiceLinkedRole",
      "iam:GetServerCertificate",
      "iam:ListServerCertificates",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "cognito-idp:DescribeUserPoolClient",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "tag:GetResources",
      "tag:TagResources",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "waf:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:GetWebACL",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "shield:DescribeProtection",
      "shield:GetSubscriptionState",
      "shield:DeleteProtection",
      "shield:CreateProtection",
      "shield:DescribeSubscription",
      "shield:ListProtections"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "alb_management" {
  name   = format("%s-%s-alb-management", var.env, var.prefix)
  policy = data.aws_iam_policy_document.alb_management.json
}
