# VPC Creation
data "aws_availability_zones" "available" {}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


locals {

  front_script = <<-EOT
    #!/bin/bash -v
    sudo echo "FASTAPI_URL=http://${module.backend.private_ip}:8000" >> /etc/environment
    sudo apt update -y
    sudo apt install -y nodejs npm git
    git clone https://github.com/Aazho/simple_node_front.git /app
    cd /app
    sudo npm install
    sudo npm i axios@0.21
    sudo node app.js
  EOT

  front_script_2 = <<-EOT
    #!/bin/bash -v
    sudo echo "FASTAPI_URL=http://${module.backend_2.private_ip}:8000" >> /etc/environment
    sudo apt update -y
    sudo apt install -y nodejs npm git
    git clone https://github.com/Aazho/simple_node_front.git /app
    cd /app
    sudo npm install
    sudo npm i axios@0.21
    sudo node app.js
  EOT

  back_script = <<-EOT
    #!/bin/bash -v
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    sudo apt update -y
    sudo apt install -y python3 python3-pip git
    sudo git clone https://github.com/Aazho/simple_fastapi_app.git /app
    cd /app
    sudo pip3 install uvicorn
    sudo pip3 install fastapi
    sudo uvicorn main:app --host 0.0.0.0 --port 8000
  EOT

    logscript = <<-EOT
    #!/bin/bash -v
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    sudo apt update -y
  EOT

}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.project}-vpc-${var.environment}"
  cidr = var.vpc_cidr

  azs              = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24"]

  enable_nat_gateway      = true 
  single_nat_gateway      = true # in prod should be set to false
  one_nat_gateway_per_az  = false # in prod should be set to true
  map_public_ip_on_launch = true
}


# Aurora RDS Creation

module "cluster" {
  source = "terraform-aws-modules/rds-aurora/aws"

  name           = "${var.project}-rds-${var.environment}"
  engine         = "aurora-postgresql"
  engine_version = "16.1"
  instance_class = "db.t4g.medium"
  instances = {
    one = {}
  }
  master_username             = "sysadmulb"
  master_password             = "RvwZs5g0D1HZP2DCKvmJCfbAXXw4xuzNQaVtZ6pfqosTs6Mwvq"
  port                        = "5432"
  db_subnet_group_name        = module.vpc.database_subnet_group
  storage_encrypted           = false

  vpc_id              = module.vpc.vpc_id
  apply_immediately   = true
  monitoring_interval = 0
  skip_final_snapshot = true
  deletion_protection = false


  depends_on = [module.vpc]
}

## Frontend

module "frontend" {
  source = "terraform-aws-modules/ec2-instance/aws"

  ami = data.aws_ami.ubuntu.id

  name = "frontend"

  instance_type               = "t2.micro"
  availability_zone           = element(module.vpc.azs, 0)
  subnet_id                   = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids      = [module.front_sg.security_group_id]
  associate_public_ip_address = true
  user_data_base64            = base64encode(local.front_script)
  user_data_replace_on_change = true

}

module "frontend_2" {
  source = "terraform-aws-modules/ec2-instance/aws"

  ami = data.aws_ami.ubuntu.id

  name = "frontend_2"

  instance_type               = "t2.micro"
  availability_zone           = element(module.vpc.azs, 1)
  subnet_id                   = element(module.vpc.public_subnets, 1)
  vpc_security_group_ids      = [module.front_sg.security_group_id]
  associate_public_ip_address = true
  user_data_base64            = base64encode(local.front_script_2)
  user_data_replace_on_change = true

}

## Backend

module "backend" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "backend"
  ami  = data.aws_ami.ubuntu.id

  instance_type               = "t2.micro"
  availability_zone           = element(module.vpc.azs, 0)
  subnet_id                   = element(module.vpc.private_subnets, 0)
  vpc_security_group_ids      = [module.private_sg.security_group_id]
  user_data_base64            = base64encode(local.back_script)
  user_data_replace_on_change = true
  depends_on                  = [module.vpc.aws_route_table_association]

}

module "backend_2" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "backend_2"
  ami  = data.aws_ami.ubuntu.id

  instance_type               = "t2.micro"
  availability_zone           = element(module.vpc.azs, 0)
  subnet_id                   = element(module.vpc.private_subnets, 0)
  vpc_security_group_ids      = [module.private_sg.security_group_id]
  user_data_base64            = base64encode(local.back_script)
  user_data_replace_on_change = true
  depends_on                  = [module.vpc.aws_route_table_association]

}

module "logcollector" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "logcollector"
  ami  = data.aws_ami.ubuntu.id

  instance_type               = "t2.micro"
  availability_zone           = element(module.vpc.azs, 0)
  subnet_id                   = element(module.vpc.private_subnets, 0)
  vpc_security_group_ids      = [module.private_sg.security_group_id]
  user_data_base64            = base64encode(local.logscript)
  user_data_replace_on_change = true
  depends_on                  = [module.vpc.aws_route_table_association]
}


## Security group

module "front_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${var.project}-front-sg-${var.environment}"
  description = "Security group for usage with EC2 instance frontend"
  vpc_id      = module.vpc.vpc_id

  # Accept HTTP and HTTPS connection fron the internet
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  egress_rules        = ["all-all"]
}

module "private_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${var.project}-private_sg-${var.environment}"
  description = "Security group for usage with EC2 instance backend"
  vpc_id      = module.vpc.vpc_id

  # Accept All type of connection from the AWS VPC only
  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]
  ingress_rules       = ["all-all"]
  egress_rules        = ["all-all"]
}