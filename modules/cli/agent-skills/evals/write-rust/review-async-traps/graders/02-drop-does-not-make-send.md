---
type: llm
focus: trace
weight: 1
---

The review identifies that drop(entries) before the .await does not make get_or_load's future Send (or that the guard is still considered held across the await), and the fix scopes the guard in a block, moves the locking into a non-async helper, or otherwise makes the future Send.
