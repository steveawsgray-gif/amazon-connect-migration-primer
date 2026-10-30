# Amazon Connect — the contact centre itself.
#
# Architecture notes for review:
# - Identity is CONNECT_MANAGED for the demo. Production answer: SAML federation.
#   Stated plainly here and in ARCHITECTURE.md — no hidden simplifications.
# - Agent users are NOT created by Terraform in this slice. Agents are people with
#   logins and headsets, not resources; the demo provisions them in the console on
#   the Standard Agent routing profile below (checklist Phase 4). Built-in Agent /
#   CallCenterManager security profiles are used; custom profiles are Phase 2.
# - The phone number is claim-only (count-gated). Assigning number → flow is a
#   commissioning step after the plan has been reviewed, never a side effect.

resource "aws_connect_instance" "this" {
  identity_management_type         = "CONNECT_MANAGED"
  instance_alias                   = var.instance_alias
  inbound_calls_enabled            = true
  outbound_calls_enabled           = true
  early_media_enabled              = true
  auto_resolve_best_voices_enabled = true
  contact_flow_logs_enabled        = true
  contact_lens_enabled             = false

  tags = var.common_tags
}

resource "aws_connect_hours_of_operation" "business" {
  instance_id = aws_connect_instance.this.id
  name        = "Business Hours"
  description = "Mon-Fri 08:00-18:00 local — the demo's staffed window"
  time_zone   = var.hours_time_zone

  dynamic "config" {
    for_each = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"]
    content {
      day = config.value
      start_time {
        hours   = 8
        minutes = 0
      }
      end_time {
        hours   = 18
        minutes = 0
      }
    }
  }

  tags = var.common_tags
}

resource "aws_connect_queue" "general" {
  instance_id           = aws_connect_instance.this.id
  name                  = "General Support"
  description           = "Default queue — unknown callers and every fallback land here"
  hours_of_operation_id = aws_connect_hours_of_operation.business.hours_of_operation_id

  tags = var.common_tags
}

resource "aws_connect_queue" "billing" {
  instance_id           = aws_connect_instance.this.id
  name                  = "Billing"
  description           = "Callers with an open billing case, routed by the data dip"
  hours_of_operation_id = aws_connect_hours_of_operation.business.hours_of_operation_id

  tags = var.common_tags
}

resource "aws_connect_queue" "priority" {
  instance_id           = aws_connect_instance.this.id
  name                  = "Priority Support"
  description           = "Priority-tier customers with an open case — first claim on agents"
  hours_of_operation_id = aws_connect_hours_of_operation.business.hours_of_operation_id

  tags = var.common_tags
}

resource "aws_connect_routing_profile" "standard_agent" {
  instance_id               = aws_connect_instance.this.id
  name                      = "Standard Agent"
  description               = "Voice 1-at-a-time, chat up to 3; Priority queue outranks the rest"
  default_outbound_queue_id = aws_connect_queue.general.queue_id

  media_concurrencies {
    channel     = "VOICE"
    concurrency = 1
  }
  media_concurrencies {
    channel     = "CHAT"
    concurrency = 3
  }
  media_concurrencies {
    channel     = "TASK"
    concurrency = 2
  }

  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 1
    queue_id = aws_connect_queue.priority.queue_id
  }
  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 2
    queue_id = aws_connect_queue.general.queue_id
  }
  queue_configs {
    channel  = "VOICE"
    delay    = 0
    priority = 2
    queue_id = aws_connect_queue.billing.queue_id
  }

  tags = var.common_tags
}

# The main inbound flow. Content is rendered from flows/main-inbound-flow.json so
# the flow lives in git as a reviewable file, not as console folklore. Lambda ARN
# and queue ARNs are the only values injected.
resource "aws_connect_contact_flow" "main_inbound" {
  instance_id = aws_connect_instance.this.id
  name        = "Main Inbound - Customer Lookup Routing"
  description = "Greeting -> Lambda customer lookup -> data-driven queue routing -> transfer"
  type        = "CONTACT_FLOW"

  content = templatefile(var.flow_template_path, {
    lambda_function_arn = var.lambda_function_arn
    general_queue_arn   = aws_connect_queue.general.arn
    priority_queue_arn  = aws_connect_queue.priority.arn
    billing_queue_arn   = aws_connect_queue.billing.arn
  })

  tags = var.common_tags
}

# Register the lookup function with the instance so flows may invoke it.
# (The matching resource-based permission lives in modules/customer_data.)
resource "aws_connect_lambda_function_association" "lookup" {
  instance_id  = aws_connect_instance.this.id
  function_arn = var.lambda_function_arn
}

# Recordings → S3. KMS-encrypted bucket owned by modules/storage_analytics.
resource "aws_connect_instance_storage_config" "call_recordings" {
  instance_id   = aws_connect_instance.this.id
  resource_type = "CALL_RECORDINGS"

  storage_config {
    storage_type = "S3"
    s3_config {
      bucket_name   = var.recordings_bucket_id
      bucket_prefix = "recordings"
      encryption_config {
        encryption_type = "KMS"
        key_id          = var.recordings_kms_key_arn
      }
    }
  }
}

resource "aws_connect_instance_storage_config" "chat_transcripts" {
  instance_id   = aws_connect_instance.this.id
  resource_type = "CHAT_TRANSCRIPTS"

  storage_config {
    storage_type = "S3"
    s3_config {
      bucket_name   = var.recordings_bucket_id
      bucket_prefix = "chat-transcripts"
      encryption_config {
        encryption_type = "KMS"
        key_id          = var.recordings_kms_key_arn
      }
    }
  }
}

# Contact Trace Records → Firehose → the reporting lake. This is the feed the
# whole reporting story hangs off (see modules/storage_analytics).
resource "aws_connect_instance_storage_config" "ctr" {
  instance_id   = aws_connect_instance.this.id
  resource_type = "CONTACT_TRACE_RECORDS"

  storage_config {
    storage_type = "KINESIS_FIREHOSE"
    kinesis_firehose_config {
      firehose_arn = var.ctr_firehose_arn
    }
  }
}

# Optional DID. Claiming is explicit (variable-gated) because a held number bills
# monthly. Assignment of number → main flow is a commissioning step
# (aws connect update-phone-number) documented in PHASE_CHECKLIST.md Phase 4.
resource "aws_connect_phone_number" "demo" {
  count = var.claim_phone_number ? 1 : 0

  target_arn   = aws_connect_instance.this.arn
  country_code = var.phone_country_code
  type         = "DID"
  description  = "Project 2 demo inbound DID — assign to Main Inbound flow after apply"

  tags = var.common_tags
}
