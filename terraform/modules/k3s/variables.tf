variable "nw_addr" {
  type    = string
  default = "10.0.0.0"
}

variable "domain" {
  type    = string
  default = "example.com"
}

variable "public_key" {
  type    = string
  default = "ssh-rsa xyz123"
}

variable "allow_ip" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "node_port" {
  type    = number
  default = 30000
}
