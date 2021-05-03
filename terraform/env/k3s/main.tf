module "k3s" {
  source     = "../../modules/k3s"
  cidr       = var.cidr
  domain     = var.domain
  public_key = var.public_key
  allow_ip   = var.allow_ip
}
