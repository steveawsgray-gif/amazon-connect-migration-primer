# Architecture — Amazon Connect Contact Centre (Project 2)

## 1. Scenario

"NorthStar Support" is a fictional mid-size services company running an aging
on-prem PBX estate (Avaya/Cisco) with third-party reporting bolted on. Leadership
wants a cloud contact centre without a big-bang cutover. This project is **slice one**
of that migration: inbound voice, done properly, small enough to demo in an afternoon
and honest enough to survive an architect's questions.

## 2. The call, step by step

```
Caller ──► DID number ──► Amazon Connect instance
                              │  Main Inbound flow
                              ├─ 1. Flow logging ON (CloudWatch Logs)
                              ├─ 2. Recording behaviour set (agent + customer)
                              ├─ 3. Greeting prompt
                              ├─ 4. Invoke Lambda: customer lookup (caller ID)
                              │        └─► DynamoDB customer directory
                              ├─ 5. Branch on $.External.routingQueue
                              │        ├─ Priority ─► Priority Support queue
                              │        ├─ Billing  ─► Billing queue
                              │        └─ General  ─► General Support queue (default)
                              └─ 6. Transfer to queue ─► agent (CCP)
Side streams:
  Call recordings ─► S3 (KMS, versioned, lifecycle to Glacier)
  Contact Trace Records ─► Kinesis Firehose ─► S3 lake ─► Glue/Athena ─► (QuickSight next phase)
```

**The design decision that matters:** routing is *data-driven*, not menu-driven.
The Lambda function — not the caller — decides the queue, from the customer's own
record: an open escalated case outranks a keypad press. Unknown callers default to
General Support. Nobody reaches a dead end, and nobody has to know the org chart
to get help. That is the difference between an IVR tree and an architecture.

## 3. Components and why each earned its place

- **Amazon Connect instance (CONNECT_MANAGED identity).** Demo-simple identity;
  production answer is SAML federation — the trade-off is stated, not hidden.
- **Queues: General Support, Billing, Priority Support.** Three is enough to prove
  priority routing without inventing a department store.
- **Routing profile "Standard Agent."** Voice concurrency 1 (a voice call is a
  one-at-a-time commitment), chat concurrency 3, queue priorities 1/2/2. This is
  where workforce reality lives in Connect — priorities, not hopes.
- **Hours of operation:** Mon–Fri 08:00–18:00 America/Toronto, attached to queues.
- **Lambda customer lookup.** Synchronous, 8-second ceiling (Connect's own limit),
  returns a flat STRING_MAP — Connect cannot consume nested JSON from a flow, and
  designing to that contract is the whole game. Least-privilege role: `GetItem` on
  one table, logs, nothing else.
- **DynamoDB customer directory.** Keyed by caller phone number (E.164). On-demand
  billing: a directory that is read in bursts and sleeps the rest of the day has no
  business paying for provisioned capacity. Point-in-time recovery on — it is a
  system of record, however small.
- **S3 for recordings, KMS-encrypted, versioned, public access blocked, lifecycle
  to Glacier at 90 days, expiry at 365.** Recordings are evidence. Treat them like it.
- **CTR pipeline: Firehose → S3 → Glue/Athena.** Contact Trace Records are the
  contact centre's memory. Streaming them to a queryable lake replaces the legacy
  pattern — a vendor reporting black box — with SQL the business owns. This is the
  TASKE reporting story, rebuilt on open rails. QuickSight dashboards are Phase 2.
- **CloudWatch alarm on Lambda errors → SNS topic.** If the data dip breaks, the
  flow still routes (General queue fallback), but someone hears about it.

## 4. Security posture

- No credentials anywhere in code; the Lambda role is the only identity the lookup has.
- Recordings bucket: Block Public Access on all four switches, KMS default encryption,
  versioning on. Bucket policies deny non-TLS transport (documented production step).
- Callers are identified by phone number for *routing convenience only* — the design
  notes are explicit that caller ID is not authentication. A production build adds a
  PIN or voice-ID step before anything sensitive is spoken. The demo never speaks
  account data back; it only routes.
- Agent users are provisioned in Connect (built-in Agent / CallCenterManager security
  profiles for the demo); custom security profiles are a documented Phase 2 item.

## 5. Well-Architected mapping

- **Reliability:** every failure branch in the flow lands somewhere staffed (General
  queue). Lambda failure ≠ call failure. Multi-AZ is inherited from Connect itself —
  and the design says so, rather than claiming credit for it.
- **Security:** least-privilege IAM, encrypted recordings, no public exposure,
  caller-ID-is-not-auth called out in writing.
- **Cost optimisation:** on-demand DynamoDB, per-minute Connect pricing, lifecycle
  policies, and a destroy path. Idle demo cost rounds to zero.
- **Operational excellence:** flows as versioned JSON in git, infrastructure as
  Terraform, alarms on the one integration that can silently rot.
- **Performance:** the data dip is one GetItem — single-digit milliseconds — well
  inside Connect's 8-second Lambda budget.

## 6. The migration story (how this sells in the room)

Real Avaya/Cisco → Connect migrations die in discovery, not in the console. The
sequence this slice implies: inventory the call flows and reports people actually
use → rebuild one flow as a Connect vertical slice (this project) → port numbers in
waves → run both platforms in parallel → cut over queue by queue → rebuild the
reporting catalogue on the CTR lake so supervisors keep their numbers on day one.
Steven ran reporting for 2,500+ agent centres; the reporting-parity point is not a
feature bullet, it is the reason migrations get signed.

## 7. Interview talk track

- **"Why Lambda in the flow instead of a bigger IVR menu?"** — Because the customer's
  record knows more than the customer's keypad. Data-driven routing shortens calls
  and puts open cases in front of the right people first.
- **"Why DynamoDB and not RDS for the directory?"** — Single-key lookups, bursty
  reads, no connections to manage from Lambda, on-demand pricing. RDS would be
  ceremony without benefit at this access pattern.
- **"Why Firehose/Athena instead of Connect's built-in reports?"** — Built-in reports
  answer yesterday's questions. The CTR lake answers tomorrow's: any field, any join,
  owned by the business. That is the reporting layer I spent a career selling.
- **"What breaks first at 10× volume?"** — Not Connect. The DynamoDB on-demand table
  and Lambda concurrency are the watch items; both are alarms-and-limits problems,
  not redesign problems. Number porting and agent desktop readiness break migrations
  before technology does.
- **"What would production add?"** — SAML identity, custom security profiles, Lex
  for natural-language entry, callback queues, QuickSight on the CTR lake, WFM,
  and a second region strategy for the telephony estate.

## 8. Known limits (stated on purpose)

- Flow JSON must be validated in Flow Designer at first deploy; treat the file as
  the reviewed design, the designer as the commissioning step.
- Phone-number-to-flow assignment is a post-apply step (checklist Phase 4) — the
  number resource is claim-only in Terraform by design, so a demo never silently
  grabs a number before the plan is reviewed.
- CTR Athena DDL is a starter column set; production extends it or runs a Glue crawler.
