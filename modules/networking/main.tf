// The VPC

resource "aws_vpc" "vpc" {
  cidr_block = "${var.vpc_cidr}"

  // this is done to allow ec2 instances to have ip addresses
  enable_dns_hostnames = true
  enable_dns_support = true

  tags {
    Name = "${var.environment}-vpc"
    Environment = "${var.environment}"
  }
}

// Internet gateways

// internet gateway 1 ) provides a target for vpc route tables
// 2) performs a network address translation on ec2 instances that have public ip addresses
resource "aws_internet_gateway" "ig" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "${var.environment}-igw"
    Environment = "${var.environment}"
  }
}

// elastic ip for igw

// ? confusing code here. i would think this belongs to a vpc.
// it seems like the concept of elastic ip is modular and is being applied to a vpc instance

// todo: articulate the importance of elastic ip in this vpc

resource "aws_eip" "nat_eip" {
  vpc = true
  depends_on = ["aws_internet_gateway.ig"] // no $ sign for referencing a resource unlike for aws_vpc?
}

// nat gateway
// nat gateway enable instances in private subnets to communicate with the internet but prevents internet
// from communicating with the instance

// nat gateway "lives?" in a public subnet and needs to be associated with an elastic ip
// private instances in private subnets needs a route table that points to the nat gateway

// for HA, you need to have one nat gateway per AZ

resource "aws_nat_gateway" "nat" {
  allocation_id = "${aws_eip.nat_eip.id}" // elastic ip associated to this nat gateway
  subnet_id = "${element(aws_subnet.public_subnet.*.id, 0)}" // pick the first public subnet
  depends_on = ["aws_internet_gateway.ig"]

  tags {
    Name = "${var.environment}-${element(var.availability_zones, count.index)}-nat"
    Environment = "${var.environment}"
  }
}

// public subnet

resource "aws_subnet" "public_subnet" {
  vpc_id = "${aws_vpc.vpc.id}"

  // ? i would think this is a constant number like 2 instead of being dependent on cidr values
  count = "${length(var.public_subnets_cidr)}"

  cidr_block = "${element(var.public_subnets_cidr, count.index)}"
  availability_zone = "${element(var.availability_zones, count.index)}"
  map_public_ip_on_launch = true // allows instances launched into this subnet to have public ips

  tags {
    Name = "${var.environment}-${element(var.availability_zones, count.index)}-public-subnet"
    Environment = "${var.environment}"
  }
}

// private subnet

resource "aws_subnet" "private_subnet" {
  vpc_id = "${aws_vpc.vpc.id}"
  count = "${length(var.private_subnets_cidr)}"
  cidr_block = "${element(var.private_subnets_cidr, count.index)}"
  availability_zone = "${element(var.availability_zones, count.index)}"
  map_public_ip_on_launch = false

  tags {
    Name = "${var.environment}-${element(var.availability_zones, count.index)}-private-subnet"
    Environment = "${var.environment}"
  }
}

// routing table for private subnet

// determines where internet traffic goes
// each subnet will need a route table and can only be associated with a single route table

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "${var.environment}-private-route-table"
    Environment = "${var.environment}"
  }
}

// routing table for public subnet

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "${var.environment}-public-route-table"
    Environment = "${var.environment}"
  }
}

// route table entry for a route table to allow the internet gateway to access the public subnet

resource "aws_route" "public_internet_gateway" {
  route_table_id = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.ig.id}"
}

resource "aws_route" "private_nat_gateway" {
  route_table_id = "${aws_route_table.private.id}"
  destination_cidr_block = "0.0.0.0/0" # this is allowing all traffic from the nat gateway
  nat_gateway_id = "${aws_nat_gateway.nat.id}"
}


// route table associations

resource "aws_route_table_association" "public" {
  route_table_id = "${aws_route_table.public.id}"
  count = "${length(var.public_subnets_cidr)}"
  subnet_id = "${element(aws_subnet.public_subnet.*.id, count.index)}"
}

resource "aws_route_table_association" "private" {
  route_table_id = "${aws_route_table.private.id}"
  count = "${length(var.private_subnets_cidr)}"
  subnet_id = "${element(aws_subnet.private_subnet.*.id, count.index)}"
}


// vpc default security group

resource "aws_security_group" "default" {
  name = "${var.environment}-default-sg"
  description = "default security group to allow inbound/outbound from the vpc"
  vpc_id = "${aws_vpc.vpc.id}"
  depends_on = ["aws_vpc.vpc"]

  ingress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    self = true
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    self = true
  }

  tags {
    environment = "${var.environment}"
  }
}
