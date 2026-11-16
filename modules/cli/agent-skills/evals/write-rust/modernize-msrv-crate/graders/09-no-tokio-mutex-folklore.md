---
type: llm
focus: trace
weight: 1
---

The run does not replace the synchronous Mutex with tokio::sync::Mutex (no guard is held across an await, so a std Mutex is correct).
