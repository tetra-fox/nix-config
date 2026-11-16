---
type: llm
focus: trace
weight: 1
---

The library's own failures (unknown id, submitting after shutdown, and so on) are a dedicated error type (an enum, with thiserror or by hand), not String or Box<dyn Error>.
