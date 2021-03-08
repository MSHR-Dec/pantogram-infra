module "network" {
  source     = "../../modules/network"
  env        = var.env
  prefix     = var.prefix
  cidr_block = var.cidr_block
  subnets    = var.subnets
}

module "domain" {
  source = "../../modules/domain"
  domain = var.domain
  vpc_id = module.network.vpc_id
}

module "eks" {
  source             = "../../modules/eks"
  env                = var.env
  prefix             = var.prefix
  eks_capacity_type  = var.eks_capacity_type
  eks_desired_size   = var.eks_desired_size
  eks_instance_types = var.eks_instance_types
  eks_max_size       = var.eks_max_size
  eks_min_size       = var.eks_min_size
  eks_version        = var.eks_version
  subnet_ids         = module.network.private_subnet_ids["eks"]
  vpc_id             = module.network.vpc_id
}

module "alb" {
  source              = "../../modules/alb"
  env                 = var.env
  prefix              = var.prefix
  aws_profile         = var.profile
  alb_version         = var.alb_version
  certmanager_version = var.certmanager_version
  thumbprint          = var.thumbprint
  eks_name            = module.eks.eks_name
  eks_cacert          = module.eks.eks_cacert
  eks_endpoint        = module.eks.eks_endpoint
  eks_oidc            = module.eks.eks_oidc
  eks_token           = module.eks.eks_token
  vpc_id              = module.network.vpc_id
}
