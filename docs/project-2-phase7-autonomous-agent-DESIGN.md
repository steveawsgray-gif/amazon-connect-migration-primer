# Project 2 — Phase 7 (optional): Autonomous Agent Tier — DESIGN ONLY

*Drafted 2026-10-22 evening, from Steven's question in chat: "Can an
autonomous agent be built with AWS tools that could be configured as an
agent in Connect?" Nothing here is built, deployed, or authorized. It is
sequenced AFTER Phase 4 (admin user / number), Phase 5 (validation calls)
and Phase 6 (GitHub packaging), and after the Oct 24 timed exam. It does
not compete with Saturday.*

## Decision — Fri Oct 30, 2026

**DECIDED Fri Oct 30, 2026 by Steven:** Phase 7 adds the AI layer to
**this** Connect project using **Amazon Connect's own AI agents (native)**,
reusing the existing Lambda customer lookup and the three queues. **Amazon
Bedrock AgentCore is NOT part of this project** — it becomes a separate,
small, focused project afterwards (held, post-cert). This restores this
document's original **Route 1** as the decision, with AgentCore split out
as its own mini-project. (An earlier same-day framing — AgentCore inside
this project, and talk of a separate "Advanced Connect" project — was
superseded by this wording before anything was built.)

## The one-sentence design

Put a bounded AI agent in front of the three queues Steven already built:
it identifies the caller using the *existing* Lambda data dip, answers the
questions that are safe to answer alone, and hands everything else to
Priority / Billing / General with full context — the autonomous tier
resolves what it can, humans catch the rest.

## Recommended route (of the three discussed in chat, 2026-10-22)

**Start with Route 1 — Connect's own AI agents.** AWS's Connect admin
guide describes AI agents built on Amazon Bedrock that engage customers
over voice and chat, answer questions, take actions via integrated tools,
and escalate to a human agent when needed, with custom prompts, AI
guardrails, and knowledge-base integration, configurable in the Connect
UI or via API:
https://docs.aws.amazon.com/connect/latest/adminguide/connect-ai-agent.html

Why Route 1 first for the demo: least new plumbing, lives inside the
instance Steven already owns, and the escalation path *is* his existing
flow — no second system to explain in an interview.

**Route 2 (later, if he wants the architect's version):** a Bedrock agent
as the brain behind Lex/Lambda in the flow. Note for 2026 accuracy:
classic Bedrock Agents is in maintenance for new customers; net-new
agent builds should target **Bedrock AgentCore** (Runtime / Gateway /
Memory / Identity). AgentCore is consumption-priced with no minimum —
Runtime from $0.0895 per vCPU-hour and $0.00945 per GB-hour, Gateway
$0.005 per 1,000 invocations, plus Bedrock model tokens:
https://aws.amazon.com/bedrock/agentcore/pricing/
At demo scale (a handful of test calls) the agent tier costs cents, but
it is NOT free like the idle instance — flag this before any build.

## How it reuses what is already live (verified 2026-10-22)

- **The tool the agent calls already exists:** Lambda
  `connect-centre-dev-customer-lookup` — caller ID → DynamoDB customer
  row → assigned queue + open-case flag. That is exactly an agent action:
  Avery Collins calls, the agent looks her up before it speaks.
- **The escalation targets already exist:** Priority Support, Billing,
  General Support queues and the Standard Agent routing profile.
- **The knowledge source is already half-built:** the CTR lake (S3 +
  Firehose + Athena DDL in the scaffold) is the analytics side; a small
  Bedrock Knowledge Base over 3–5 written policy pages (hours, billing
  FAQ, case-status wording) is the agent's reading material.
- **The safety rail already exists in the flow:** the ErrorDisconnect
  pattern fixed during the deploy — the agent tier gets the same rule:
  on any failure or low confidence, transfer, never improvise.

## The autonomy dial (Steven's own rule, applied)

- **Agent may resolve alone:** identity + case-status lookup ("your case
  is open, assigned to Billing"), business hours, queue routing questions.
- **Agent must hand off:** anything that changes state (payments, account
  changes), anything emotional, anything it cannot ground in the lookup
  or the knowledge base. Handoff carries the transcript + lookup result,
  so the human never re-asks.
- **Success metric for the demo:** cost per *resolved* contact, not
  deflection rate — the line he already uses.

## Demo script (extends the Phase 5 validation calls)

1. Avery (known, Priority, open case) → agent greets her by name, states
   her case status, offers Priority transfer; she accepts → lands in
   Priority with context.
2. Unknown number → agent cannot identify → no dead air, straight to
   General, same as the Phase 5 fallback test.
3. Billing question inside the knowledge base → agent answers alone,
   contact ends resolved, CTR lands in the lake; Athena query shows it.

## Interview bridge (why this phase exists)

This is the IQ lesson, rebuilt forward: Avaya sold a lake-shaped
analytics tool as a replacement for the real-time stream supervisors
lived in. The agent tier makes the same category error impossible to
hide — the design says out loud which work is stream (real-time,
human, now) and which is agent/lake (bounded, lookup-driven,
escalating). A candidate who can draw that line from lived vendor
experience is the pitch.

## Decisions left to Steven (none urgent)

1. ~~Build Phase 7 at all~~ — **Resolved Oct 30, 2026: yes, as a phase of
   this project** (see the Decision section at the top of this document).
2. ~~Route order~~ — **Resolved Oct 30, 2026:** Connect's own AI agents
   inside this project (Route 1); AgentCore is a separate later
   mini-project, not part of Project 2 (see Decision section).
3. Accept the small running cost once an agent + number are live
   (release the DID / disable the agent when the demo sleeps).
