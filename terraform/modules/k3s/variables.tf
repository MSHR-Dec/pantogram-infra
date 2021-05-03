variable "cidr" {
  type = string
}

variable "domain" {
  type = string
}

variable "public_key" {
  type = string
}

variable "allow_ip" {
  type = list(string)
}
