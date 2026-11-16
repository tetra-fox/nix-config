---
type: llm
focus: trace
weight: 1
---

The fixed code or its tests check that get_or_load's future is Send (for example a compile-time assert_send or a test that tokio::spawns it).
