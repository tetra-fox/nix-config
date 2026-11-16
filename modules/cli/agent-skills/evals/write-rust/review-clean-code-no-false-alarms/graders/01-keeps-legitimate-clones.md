---
type: llm
focus: trace
weight: 1
---

The run removes no clone on reflex: the self.clone() moved into the spawned task and the per-member message.clone() are kept, and any clone it does remove (such as the sender snapshot, which can go because try_send never waits) comes with a concrete reason and leaves behaviour unchanged.
