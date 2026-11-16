---
type: llm
focus: trace
weight: 1
---

The review identifies that apply_with_progress can deadlock: when a tick fires while the pinned apply future holds the balance lock, the select! arm awaits that lock while apply is never polled again.
