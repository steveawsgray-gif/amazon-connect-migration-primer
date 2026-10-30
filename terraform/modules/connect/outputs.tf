output "instance_id" {
  value = aws_connect_instance.this.id
}

output "instance_arn" {
  value = aws_connect_instance.this.arn
}

output "instance_access_url" {
  value = "https://${var.instance_alias}.my.connect.aws/"
}

output "main_flow_id" {
  value = aws_connect_contact_flow.main_inbound.id
}

output "queue_ids" {
  value = {
    general  = aws_connect_queue.general.id
    billing  = aws_connect_queue.billing.id
    priority = aws_connect_queue.priority.id
  }
}

output "claimed_phone_number" {
  value = var.claim_phone_number ? aws_connect_phone_number.demo[0].phone_number : "(not claimed — claim_phone_number = false)"
}
