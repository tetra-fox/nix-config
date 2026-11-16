---
type: llm
focus: trace
weight: 1
---

async-trait is removed; the trait uses native async fn or returns impl Future, and the future is declared Send (for example fn write(..) -> impl Future<Output = ..> + Send) so spawn_flusher still compiles and its test still passes.
