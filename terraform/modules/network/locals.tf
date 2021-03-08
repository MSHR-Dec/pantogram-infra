locals {
  az = ["ap-northeast-1a", "ap-northeast-1d"]
  private_eks_tag = {
    format("kubernetes.io/cluster/%s-%s-cluster", var.env, var.prefix) = "shared"
  }
  public_eks_tag = merge(local.private_eks_tag, map("kubernetes.io/role/elb", ""))

  public_subnets = [
    for subnet in var.subnets :
    subnet
    if subnet["type"] == "public"
  ]
  private_subnets = [
    for subnet in var.subnets :
    subnet
    if subnet["type"] == "private"
  ]
}
