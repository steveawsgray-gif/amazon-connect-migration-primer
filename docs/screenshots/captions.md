# Console evidence — captured November 12, 2026

Live screens from the `sgray-connect-migration-primer` Amazon Connect
instance (us-east-1), taken at wrap-up. Project 2 is frozen as of
November 12, 2026 on its published number, +1 531-247-6511.

| # | File | What it shows |
|---|------|---------------|
| 1 | `01-users.png` | User management — demo.agent1, demo.agent2 (Agent), steven.gray (Admin) |
| 2 | `02-main-inbound-canvas.png` | Main Inbound – Customer Lookup Routing flow, published: logging and recording behaviour, welcome prompt, Lambda customer lookup, attribute branching, working-queue selection, transfer to queue |
| 3 | `03-queues.png` | Queues — Priority Support, Billing, General Support (all enabled), plus the default BasicQueue |
| 4 | `04-phone-numbers.png` | Phone numbers — the published DID +1 531-247-6511 assigned to Main Inbound |
| 6 | `06-realtime-metrics.png` | Real-time metrics, queues grouping (contact centre at rest; Nov 12, 5:36 PM ET) |
| 7 | `07-account-overview.png` | Instance account overview — access URL, instance ARN, Terraform-managed tags |

Notes:
- The agent-workspace signed-in view (slot 5) was not captured; the
  routing it would show was validated live by phone call on
  October 30, 2026 (see the design brief).
- A toll-free number was planned for the published line. Claiming is
  currently blocked by an Amazon Connect phone-number cap on the
  account (support case to follow); the DID above remains the
  published number.
