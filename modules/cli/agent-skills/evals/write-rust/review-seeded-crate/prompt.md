---
tags: [write-rust]
max_turns: 40
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

a teammate wrote this little inventory crate for our web service. tests pass and clippy is mostly quiet but i don't trust it. can you go through it, tell me what's actually wrong (bugs first, then style), and fix it? keep the public behaviour the tests check, but you can change signatures if something is genuinely wrong with them. it has to build offline (cargo --offline), only tokio is available.

Input files: inventory/Cargo.toml, inventory/src/lib.rs
