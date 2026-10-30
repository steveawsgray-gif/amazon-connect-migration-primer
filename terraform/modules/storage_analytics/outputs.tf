output "recordings_bucket_id" {
  value = aws_s3_bucket.recordings.id
}

output "analytics_bucket_id" {
  value = aws_s3_bucket.analytics.id
}

output "kms_key_arn" {
  value = aws_kms_key.connect_data.arn
}

output "ctr_firehose_arn" {
  value = aws_kinesis_firehose_delivery_stream.ctr.arn
}

output "glue_database_name" {
  value = aws_glue_catalog_database.reporting.name
}
