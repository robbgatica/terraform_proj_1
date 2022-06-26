#TODO: deploy load balancer
#TODO: configure docker image/ec2 instances 

# VPC
resource "aws_vpc" "vpc-home" {
  provider             = aws.region-home
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-home"
  }
}

# IGW
resource "aws_internet_gateway" "gateway-home" {
  provider = aws.region-home
  vpc_id   = aws_vpc.vpc-home.id
}

# get AZs
data "aws_availability_zones" "azs" {
  provider = aws.region-home
  state    = "available"
}

# subnets
resource "aws_subnet" "public-subnet-home" {
  provider          = aws.region-home
  availability_zone = element(data.aws_availability_zones.azs.names, 0)
  vpc_id            = aws_vpc.vpc-home.id
  cidr_block        = "10.0.1.0/24"
  # required for EKS - might not need this at the moment
  map_public_ip_on_launch = true
  tags = {
    Name                        = "public-subnet"
    "kubernetes.io/cluster/eks" = "shared"
    "kubernetes.io/role/elb"    = 1
  }
}

resource "aws_subnet" "private-subnet-home" {
  provider          = aws.region-home
  availability_zone = element(data.aws_availability_zones.azs.names, 1)
  vpc_id            = aws_vpc.vpc-home.id
  cidr_block        = "10.0.2.0/24"
  tags = {
    Name                              = "private-subnet"
    "kubernetes.io/cluster/eks"       = "shared"
    "kubernetes.io/role/internal-elb" = 1
  }
}

# NAT gateway
resource "aws_nat_gateway" "gateway-home" {
  allocation_id = aws_eip.nat-eip.id
  subnet_id     = aws_subnet.public-subnet-home.id
  tags = {
    Name = "nat-gw"
  }
}

# EIP for NAT gateway
resource "aws_eip" "nat-eip" {
  depends_on = [
    aws_internet_gateway.gateway-home
  ]
}

# routing tables
resource "aws_route_table" "public-rt-home" {
  vpc_id = aws_vpc.vpc-home.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway-home.id
  }
  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table" "private-rt-home" {
  vpc_id = aws_vpc.vpc-home.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gateway-home.id
  }
  tags = {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "public-rt-assoc" {
  subnet_id      = aws_subnet.public-subnet-home.id
  route_table_id = aws_route_table.public-rt-home.id
}

resource "aws_route_table_association" "private-rt-assoc" {
  subnet_id      = aws_subnet.private-subnet-home.id
  route_table_id = aws_route_table.private-rt-home.id
}