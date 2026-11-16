---
type: llm
focus: trace
weight: 1
---

lazy_static and once_cell are replaced by std::sync::LazyLock and OnceLock (or equivalent std code) and both are removed from Cargo.toml.
