output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "public_subnet_ids" {
  value = {
    for public in aws_subnet.public :
    element(split("-", public.tags["Name"]), 3) => public.id...
  }
}

output "private_subnet_ids" {
  value = {
    for private in aws_subnet.private :
    element(split("-", private.tags["Name"]), 3) => private.id...
  }
}
