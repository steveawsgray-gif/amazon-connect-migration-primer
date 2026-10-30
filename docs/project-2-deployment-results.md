# Project 2 — Deployment Results (FINAL, 2026-10-30)

*Supersedes the Oct 22 DRAFT. Phases 1–3 built Oct 22; Phase 4 commissioned
and Phase 5 prepared Oct 30, 2026, on Steven's go ("proceed with all").*

## Status line

> **Status (2026-10-30): DEPLOYED AND COMMISSIONED.** All 36 Terraform
> resources from the Oct 22 apply are live, plus Phase 4 additions: a
> claimed US DID (**+1 531-247-6511**) associated with the Main Inbound
> flow, two demo agent users, and an admin user for Steven. A final
> `terraform plan` reports **no changes** — configuration and account
> agree. Instance: https://sgray-connect-migration-primer.my.connect.aws/
> Remaining: Steven's Phase 5 validation calls (script ready), Phase 6
> screenshots, and Phase 7 (decided — see below).

## What is live (verified against the account, 2026-10-30)

- Amazon Connect instance `sgray-connect-migration-primer` — ACTIVE,
  CONNECT_MANAGED identity, inbound + outbound enabled (us-east-1)
- **Phone number: +1 531-247-6511** (US DID, status CLAIMED), associated
  with the **Main Inbound - Customer Lookup Routing** flow. The flow's
  status is **PUBLISHED** (verified Oct 30; every flow on the instance is
  published)
- Queues: General Support, Billing, Priority Support (plus built-in
  BasicQueue), all on Business Hours (Mon–Fri 08:00–18:00 America/Toronto)
- Routing profile: Standard Agent (voice 1, chat 3, task 2; Priority queue
  outranks the rest)
- **Users (created Oct 30):**
  - `demo.agent1` — Agent security profile, Standard Agent routing
  - `demo.agent2` — Agent security profile, Standard Agent routing
  - `steven.gray` — **Admin** security profile, Standard Agent routing
  - Passwords are stored only in the goal's private (hidden) files, never
    in this document or any repo. **Steven: change the `steven.gray`
    password at first login** — sign in at the instance URL above, or via
    console: Amazon Connect → instance → Users → steven.gray
  - Placeholder `@example.com` email addresses were used; Steven can set
    real ones in the console at any time
- Lambda: `connect-centre-dev-customer-lookup`, associated with the
  instance; invoked directly on Oct 30 with the real Connect event shape,
  it returns exactly the designed routing for every seed identity:
  Avery Collins → Priority (case CASE-1042), Jordan Lee → Billing
  (CASE-2077), Sam Tremblay → General, unknown caller → General fallback
- DynamoDB customer directory, seeded and verified row by row (as above)
- S3: recordings bucket and CTR-lake bucket; call-record stream via
  Firehose; storage configs for recordings, chat transcripts, and CTRs

## Defects found and fixed (interview-grade detail)

*Oct 22 build (3):* (1) queues/routing profile needed the provider's bare
`hours_of_operation_id` / `queue_id` attributes, not composite IDs;
(2) Firehose error-output prefix needed the `!{firehose:error-output-type}`
marker; (3) flow transfer blocks rebuilt as `TransferContactToQueue` with
error transitions to an ErrorDisconnect prompt + clean Disconnect.

*Oct 30 commissioning (1):* (4) `aws_connect_user` creation failed with
Connect's opaque "Invalid parameter: null". Isolated by capturing the
provider's actual API request: the security/routing **data sources' `.id`
is the composite `instance:profile` string**, and CreateUser rejects it.
Same root-cause family as defect (1) — fixed by using the bare
`security_profile_id` / `routing_profile_id` attributes. All three users
then created cleanly and Terraform converged. (Two earlier theories —
missing email, dropped AutoAccept flag — were tested against the live API
and ruled out with evidence.)

## Phase 5 — validation calls (ready for Steven)

Script: `files/project-2-validation-call-script.md`. Steven dials
**+1 531-247-6511** from his own phone (an unknown number → General
Support path), signed into the CCP as demo.agent1, inside business hours;
then confirms the recording in S3 and the CTR row in Athena. The
seed-identity routings are already proven at the Lambda layer (above) —
they key on the caller's number, so they cannot be re-proven from his
handset without adding a temporary seed row. Expected total telephony
cost: well under $1.

## Phase 7 — decision (recorded in the design document)

**DECIDED Fri Oct 30, 2026 by Steven:** Phase 7 adds the AI layer to
**this** project using **Amazon Connect's own AI agents (native)**,
reusing the existing Lambda and queues. Amazon Bedrock AgentCore is not
part of this project — it becomes a separate, small, focused project
afterwards (held, post-cert). Full record:
`files/project-2-phase7-autonomous-agent-DESIGN.md`. No Phase 7 building
yet.

## Cost

- Oct 22 build: effectively $0 (idle instance, no number, no calls)
- Oct 30: DID claim — small monthly hold fee while claimed (release via
  Terraform/console if the demo sleeps); users and flow association: $0;
  validation calls at demo volume: cents. **Phase 4–5 spend: under ~$2.**
- Standing cost while the DID is held: the number's monthly fee only;
  everything else is usage-priced and idle at $0.

## GitHub / repository status

**There is no git repository for this project yet** — the scaffold lives
in the goal workspace only, and no remote exists. Nothing was committed
or pushed on Oct 30. The finalized README text is saved alongside this
document (`files/project-2-README.md`); creating the GitHub repo and
pushing is a separate step on Steven's word. Note the scaffold's own
README in the workspace still carries its stale Oct 21 "Nothing is
deployed" status — superseded by this document and the goal-files README.
