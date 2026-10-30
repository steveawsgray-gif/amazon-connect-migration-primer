output "connect_instance_id" {
  description = "Amazon Connect instance ID"
  value       = module.connect.instance_id
}

output "connect_instance_arn" {
  description = "Amazon Connect instance ARN"
  value       = module.connect.instance_arn
}

output "connect_access_url" {
  description = "Admin / agent entry point for the instance"
  value       = module.connect.instance_access_url
}

output "main_flow_id" {
  description = "Main Inbound contact flow ID — assign the phone number to this flow"
  value       = module.connect.main_flow_id
}

output "queue_ids" {
  description = "Queue name → queue ID"
  value       = module.connect.queue_ids
}

output "claimed_phone_number" {
  description = "The claimed DID, if claim_phone_number was true"
  value       = module.connect.claimed_phone_number
}

output "customer_table_name" {
  description = "DynamoDB customer directory table"
  value       = module.customer_data.table_name
}

output "lookup_lambda_name" {
  description = "Customer lookup Lambda function"
  value       = module.customer_data.lambda_function_name
}

output "recordings_bucket" {
  description = "S3 bucket receiving call recordings and chat transcripts"
  value       = module.storage_analytics.recordings_bucket_id
}

output "ctr_lake_bucket" {
  description = "S3 bucket receiving Contact Trace Records via Firehose"
  value       = module.storage_analytics.analytics_bucket_id
}

output "next_steps" {
  description = "Commissioning steps after apply"
  value       = "1) Open the Main Inbound flow in Flow Designer and validate. 2) Assign the phone number to the flow (console or aws connect update-phone-number). 3) Create demo agents on the Standard Agent routing profile. 4) Run the Phase 5 validation calls from PHASE_CHECKLIST.md."
}
