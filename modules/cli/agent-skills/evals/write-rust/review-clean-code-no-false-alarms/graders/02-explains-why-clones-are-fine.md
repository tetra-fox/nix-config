---
type: llm
focus: trace
weight: 1
---

The review explains, for the clones and to_owned calls, why they are correct here (releasing a lock before awaiting, each queue owning its message, an Arc clone being a reference-count bump, building owned data), instead of treating the count of clones as a problem.
