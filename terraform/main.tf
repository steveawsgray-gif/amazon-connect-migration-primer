# Project 2 — Amazon Connect Contact Centre — root module
#
# REVIEW GUIDE (architecture level — that's your layer):
#   modules/connect            The contact centre itself: instance, hours,
#                              queues, routing profile, main flow, storage wiring
#   modules/customer_data      DynamoDB customer directory + Lambda data dip
#   modules/storage_analytics  KMS, S3 (recordings + CTR lake), Firehose, Athena
#
# Dependency shape (acyclic on purpose):
#   connect instance ──► customer_data Lambda permission (Connect may invoke)
#   customer_data Lambda ──► connect flow (flow calls the function)
#   storage outputs ──► connect storage configs (recordings + CTR destinations)

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  common_tags = merge(
    {
      Project     = "amazon-connect-contact-centre"
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.common_tags,
  )
}

module "storage_analytics" {
  source       = "./modules/storage_analytics"
  project_name = var.project_name
  environment  = var.environment
  account_id   = data.aws_caller_identity.current.account_id
  common_tags  = local.common_tags
}

module "connect" {
  source                 = "./modules/connect"
  project_name           = var.project_name
  environment            = var.environment
  instance_alias         = var.instance_alias
  hours_time_zone        = var.hours_time_zone
  lambda_function_arn    = module.customer_data.lambda_function_arn
  recordings_bucket_id   = module.storage_analytics.recordings_bucket_id
  recordings_kms_key_arn = module.storage_analytics.kms_key_arn
  ctr_firehose_arn       = module.storage_analytics.ctr_firehose_arn
  flow_template_path     = "${path.root}/../flows/main-inbound-flow.json"
  claim_phone_number     = var.claim_phone_number
  phone_country_code     = var.phone_country_code
  common_tags            = local.common_tags
}

module "customer_data" {
  source              = "./modules/customer_data"
  project_name        = var.project_name
  environment         = var.environment
  account_id          = data.aws_caller_identity.current.account_id
  connect_instance_id = module.connect.instance_id
  common_tags         = local.common_tags
}
