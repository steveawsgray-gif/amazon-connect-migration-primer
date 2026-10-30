# Storage & reporting — where the evidence lives.
#
# Two buckets, two jobs, never merged:
# - recordings: call recordings + chat transcripts. Sensitive, KMS-encrypted,
#   versioned, glaciered at 90 days, gone at 365.
# - analytics: Contact Trace Records via Firehose, partitioned by date, queried
#   with Athena against the Glue database. This is the reporting layer the
#   business owns — the anti-black-box.

resource "aws_kms_key" "connect_data" {
  description             = "Project 2 — encrypts Connect recordings and the CTR lake"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags                    = var.common_tags
}

resource "aws_kms_alias" "connect_data" {
  name          = "alias/${var.project_name}-${var.environment}-connect-data"
  target_key_id = aws_kms_key.connect_data.key_id
}

# ---------------------------------------------------------------- recordings ---
resource "aws_s3_bucket" "recordings" {
  bucket = "${var.project_name}-${var.environment}-recordings-${var.account_id}"
  tags   = var.common_tags
}

resource "aws_s3_bucket_versioning" "recordings" {
  bucket = aws_s3_bucket.recordings.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "recordings" {
  bucket = aws_s3_bucket.recordings.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.connect_data.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "recordings" {
  bucket                  = aws_s3_bucket.recordings.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "recordings" {
  bucket = aws_s3_bucket.recordings.id
  rule {
    id     = "archive-then-expire"
    status = "Enabled"
    filter {}
    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
    expiration {
      days = 365
    }
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# ----------------------------------------------------------------- analytics ---
resource "aws_s3_bucket" "analytics" {
  bucket = "${var.project_name}-${var.environment}-ctr-lake-${var.account_id}"
  tags   = var.common_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "analytics" {
  bucket = aws_s3_bucket.analytics.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.connect_data.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "analytics" {
  bucket                  = aws_s3_bucket.analytics.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Firehose delivery role: write CTR objects into the lake, nothing else.
data "aws_iam_policy_document" "firehose_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "firehose" {
  name               = "${var.project_name}-${var.environment}-ctr-firehose"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume.json
  tags               = var.common_tags
}

data "aws_iam_policy_document" "firehose" {
  statement {
    sid = "DeliverToLake"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
    ]
    resources = [
      aws_s3_bucket.analytics.arn,
      "${aws_s3_bucket.analytics.arn}/*",
    ]
  }
  statement {
    sid       = "UseDataKey"
    actions   = ["kms:Encrypt", "kms:GenerateDataKey", "kms:Decrypt", "kms:DescribeKey"]
    resources = [aws_kms_key.connect_data.arn]
  }
}

resource "aws_iam_role_policy" "firehose" {
  name   = "ctr-delivery"
  role   = aws_iam_role.firehose.id
  policy = data.aws_iam_policy_document.firehose.json
}

resource "aws_kinesis_firehose_delivery_stream" "ctr" {
  name        = "${var.project_name}-${var.environment}-ctr"
  destination = "extended_s3"
  tags        = var.common_tags

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = aws_s3_bucket.analytics.arn
    prefix              = "ctr/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "ctr-errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    buffering_interval  = 300
    buffering_size      = 64
    compression_format  = "GZIP"
    kms_key_arn         = aws_kms_key.connect_data.arn
  }
}

resource "aws_glue_catalog_database" "reporting" {
  name        = "connect_reporting"
  description = "Project 2 — queryable home for Contact Trace Records (see docs/ctr-athena-ddl.sql)"
}

resource "aws_athena_workgroup" "reporting" {
  name = "${var.project_name}-${var.environment}-reporting"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.analytics.id}/athena-results/"
      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = aws_kms_key.connect_data.arn
      }
    }
  }

  tags = var.common_tags
}
