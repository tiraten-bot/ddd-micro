# DDD Microservices Infrastructure
# Main Terraform configuration

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.17"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "ddd-microservices"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Local values
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  
  availability_zones = data.aws_availability_zones.available.names
  
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  
  tags = local.common_tags
}

# EKS Module
module "eks" {
  source = "./modules/eks"
  
  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids
  
  node_groups = var.eks_node_groups
  
  tags = local.common_tags
  
  depends_on = [module.vpc]
}

# RDS Module (PostgreSQL)
module "rds" {
  source = "./modules/rds"
  
  name_prefix = local.name_prefix
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  databases = var.rds_databases
  
  tags = local.common_tags
  
  depends_on = [module.vpc]
}

# ElastiCache Module (Redis)
module "redis" {
  source = "./modules/redis"
  
  name_prefix = local.name_prefix
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  redis_config = var.redis_config
  
  tags = local.common_tags
  
  depends_on = [module.vpc]
}

# ECR Module (Container Registry)
module "ecr" {
  source = "./modules/ecr"
  
  name_prefix = local.name_prefix
  
  repositories = var.ecr_repositories
  
  tags = local.common_tags
}

# MSK Module (Kafka)
module "msk" {
  source = "./modules/msk"
  
  name_prefix = local.name_prefix
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  kafka_config = var.kafka_config
  
  tags = local.common_tags
  
  depends_on = [module.vpc]
}
