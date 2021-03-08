variable "env" {
  type = string
}
variable "prefix" {
  type = string
}
variable "eks_version" {
  type = string
}
variable "eks_capacity_type" {
  type = string
}
variable "eks_instance_types" {
  type = list(string)
}
variable "eks_desired_size" {
  type = number
}
variable "eks_max_size" {
  type = number
}
variable "eks_min_size" {
  type = number
}
variable "vpc_id" {
  type = string
}
variable "subnet_ids" {
  type = list(string)
}
