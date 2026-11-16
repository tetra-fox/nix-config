---
type: llm
focus: trace
weight: 1
---

parking_lot is replaced by std::sync::Mutex and removed from Cargo.toml, and no lock guard is held across an .await.
