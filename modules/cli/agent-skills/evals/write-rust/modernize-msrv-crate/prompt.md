---
tags: [write-rust]
max_turns: 40
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

this metrics crate is a couple of years old. can you bring it up to current idiomatic rust and drop any dependencies we don't actually need anymore? our CI builds it on the MSRV in Cargo.toml (rust-version = 1.85) as well as on latest stable, so it has to keep building on 1.85. keep the public behaviour the same. it has to build offline (cargo --offline).

Input files: metrics/Cargo.toml, metrics/src/lib.rs
