---
type: llm
focus: trace
weight: 1
---

No std::sync::Mutex or RwLock guard is held across an .await (tokio's Mutex across .await, or no lock across .await, is fine).
