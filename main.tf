provider "aws" {
  region = "${var.region}"
}

## Get AZ's details

data "aws_availability_zones" "azs" {}

## Declare local variables

locals {
  az_names      =    "${data.aws_availability_zones.azs.names}"
  pub_sub_ids   =    "${aws_subnet.public.*.id}"
  pri_sub_ids   =    "${aws_subnet.private.*.id}"
}

## Create VPC

resource "aws_vpc" "my_vpc" {
  
  cidr_block              =   "${var.vpc_cidr}"
  instance_tenancy        =   "default"
  enable_dns_hostnames    =   "true"

  tags = {
    Name = "main"
  }
}

## Create public subnet

resource "aws_subnet" "public" {
  count                    =    "${length(local.az_names)}"
  vpc_id                   =    "${aws_vpc.my_vpc.id}"
  cidr_block               =    "${cidrsubnet(var.vpc_cidr, 8 , count.index)}"
  availability_zone        =    "${local.az_names[count.index]}"
  map_public_ip_on_launch  =     true
  
  tags = {
    Name = "publicSubnet-${count.index + 1}"
  }
}
## Create internet gateway

resource "aws_internet_gateway" "igw" {
  vpc_id      = "${aws_vpc.my_vpc.id}"
 
  tags = {
    Name = "my_gateway"
  }
}

## creating public route table 

resource "aws_route_table" "public_rt" {
  vpc_id     = "${aws_vpc.my_vpc.id}"

  route        {
    
      cidr_block         =   "0.0.0.0/0"
      gateway_id         =   "${aws_internet_gateway.igw.id}"
    }
   
  

  tags       = {
    Name = "public-rt"
  }
}

## public route table association

resource "aws_route_table_association" "pub_sub_association" {
  count          = "${length(local.az_names)}"
  subnet_id      = "${local.pub_sub_ids[count.index]}"
  route_table_id = "${aws_route_table.public_rt.id}"
  
}


## private subnets 

resource "aws_subnet" "private" {
  count                    =    "${length(slice(local.az_names, 0 , 2))}"
  vpc_id                   =    "${aws_vpc.my_vpc.id}"
  cidr_block               =    "${cidrsubnet(var.vpc_cidr, 8 , count.index + length(local.az_names))}"
  availability_zone        =    "${local.az_names[count.index]}"
  
  tags = {
    Name = "privateSubnet-${count.index + 1}"
  }
}



##  creating Bastion Host


resource "aws_instance" "nat" {
  ami                    =   "${var.nat_ami[var.region]}"
  instance_type          =   "t2.micro"
  subnet_id              =   "${local.pub_sub_ids[0]}"
  source_dest_check      =    false
  vpc_security_group_ids =   ["${aws_security_group.nat_sg.id}"]
  key_name               =   "keerthi"
 

  tags = {
    Name  =  "bastion_Host"
  }
}

## creating private route

resource "aws_route_table" "private_rt" {
  vpc_id     = "${aws_vpc.my_vpc.id}"
  depends_on               = [aws_instance.nat]
  route        {
    
      cidr_block         =   "0.0.0.0/0"
      instance_id        =   "${aws_instance.nat.id}"
    }
   
  tags       = {
    Name = "private-rt"
  }
}

## private route table association

resource "aws_route_table_association" "pri_sub_association" {
  count          = "${length(slice(local.az_names, 0 , 2))}"
  subnet_id      = "${local.pri_sub_ids[count.index]}"
  route_table_id = "${aws_route_table.private_rt.id}"
} 

## Creating nat security group

resource "aws_security_group" "nat_sg" {
  name        = "nat_sg"
  description = "Allow all traffic from internet"
  vpc_id      = "${aws_vpc.my_vpc.id}"
  

  egress  {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
  }  

  tags = {
    Name = "nat_sg" 
  }
}

## creating amazon linux HVM with docker

resource "aws_instance" "web-server" {
  count                    =   "${var.web_ec2_count}"
  ami                      =   "${var.web_server_ami[var.region]}" 
  instance_type            =   "t2.micro"
  subnet_id                =   "${local.pub_sub_ids[0]}"
  user_data                =   "${file("scripts/docker.sh")}"
  vpc_security_group_ids   =   ["${aws_security_group.web_sg.id}"]
  key_name                 =   "keerthi"
  iam_instance_profile     =   aws_iam_instance_profile.test_profile.name

     tags = {
  Name = "web-server"
   }
}

## Creating security group for docker instances 
resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "Allow all traffic from internet"
  vpc_id      = "${aws_vpc.my_vpc.id}"


  ingress  {
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
  } 
   ingress  {
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
  }  
   egress  {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
  }   

  tags = {
    Name = "web_sg" 
  }
}

## Creating rds db instance

resource "aws_db_instance" "rds" {
  allocated_storage        = 10
  engine                   = "mysql"
  engine_version           = "5.7"
  instance_class           = "db.t2.micro"
  name                     = "mydb"
  username                 = "admin"
  password                 = "admin4321"
  parameter_group_name     = "default.mysql5.7"
  db_subnet_group_name     = "${aws_db_subnet_group.rds.id}"
  auto_minor_version_upgrade = false
  skip_final_snapshot      =  true

}

## DB subnet group

resource "aws_db_subnet_group" "rds" {
  name       = "main"
  subnet_ids = "${local.pri_sub_ids}"

  tags = {
    Name = "My DB subnet group"
  }
}

## rds db security group

resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow traffic for rds"
  vpc_id      = "${aws_vpc.my_vpc.id}"

   ingress  {
      from_port        = 3306
      to_port          = 3306
      protocol         = "tcp"
      security_groups  = ["${aws_security_group.web_sg.id}"]
  }  
   egress  {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
  }   

  tags = {
    Name = "rds_sg" 
  }
}
