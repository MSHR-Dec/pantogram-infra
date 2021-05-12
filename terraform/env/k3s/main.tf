module "k3s" {
  source     = "../../modules/k3s"
  nw_addr    = var.nw_addr
  domain     = var.domain
  public_key = var.public_key
  allow_ip   = var.allow_ip
  node_port  = var.node_port
}
