# Project 2 — Amazon Connect Contact Centre

<img width="2835" height="1710" alt="image" src="https://github.com/user-attachments/assets/55f5c6b6-326a-4c2c-aa75-1294b60bd3c1" />


**A target-state slice of a legacy contact-centre migration (Avaya/Cisco →
Amazon Connect), built as a portfolio example.**

A caller dials in. Before an agent ever says hello, the contact flow
quietly looks the caller up in DynamoDB via Lambda, learns who they are
and what they have open, and routes them to the right queue — priority
case, billing case, or general support. Recordings land encrypted in S3.
Every contact trace record streams out through Kinesis Firehose into an
S3 data lake that Athena can query — the reporting layer a legacy shop
would otherwise buy as a black box.

## Why this project exists

Forty years of contact-centre work (TASKE: 2,500+ agent centres on Avaya
and Cisco) says the first deliverable of any real migration is never "the
whole platform." It is one working vertical slice: one inbound flow, one
data dip, a handful of queues done properly, and reporting you can see
into. That slice is what this project builds.

## Status (2026-10-30): DEPLOYED AND COMMISSIONED

- **Instance:** `sgray-connect-migration-primer` (us-east-1) —
  https://sgray-connect-migration-primer.my.connect.aws/
- **Phone number:** **+1 531-247-6511** (US DID), associated with the
  Main Inbound flow (PUBLISHED)
- **Users:** two demo agents (`demo.agent1`, `demo.agent2`, Agent
  profile) and an admin user — all on the Standard Agent routing profile
- **Flow:** "Main Inbound - Customer Lookup Routing" — greeting → Lambda
  data dip → three-way branch on the caller's assigned queue → transfer
- **Queues:** Priority Support, Billing, General Support — Business Hours
  Mon–Fri 08:00–18:00 America/Toronto
- **Verified routing** (Lambda invoked with the real Connect event shape,
  Oct 30): Avery Collins → Priority (open case), Jordan Lee → Billing
  (open case), Sam Tremblay → General, unknown caller → General fallback
- **Cost so far:** effectively nothing beyond the DID's small monthly
  hold fee; the idle platform is usage-priced at $0

Full detail — including four real defects found against the live service
and fixed — lives in the deployment results document
(`project-2-deployment-results.md` in the project files).

## What is in the box

| Piece | Where | What it does |
|---|---|---|
| Connect instance | Terraform `modules/connect` | Instance, business hours, 3 queues, routing profile, main flow, storage configs, phone number |
| Customer data dip | Terraform `modules/customer_data` | DynamoDB customer directory (seeded), Lambda lookup, least-privilege IAM, error alarm |
| Storage & reporting | Terraform `modules/storage_analytics` | KMS key, recordings bucket, CTR lake bucket, Firehose delivery, Glue database, Athena workgroup |
| Main inbound flow | `flows/main-inbound-flow.json` | Connect flow-language JSON: logging → recording → greeting → Lambda lookup → queue routing → transfer |
| Lookup function | `lambda/customer_lookup/handler.py` | Returns a flat STRING_MAP (customerFound, customerName, accountTier, routingQueue, openCase, caseId) |
| Demo callers | `sample-data/customers.seed.json` | Three fictional callers mirroring the seeded DynamoDB items |
| CTR starter DDL | `docs/ctr-athena-ddl.sql` | Athena table over the Firehose-delivered contact trace records |
| Users (Phase 4) | Terraform `phase4_users.tf` | Two demo agents + the owner's admin user, commissioned in code |

Everything is Terraform-managed; a fresh `terraform plan` against the
account reports no changes.

## What's next

- **Phase 5 — validation calls:** the owner dials the number and walks
  the script (unknown-caller path live; recording → S3; CTR → Athena)
- **Phase 6 — packaging:** screenshots (flow designer, agent desktop,
  Athena result) to sit alongside this README
- **Phase 7 — AI agent tier (DECIDED Oct 30, 2026):** Amazon Connect's
  own AI agents, native to this project, reusing the same Lambda lookup
  and queues — the agent resolves what is safe to resolve alone and hands
  the rest to a human with full context. (Amazon Bedrock AgentCore is a
  separate later mini-project, deliberately not part of this one.)
- **Teardown:** `terraform destroy` releases everything, including the
  number. A claimed DID bills monthly while held — release it if the
  demo sleeps.
