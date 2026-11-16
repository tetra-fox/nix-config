---
tags: [write-rust]
max_turns: 40
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

i need a small rust library crate called `jobs` for a tokio service. it runs async jobs in the background with at most N running at once (extra ones wait their turn). you submit a job (some async work that returns a String or fails with an error message) and get back an id. with the id you can check its status (queued, running, done with output, failed with the error, cancelled) and cancel it. there's also a shutdown that stops taking new jobs and waits for the running ones to finish. make it a proper library other people could use, with tests. put it in ./jobs. it has to build offline (cargo --offline); tokio, tokio-util and thiserror are in the local cargo cache, nothing else.
