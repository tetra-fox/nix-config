---
type: llm
focus: trace
weight: 1
---

The run explicitly considers the 1.85 MSRV when choosing what to modernise (for example noting that let chains or assert_matches! would need a newer Rust), rather than ignoring it.
