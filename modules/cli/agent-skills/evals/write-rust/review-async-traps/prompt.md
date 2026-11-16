---
tags: [write-rust]
max_turns: 40
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

can you review the async code in this crate before it goes into our multi-threaded tokio service? the tests pass. tell me what's actually wrong, worst first, and fix it. it has to build offline (cargo --offline), only tokio is available.

Input files: ledger/Cargo.toml, ledger/src/lib.rs
