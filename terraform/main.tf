provider "aws" {
  access_key = var.aws-access-key
  secret_key = var.aws-secret-key
  region     = var.aws-region
}

data "aws_caller_identity" "current" {}

#terraform {
#  backend "s3" {
#    bucket  = "terraform-backend-store"
#    encrypt = true
#    key     = "terraform.tfstate"
#    region  = "eu-central-1"
#    # dynamodb_table = "terraform-state-lock-dynamo" - uncomment this line once the terraform-state-lock-dynamo has been terraformed
#  }
#}
#
#resource "aws_dynamodb_table" "dynamodb-terraform-state-lock" {
#  name           = "terraform-state-lock-dynamo"
#  hash_key       = "LockID"
#  read_capacity  = 20
#  write_capacity = 20
#  attribute {
#    name = "LockID"
#    type = "S"
#  }
#  tags = {
#    Name = "DynamoDB Terraform State Lock Table"
#  }
#}

module "vpc" {
  source             = "./vpc"
  name               = var.name
  cidr               = var.cidr
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
  availability_zones = var.availability_zones
  environment        = var.environment
}

module "security_groups" {
  source         = "./security-groups"
  name           = var.name
  vpc_id         = module.vpc.id
  environment    = var.environment
  container_port = var.container_port
}

module "alb" {
  source              = "./alb"
  name                = var.name
  vpc_id              = module.vpc.id
  subnets             = module.vpc.public_subnets
  environment         = var.environment
  alb_security_groups = [module.security_groups.alb]
  alb_tls_cert_arn    = var.tsl_certificate_arn
  health_check_path   = var.health_check_path
}

module "ecr" {
  source      = "./ecr"
  name        = var.name
  environment = var.environment
}

module "secrets" {
  source              = "./secrets"
  name                = var.name
  environment         = var.environment
}

module "s3" {
  source = "./s3"
}

module "connection" {
  source = "./connection"
}

module "ecs" {
  source                      = "./ecs"
  name                        = var.name
  environment                 = var.environment
  region                      = var.aws-region
  subnets                     = module.vpc.private_subnets
  aws_alb_target_group_arn    = module.alb.aws_alb_target_group_arn
  ecs_service_security_groups = [module.security_groups.ecs_tasks]
  container_port              = var.container_port
  container_cpu               = var.container_cpu
  container_memory            = var.container_memory
  service_desired_count       = var.service_desired_count
  container_environment       = [
    {
      name  = "LOG_LEVEL",
      value = "DEBUG"
    },
    {
      name  = "PORT",
      value = var.container_port
    }
  ]
  # container_secrets      = module.secrets.secrets_map
  # aws_ecr_repository_url = module.ecr.container_image_url
  # container_secrets_arns = module.secrets.application_secrets_arn
  # container_image        = module.ecr.container_image_name
  container_image_url_repository = module.ecr.container_image_url
}

module "codebuild" {
  source                   = "./codebuild"
  codebuild_account_id     = data.aws_caller_identity.current.id
  codebuild_region         = var.aws-region
  codebuild_repository_url = module.ecr.container_image_url
  codebuild_s3_artifacts   = module.s3.s3_artifacts
}

module "codepipeline" {
  source                    = "./codepipeline"
  codebuild_project         = module.codebuild.codebuild_project
  connection_github         = module.connection.connection_name
  ecs_cluster_id            = module.ecs.ecs_cluster
  ecs_services_id           = module.ecs.ecs_service
  github_branch             = var.github-branch
  github_repository         = var.github-repo
  s3_codepipeline_artifacts = module.s3.s3_codepipeline_artifacts
  s3_artifacts              = module.s3.s3_artifacts
}