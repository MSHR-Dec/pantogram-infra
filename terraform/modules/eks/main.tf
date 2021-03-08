// EKS
resource "aws_eks_cluster" "cluster" {
  name     = format("%s-%s-cluster", var.env, var.prefix)
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids = var.subnet_ids
    security_group_ids = [
      aws_security_group.cluster-sg.id
    ]
  }

  tags = {
    Name = format("%s-%s-cluster", var.env, var.prefix)
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy,
  ]
}

resource "aws_eks_node_group" "node" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = format("%s-%s-node", var.env, var.prefix)
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = var.subnet_ids
  capacity_type   = var.eks_capacity_type
  instance_types  = var.eks_instance_types

  scaling_config {
    desired_size = var.eks_desired_size
    max_size     = var.eks_max_size
    min_size     = var.eks_min_size
  }

  launch_template {
    id      = aws_launch_template.lt.id
    version = aws_launch_template.lt.latest_version
  }

  tags = {
    Name = format("%s-%s-node", var.env, var.prefix)
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_node_cni_policy,
    aws_iam_role_policy_attachment.eks_node_ecr_policy,
    aws_iam_role_policy_attachment.eks_node_autoscaler_policy,
  ]
}

resource "aws_launch_template" "lt" {
  name_prefix = format("%s-%s-eks-lt", var.env, var.prefix)
  vpc_security_group_ids = [
    aws_security_group.node-sg.id
  ]

  tags = {
    Name = format("%s-%s-eks-lt", var.env, var.prefix)
  }
}

// IAM for EKS Cluster
data "aws_iam_policy_document" "eks_cluster" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["eks.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = format("%s-%s-cluster", var.env, var.prefix)
  assume_role_policy = data.aws_iam_policy_document.eks_cluster.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

// IAM for EKS Node
data "aws_iam_policy_document" "eks_node" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_node" {
  name               = format("%s-%s-node", var.env, var.prefix)
  assume_role_policy = data.aws_iam_policy_document.eks_node.json
}

resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_node_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_node_alb_policy" {
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_node_autoscaler_policy" {
  policy_arn = aws_iam_policy.eks_node_autoscaler_policy.arn
  role       = aws_iam_role.eks_node.name
}

data "aws_iam_policy_document" "eks_node_autoscaler_policy" {
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "eks_node_autoscaler_policy" {
  name   = format("%s-%s-eks-node-autoscaler-policy", var.env, var.prefix)
  policy = data.aws_iam_policy_document.eks_node_autoscaler_policy.json
}

// Security Group for Cluster
resource "aws_security_group" "cluster-sg" {
  name   = format("%s-%s-sg-cluster", var.env, var.prefix)
  vpc_id = var.vpc_id

  tags = {
    Name = format("%s-%s-sg-cluster", var.env, var.prefix)
  }
}

resource "aws_security_group_rule" "cluster_443_node" {
  security_group_id        = aws_security_group.cluster-sg.id
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node-sg.id
}

resource "aws_security_group_rule" "cluster_out" {
  security_group_id = aws_security_group.cluster-sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
}

// Security Group for Node
resource "aws_security_group" "node-sg" {
  name   = format("%s-%s-sg-node", var.env, var.prefix)
  vpc_id = var.vpc_id

  tags = {
    Name                                                             = format("%s-%s-sg-node", var.env, var.prefix)
    format("kubernetes.io/cluster/%s", aws_eks_cluster.cluster.name) = "owned"
  }
}

resource "aws_security_group_rule" "node_any_cluster" {
  security_group_id        = aws_security_group.node-sg.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster-sg.id
}

resource "aws_security_group_rule" "node_any_self" {
  security_group_id = aws_security_group.node-sg.id
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  self              = true
}

resource "aws_security_group_rule" "node_out" {
  security_group_id = aws_security_group.node-sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
}
