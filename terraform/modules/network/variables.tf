variable "env" {
  type = string
}
variable "prefix" {
  type = string
}
variable "cidr_block" {
  type = string
}
variable "subnets" {
  type = list(object({
    type   = string,
    role   = string,
    cidr   = string,
    is_eks = bool
  }))
}
