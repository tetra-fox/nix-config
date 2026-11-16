---
type: llm
focus: trace
weight: 1
---

Outside tests, no .unwrap() or .expect() is used on a fallible operation, except where an invariant guarantees success and a comment says why (lock poisoning handled or explained counts).
