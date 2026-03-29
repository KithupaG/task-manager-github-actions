terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
    region = var.region
}

resource "aws_vpc" "myapp_vpc" {
    cidr_block = var.vpc_cidr_block
    enable_dns_hostnames = true
    enable_dns_support   = true

    tags = {
        Name = "${var.env_prefix}-vpc"
    }
}


resource "aws_subnet" "myapp-subnet-1" {
    vpc_id = aws_vpc.myapp_vpc.id
    cidr_block = var.subnet_cidr_block
    availability_zone = var.avail_zone
    map_public_ip_on_launch = true
    
    tags = {
        Name = "${var.env_prefix}-subnet-1"
        "kubernetes.io/cluster/myapp-eks-cluster" = "shared"
        "kubernetes.io/role/elb" = "1"
    }
}

resource "aws_subnet" "myapp-subnet-2" {
    vpc_id = aws_vpc.myapp_vpc.id
    cidr_block = var.subnet_cidr_block_2
    availability_zone = var.avail_zone_2
    map_public_ip_on_launch = true
        
    tags = {
        Name = "${var.env_prefix}-subnet-2"
        "kubernetes.io/cluster/myapp-eks-cluster" = "shared"
        "kubernetes.io/role/elb" = "1"
    }
}


resource "aws_internet_gateway" "myapp_igw" {
    vpc_id = aws_vpc.myapp_vpc.id

    tags = {
        Name = "${var.env_prefix}-igw"
    }
}

resource "aws_default_route_table" "main_rtb" {
    default_route_table_id = aws_vpc.myapp_vpc.default_route_table_id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp_igw.id
    }

    tags = {
        Name = "${var.env_prefix}-main-rtb"
    }
}

module "eks" {
    source  = "terraform-aws-modules/eks/aws"
    version = "~> 21.0"

    name               = "myapp-eks-cluster"
    kubernetes_version = "1.33"

    endpoint_public_access                 = true
    enable_cluster_creator_admin_permissions = true

    eks_managed_node_groups = {
        dev_nodes = {
        ami_type       = "AL2023_x86_64_STANDARD"
        instance_types = ["t3.small"]
        min_size       = 1
        max_size       = 3
        desired_size   = 2
    }
}

    vpc_id     = aws_vpc.myapp_vpc.id
    subnet_ids = [aws_subnet.myapp-subnet-1.id, aws_subnet.myapp-subnet-2.id]

    tags = {
        environment = "dev"
        Terraform   = "true"
    }
}

resource "aws_security_group" "myapp_sg" {
    name = "myapp-sg"
    vpc_id = aws_vpc.myapp_vpc.id

    ingress {
        from_port = 443
        to_port = 443
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 30080
        to_port = 30080
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.env_prefix}-sg" 
    }
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}