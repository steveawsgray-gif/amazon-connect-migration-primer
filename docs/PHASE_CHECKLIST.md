# Phase Checklist — Project 2: Amazon Connect Contact Centre

## Phase 0 — Design (done 2026-10-21)
- [x] Scenario fixed: legacy → Connect migration, slice one (inbound voice)
- [x] Architecture + trade-offs written (`ARCHITECTURE.md`)
- [x] Flow designed: data-driven routing via Lambda data dip, General-queue fallback
- [x] Scaffold written: Terraform modules, flow JSON, Lambda, seed data

## Phase 1 — Pre-deploy review (Steven)
- [x] Read `ARCHITECTURE.md` end to end — Steven, 2026-10-22: "clear to me and well thought out in the context of the migrations story." No voice marks.
- [x] Instance alias chosen by Steven 2026-10-22: `sgray-connect-migration-primer` (set in `terraform.tfvars`); region `us-east-1` confirmed by Steven 2026-10-22
- [x] Phone number claim: OFF for the first apply (confirmed by Steven 2026-10-22)

## Phase 2 — Credential gate (same gate as Project 1)
- [x] AWS IAM access key provided 2026-10-22 — IAM user `vivienne-projects` (AdministratorAccess, created by Steven in his own account); pair stored in ~/.aws/credentials on Vivienne's machine (values never recorded elsewhere). Verified working via terraform plan (STS auth OK after trimming a stray trailing character from the pasted secret).
- [x] `terraform plan` run 2026-10-22 — **36 to add, 0 to change, 0 to destroy**. Full plan saved for Steven's review: goal files/project-2-terraform-plan-oct22.txt
- [x] Apply authorized by Steven 2026-10-22 ("Apply please")

## Phase 3 — Build — COMPLETE 2026-10-22
- [x] `terraform apply` — all 36 resources live in Steven's account; a fresh
      plan afterwards reports no differences. Instance:
      https://sgray-connect-migration-primer.my.connect.aws/
- [x] Main Inbound flow created and accepted by Connect's own validation.
      Three scaffold defects found and fixed during the apply (same scope,
      nothing added or dropped): (1) queues/routing profile now use the
      provider's bare `hours_of_operation_id` / `queue_id` attributes instead
      of the composite `.id`; (2) Firehose error_output_prefix now includes
      `!{firehose:error-output-type}`; (3) flow transfer blocks are
      `TransferContactToQueue` with NextAction + error transitions to a new
      ErrorDisconnect prompt + Disconnect action (the flow's only design
      addition, an error exit). Root causes proven by direct API probes
      against the live instance before patching.
- [ ] (Optional) Open the Main Inbound flow in Flow Designer for a visual pass

## Phase 4 — Commission the number — COMPLETE 2026-10-30
- [x] Claim DID (Terraform) — **+1 531-247-6511** (US DID; Steven approved
      2026-10-30, "proceed with all"; tfvars flipped to claim=true, US)
- [x] Assign the number to the Main Inbound flow — done via the
      AssociatePhoneNumberContactFlow API (the update-phone-number route
      rejects a flow ARN; association verified, and a follow-up
      `terraform plan` shows no drift)
- [x] Create 2 demo agent users (built-in Agent security profile,
      Standard Agent routing profile) — `demo.agent1`, `demo.agent2`,
      created in Terraform (`phase4_users.tf`). One real defect found and
      fixed on the way: the profile data sources' composite `.id` is
      rejected by CreateUser ("Invalid parameter: null"); the bare
      `security_profile_id` / `routing_profile_id` attributes are the fix
- [x] Admin user for Steven — `steven.gray` (Admin security profile);
      password stored only in the goal's hidden files; Steven to change
      it at first login. Passwords for all three users live in
      goal hidden_files/demo-agent-credentials.txt (mode 600)
- Note: demo users carry placeholder @example.com emails for now

## Phase 5 — Validation tests (the demo script)
- Prepared 2026-10-30: call script written to goal
  files/project-2-validation-call-script.md. The Lambda data dip was
  invoked directly with the real Connect event shape and returns the
  designed routing for all three seeds + the unknown-caller fallback —
  items 1–3 are proven at the routing layer; the live telephony pass
  (Steven dialling +1 531-247-6511 from his own phone = the
  unknown-caller path, item 3) is his to run inside business hours.
1. [ ] Call from the "Avery Collins" seed number → lands in **Priority Support**,
       hears the open-case greeting with her name
       (routing proven at Lambda layer 2026-10-30; a live seed call needs
       a temporary seed row for Steven's own number — see the script)
2. [ ] Call from the "Jordan Lee" seed number → lands in **Billing**
3. [ ] Call from an unknown number → lands in **General Support**, no error, no dead air
4. [ ] Kill the Lambda (disable association) → calls still route to General;
       alarm fires to the SNS topic
5. [ ] Recording appears in the S3 recordings bucket, KMS-encrypted
6. [ ] CTR for the test calls appears in the lake bucket; Athena query returns rows

## Phase 6 — Package
- [ ] Screenshots: flow in designer, agent CCP, Athena result
- [x] README results section filled; cost of the exercise recorded —
      finalized 2026-10-30 as goal files/project-2-deployment-results.md
      with a README-form version at goal files/project-2-README.md
- [ ] Push to GitHub alongside Project 1 — **no git repository exists
      for this project yet** (checked 2026-10-30: no .git, no remote);
      repo creation waits on Steven's word

## Phase 7 (design doc) — AI agent tier — DECIDED 2026-10-30
- Steven: the AI layer is added to THIS project using Amazon Connect's
  own AI agents (native), reusing the Lambda + queues. Amazon Bedrock
  AgentCore is NOT part of this project — separate small project later
  (held, post-cert). Record:
  goal files/project-2-phase7-autonomous-agent-DESIGN.md. Not built yet.

## Phase 7 — Teardown
- [ ] `terraform destroy`; confirm instance, buckets, and number released
- ⚠️ A claimed DID bills monthly while held. Release it if the demo sleeps.
