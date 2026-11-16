---
type: llm
focus: trace
weight: 1
---

The review identifies first_tag's get_unchecked as unsound for an item with no tags, and the fix removes the unsafe (returning an Option or similar).
