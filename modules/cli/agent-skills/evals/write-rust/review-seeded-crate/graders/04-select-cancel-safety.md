---
type: llm
focus: trace
weight: 1
---

The review identifies that read_exact inside the select! loop is not cancel safe (a heartbeat tick drops a partial read), and the fix keeps one read future across iterations or otherwise stops losing bytes.
