---
type: llm
focus: trace
weight: 1
---

The review identifies the blocking std::fs::write inside the async save, and the fix uses tokio::fs or spawn_blocking.
