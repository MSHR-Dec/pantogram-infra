// provider
variable "profile" {}
variable "region" {}

// common
variable "env" {}
variable "prefix" {}

// network
variable "cidr_block" {}
variable "subnets" {}

// domain
variable "domain" {}

// eks
variable "eks_version" {}
variable "eks_capacity_type" {}
variable "eks_instance_types" {}
variable "eks_desired_size" {}
variable "eks_max_size" {}
variable "eks_min_size" {}

// alb
variable "alb_version" {}
variable "certmanager_version" {}
variable "thumbprint" {}
