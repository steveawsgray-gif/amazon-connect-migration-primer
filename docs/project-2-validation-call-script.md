# Project 2 — Phase 5 Validation Call Script

*Prepared Fri Oct 30, 2026, after Phase 4 commissioning. Steven places these
calls himself, from his own phone. Total telephony cost for the full set:
well under $1 (a few inbound minutes + the DID's small monthly hold fee).*

## The number

**Call: +1 531-247-6511** — the instance's claimed US DID, associated with
the **Main Inbound - Customer Lookup Routing** flow (status: PUBLISHED).

Instance: https://sgray-connect-migration-primer.my.connect.aws/
Business Hours of operation: **Mon–Fri 08:00–18:00 America/Toronto** — run
the live tests inside that window so queue transfers behave as designed.
(Outside the window, queues are unstaffed by design and calls wait/queue
per the customer-queue flow rather than reaching an agent.)

## Already verified without a phone (Oct 30, by direct Lambda invocation)

The customer-lookup data dip returns exactly the designed routing for
every seed identity — this is the brain of the flow, proven before any
call is placed:

| Caller number presented | Result |
|---|---|
| +1 613-555-0101 (Avery Collins) | found → **Priority Support**, open case CASE-1042, greeted by name |
| +1 416-555-0102 (Jordan Lee) | found → **Billing**, open case CASE-2077 |
| +1 514-555-0103 (Sam Tremblay) | found → **General Support**, no open case |
| Any unknown number | not found → **General Support** fallback, no error |

## Live calls Steven places (in order)

**Before calling:** sign in to the agent desktop (Contact Control Panel) as
`demo.agent1` in a browser tab, status Available, so queued calls have
somewhere to land. (Credentials: see Vivienne — stored privately, not in
this document.)

1. **Unknown-caller test (his own mobile — it is not a seed number).**
   Dial +1 531-247-6511.
   Expect: greeting plays, the lookup misses, and the call routes to
   **General Support** — no error, no dead air. Answer it in the CCP as
   demo.agent1, confirm two-way audio, hang up.
   *This single call proves the whole telephony path end to end: DID →
   flow → Lambda dip → queue → agent desktop.*

2. **Recording check (after call 1).** In the console or S3: the call
   recording appears in the `connect-centre-dev-recordings-258032684610`
   bucket under `recordings/`, KMS-encrypted.

3. **CTR check (after call 1, allow a few minutes).** The contact trace
   record streams via Firehose into the CTR lake bucket; the Athena
   starter query (scaffold `docs/ctr-athena-ddl.sql`) returns the call's
   row.

4. **Seed-identity behaviour (optional, read-only).** The Avery/Jordan/Sam
   routings above were proven at the Lambda layer. They cannot be
   re-proven from Steven's own handset because inbound routing keys on
   the *caller's* number, and his number is none of the seeds. If a live
   seed test is ever wanted, the honest way is to add his mobile as a
   temporary fourth seed row (pointed at Priority), call once, then
   delete the row — a Phase 5+ exercise, not needed for the demo story.

5. **Fallback test (optional, checklist item 4).** With the Lambda
   association temporarily removed in the console, a call still routes to
   General Support (the flow's error branch), and the lookup error alarm
   notifies via SNS. Restore the association afterwards. Skip unless a
   full failure-mode demo is wanted.

## Pass criteria

- [ ] Call 1 reaches General Support and an agent; audio both ways
- [ ] Recording present in S3, KMS-encrypted
- [ ] CTR row queryable in Athena
- [ ] Nothing in the flow errored (Flow logs in CloudWatch / Connect
      contact search show a clean trace)

## Cost note

DID hold: a small monthly fee while claimed (release it with
`terraform destroy` of the phone resource / console if the demo sleeps —
see PHASE_CHECKLIST Phase 7). Inbound minutes at demo volume: cents.
**Total Phase 5 spend target: well under $1.**
