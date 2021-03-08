// VPC
resource "aws_vpc" "vpc" {
  cidr_block         = var.cidr_block
  enable_dns_support = true

  tags = {
    Name = format("%s-%s-vpc", var.env, var.prefix)
  }
}

// Subnet
resource "aws_subnet" "public" {
  count             = length(local.public_subnets)
  cidr_block        = element(local.public_subnets, count.index)["cidr"]
  vpc_id            = aws_vpc.vpc.id
  availability_zone = element(local.az, count.index)

  tags = merge(
    map("Name", format("%s-%s-%s-%s-%s",
      var.env,
      var.prefix,
      element(local.public_subnets, count.index)["type"],
      element(local.public_subnets, count.index)["role"],
      trimprefix(element(local.az, count.index), "ap-northeast-")
    )),
    element(local.public_subnets, count.index)["is_eks"] ? local.public_eks_tag : null
  )
}

resource "aws_subnet" "private" {
  count             = length(local.private_subnets)
  cidr_block        = element(local.private_subnets, count.index)["cidr"]
  vpc_id            = aws_vpc.vpc.id
  availability_zone = element(local.az, count.index)

  tags = merge(
    map("Name", format("%s-%s-%s-%s-%s",
      var.env,
      var.prefix,
      element(local.private_subnets, count.index)["type"],
      element(local.private_subnets, count.index)["role"],
      trimprefix(element(local.az, count.index), "ap-northeast-")
    )),
    element(local.private_subnets, count.index)["is_eks"] ? local.private_eks_tag : null
  )
}

// Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = format("%s-%s-igw", var.env, var.prefix)
  }
}

// Nat Gateway
resource "aws_eip" "eip" {
  vpc = true

  tags = {
    Name = format("%s-%s-nat-eip", var.env, var.prefix)
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = format("%s-%s-nat", var.env, var.prefix)
  }
}

// Route Table
resource "aws_route_table" "public" {
  count  = length(local.public_subnets) / 2
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = format("%s-%s-public-%s-rtb", var.env, var.prefix, element(local.public_subnets, count.index)["role"])
  }
}

resource "aws_route" "public_igw" {
  count                  = length(local.public_subnets) / 2
  route_table_id         = aws_route_table.public[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  count          = length(local.public_subnets)
  route_table_id = aws_route_table.public[floor(count.index / 2)].id
  subnet_id      = aws_subnet.public[count.index].id
}

resource "aws_route_table" "private" {
  count  = length(local.private_subnets) / 2
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = format("%s-%s-private-%s-rtb", var.env, var.prefix, element(local.private_subnets, count.index)["role"])
  }
}

resource "aws_route" "private_nat" {
  count                  = length(local.private_subnets) / 2
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private" {
  count          = length(local.private_subnets)
  route_table_id = aws_route_table.private[floor(count.index / 2)].id
  subnet_id      = aws_subnet.private[count.index].id
}
