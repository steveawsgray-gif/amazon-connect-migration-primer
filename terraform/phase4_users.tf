# Phase 4 (2026-10-30) — Connect users, added additively at root level.
# The connect module's design note left agents to console provisioning; Phase 4
# commissions them in code instead so the demo is reproducible. Passwords are
# supplied via phase4.auto.tfvars.json (mode 600, never committed) and mirrored
# in the goal's hidden_files/demo-agent-credentials.txt for Steven.

variable "demo_agent1_password" {
  type      = string
  sensitive = true
}

variable "demo_agent2_password" {
  type      = string
  sensitive = true
}

variable "steven_admin_password" {
  type      = string
  sensitive = true
}

data "aws_connect_security_profile" "agent" {
  instance_id = module.connect.instance_id
  name        = "Agent"
}

data "aws_connect_security_profile" "admin" {
  instance_id = module.connect.instance_id
  name        = "Admin"
}

data "aws_connect_routing_profile" "standard_agent" {
  instance_id = module.connect.instance_id
  name        = "Standard Agent"
}

resource "aws_connect_user" "demo_agent1" {
  instance_id        = module.connect.instance_id
  name               = "demo.agent1"
  password           = var.demo_agent1_password
  security_profile_ids = [data.aws_connect_security_profile.agent.security_profile_id]
  routing_profile_id = data.aws_connect_routing_profile.standard_agent.routing_profile_id

  identity_info {
    first_name    = "Demo"
    last_name     = "Agent One"
    email         = "demo.agent1@example.com"
  }

  phone_config {
    phone_type                    = "SOFT_PHONE"
    auto_accept                   = false
    after_contact_work_time_limit = 30
  }

  tags = local.common_tags
}

resource "aws_connect_user" "demo_agent2" {
  instance_id        = module.connect.instance_id
  name               = "demo.agent2"
  password           = var.demo_agent2_password
  security_profile_ids = [data.aws_connect_security_profile.agent.security_profile_id]
  routing_profile_id = data.aws_connect_routing_profile.standard_agent.routing_profile_id

  identity_info {
    first_name    = "Demo"
    last_name     = "Agent Two"
    email         = "demo.agent2@example.com"
  }

  phone_config {
    phone_type                    = "SOFT_PHONE"
    auto_accept                   = false
    after_contact_work_time_limit = 30
  }

  tags = local.common_tags
}

resource "aws_connect_user" "steven_admin" {
  instance_id        = module.connect.instance_id
  name               = "steven.gray"
  password           = var.steven_admin_password
  security_profile_ids = [data.aws_connect_security_profile.admin.security_profile_id]
  routing_profile_id = data.aws_connect_routing_profile.standard_agent.routing_profile_id

  identity_info {
    first_name    = "Steven"
    last_name     = "Gray"
    email         = "steven.gray@example.com"
  }

  phone_config {
    phone_type                    = "SOFT_PHONE"
    auto_accept                   = false
    after_contact_work_time_limit = 30
  }

  tags = local.common_tags
}
