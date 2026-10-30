variable "project_name" { type = string }
variable "environment" { type = string }
variable "instance_alias" { type = string }
variable "hours_time_zone" { type = string }
variable "lambda_function_arn" { type = string }
variable "recordings_bucket_id" { type = string }
variable "recordings_kms_key_arn" { type = string }
variable "ctr_firehose_arn" { type = string }
variable "flow_template_path" { type = string }
variable "claim_phone_number" { type = bool }
variable "phone_country_code" { type = string }
variable "common_tags" {
  type    = map(string)
  default = {}
}
