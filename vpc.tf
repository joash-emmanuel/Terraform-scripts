#Authorization using profile name
provider "aws" {
  region     = var.AWS_REGION
  access_key = var.AWS_ACCESS_KEY
  secret_key = var.AWS_SECRET_KEY
}


#Creating VPC
resource "aws_vpc" "dev_vpc" {
    cidr_block = "11.0.0.0/16"
    instance_tenancy = "default"
    enable_dns_hostnames = true
    enable_dns_support   = true

    tags = {
    Name = "Dev_vpc"
  }
  
}

#subnet_id     = aws_subnet.public_subnet[0].id

#CREATING PUBLIC SUBNETS
resource "aws_subnet" "dev_public_subnet" {
 count      = length(var.public_subnet_cidrs)  #length will det the number or length of a given list/string/map --count will det the number of instances to create
 vpc_id     = aws_vpc.dev_vpc.id
 cidr_block = element(var.public_subnet_cidrs, count.index) #element retrieves the variables one by one while count.index represents the index of the resource created and starts from 0
 availability_zone = element(var.availability_zones, count.index)
 
 tags = {
   Name = "dev_public_subnet ${count.index + 1}"
 }
}
 
#creating a public route table for the two public subnets, adding a vpc and adding routes in relation to IGW
resource "aws_route_table" "dev_public_route" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev_IGW.id
  }
}

#creating public subnets route table association
resource "aws_route_table_association" "public_subnet_association" {
 count = length(var.public_subnet_cidrs)
 subnet_id      = element(aws_subnet.dev_public_subnet[*].id, count.index)
 route_table_id = aws_route_table.dev_public_route.id

}

#creating an internet_gateway
resource "aws_internet_gateway" "dev_IGW" {
 vpc_id = aws_vpc.dev_vpc.id

 tags = {
    Name = "dev_IGW"
  }
}


 #CREATING PRIVATE SUBNETS
resource "aws_subnet" "dev_private_subnet" {
 count      = length(var.private_subnet_cidrs)
 vpc_id     = aws_vpc.dev_vpc.id
 cidr_block = element(var.private_subnet_cidrs, count.index)
 availability_zone = element(var.availability_zones, count.index)
 
 tags = {
   Name = "dev_private_subnet ${count.index + 1}"
 }

}

#create an elastic IP
resource "aws_eip" "dev-eip" {
   vpc   = true

   tags = {
   Name = "dev-eip"
 }
 }

 #Creating the NAT Gateway using subnet_id and allocation_id --creating a nat gateway in one of the private subnets
 resource "aws_nat_gateway" "dev_NAT_gateway" {
   allocation_id = aws_eip.dev-eip.id
   #count = length(var.public_subnet_cidrs)
   #subnet_id      = element(aws_subnet.public_subnet[*].id, count.index)
   subnet_id     = aws_subnet.dev_public_subnet[0].id

   tags = {
   Name = "dev_NAT_gateway"
 }
 }

 #route table for the two private subnets
 resource "aws_route_table" "dev_private_route" {   
   vpc_id = aws_vpc.dev_vpc.id
   route {
   cidr_block = "0.0.0.0/0"           
   nat_gateway_id = aws_nat_gateway.dev_NAT_gateway.id
   }
 }

#creating private route table association
 resource "aws_route_table_association" "private_subnet_association" {
 count = length(var.private_subnet_cidrs)
 subnet_id      = element(aws_subnet.dev_private_subnet[*].id, count.index)
 route_table_id = aws_route_table.dev_private_route.id

}


# creating security_group
resource "aws_security_group" "dev_security_group" {
  name        = "initial_security_group"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] #allow all ipv4 ingress from ssh
    ipv6_cidr_blocks = ["::/0"]      #allow  all ipv6 ingress from ssh
  }
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
