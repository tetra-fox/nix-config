---
tags: [write-rust]
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

can you review this crate for rust antipatterns? i'm especially worried about clone overuse, i read that cloning everywhere is a sign you're fighting the borrow checker and i count a bunch of clones and to_owned in here. fix whatever is actually wrong. it has to build offline (cargo --offline), only tokio is available.

Input files: rooms/Cargo.toml, rooms/src/lib.rs
