---
type: llm
focus: trace
weight: 1
---

There is no unsafe code and no blocking call (std::thread::sleep, std::fs, blocking recv) inside async code.
