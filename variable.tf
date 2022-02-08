## Declare variable region

variable "region" {
  default = "ap-south-1"
}

## Declare variable vpc_cidr

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

##    declaring Bastion host amis

variable "nat_ami" {
  type     =  map 
  default  =  {
    us-east-1    =   "ami-087c17d1fe0178315"
    us-east-2    =   "ami-00dfe2c7ce89a450b"
    ap-south-1   =   "ami-0a23ccb2cdd9286bb"
  }
}

## Declaring variables for web instance

variable "web_server_ami" {
  type     =  map 
  default  =  {
    us-east-1    =   "ami-087c17d1fe0178315"
    us-east-2    =   "ami-00dfe2c7ce89a450b"
    ap-south-1   =   "ami-0a23ccb2cdd9286bb"
  }
}

# Declaring ec2 count
variable "web_ec2_count" {
  default = 1
}

# Declaring ec2 instance type
variable "web_instance_type" {
  default = "t2.micro"
}

##
variable  "private_key" {
  default = "keerthi"
}
