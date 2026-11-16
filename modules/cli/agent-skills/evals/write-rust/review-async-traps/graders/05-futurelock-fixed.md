---
type: llm
focus: trace
weight: 1
---

The fix removes the deadlock (for example by spawning apply, not awaiting the lock inside the select! arm, using try_lock, or restructuring) and a test with a report interval shorter than the transfer shows it completes.
