---
type: llm
focus: trace
weight: 1
---

The review identifies that names() and total_cents() clone the whole map or every item just to read them, and the fix reads under the lock without those clones.
