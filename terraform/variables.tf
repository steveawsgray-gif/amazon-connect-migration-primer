variable "aws_region" {
  description = "AWS region for the Connect instance (us-east-1 has the widest Connect feature + number coverage)"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project slug used in resource names and tags"
  type        = string
  default     = "connect-centre"
}

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "dev"
}

variable "instance_alias" {
  description = "Amazon Connect instance alias — globally unique, becomes the login URL (https://<alias>.my.connect.aws). Change it if taken."
  type        = string
  default     = "sgray-connect-demo"
}

variable "hours_time_zone" {
  description = "Time zone for the business hours of operation"
  type        = string
  default     = "America/Toronto"
}

variable "claim_phone_number" {
  description = "true = claim a DID number during apply (small monthly fee while held). false = build everything, claim later from the console."
  type        = bool
  default     = false
}

variable "phone_country_code" {
  description = "Country for the claimed DID (ISO 3166-1 alpha-2)"
  type        = string
  default     = "CA"
}

variable "common_tags" {
  description = "Extra tags merged onto every resource"
  type        = map(string)
  default     = {}
}
