---
name: docs-audit-loop
description: Audit every piece of text a person reads in a project (doc comments, code comments, README, manifest, CLI help and output, error and log messages) domain by domain with two models in a loop, under the write-docs rules. A reviewer model audits each domain, an implementer model fixes or disputes every finding in its own git worktree, and the reviewer rules until no violation remains. Nothing is handed back to the owner. Use when asked for a docs audit or docs pass in a loop, or a reviewer/implementer back and forth on docs, comments or copy.
argument-hint: "[reviewer model] [implementer model] [focus or paths]"
---

# Docs audit loop

This runs the same loop as `audit-loop`, through the same script at
`~/.claude/skills/audit-loop/workflow.js`. Read `~/.claude/skills/audit-loop/SKILL.md` first:
its defaults, the rule that the reviewer makes every call, the worktree setup (step 3), the run
(step 4) and bringing the work home (step 5) all apply unchanged. This file gives only what
differs for text: orienting, the domains, and the briefs and guides passed as `args`.

## 1. Orient

- Load the write-docs skill and read the project's CLAUDE.md and README.
- If the project's CLAUDE.md has no "Documentation voice" section, run write-docs' "Learn the
  voice from the field first" inline now, and write the measured targets into CLAUDE.md before
  the workflow starts. Every agent judges against the same targets, so none of them should
  survey the field on its own.
- Find the docs gate: the doc build with warnings denied, the doc tests, a README compiled as a
  doc test, and the tests that assert on printed lines or messages. Run it once on the base.
- Note anything the project keeps out of a docs change, such as wording that is behaviour only
  with a changelog entry, or text that follows a format another tool parses. That goes in
  `outOfScope`.

## 2. Split into domains

Group by the text a reader meets, so one reviewer holds one voice:

- the front door: README, the manifest's description and keywords, the crate or package root
  docs, and any README compiled into doc tests
- one domain per public module, or a group of small ones: the rendered docs on everything
  exported, with their examples
- one domain per subsystem for implementation comments: the private modules' module docs,
  `//` comments, and docs on items that aren't exported
- the program's text: `--help`, printed lines and JSON keys, exit-status docs, error and log
  messages, `expect`/`assert!`/`unreachable!` messages
- the tests' comments and messages, when the suite is large

Each file's rendered docs and its comments may fall in different domains. When that happens,
give `files` with what to read in each (for example "src/grid.rs: rendered docs only") so two
implementers never edit the same lines.

## 3 to 5. Worktrees, run, bring home

These are audit-loop's steps, with `prefix: "docs"` so the branches (`docs/<key>`) and
worktrees (`../<repo>-docs/<key>`) don't collide with a code audit. The `args` for text are:

- `guides`: `~/.claude/skills/write-docs/SKILL.md`,
  `~/.claude/skills/write-docs/references/docs-pass.md`,
  `~/.claude/skills/write-docs/references/comments.md`, and
  `~/.claude/skills/write-docs/references/readme.md` for the front-door domain
- `auditBrief`: "Audit every piece of text in the files in scope under write-docs and the
  project's Documentation voice: rendered docs, implementation comments, README and manifest
  text, help and printed output, and error, log, expect and assert messages. Measure doc-comment
  summaries against the project's targets. Check every claim (a default, a unit, an error or
  panic condition, what a result means) against the code, and treat the code as the truth. A
  finding quotes the text, names the rule it breaks or the code it contradicts, and gives the
  replacement text. A comment that only says what the code says is a finding, and its fix is
  deleting it."
- `fixBrief`: "Fix the text. When the text describes the intended behaviour and the code is the
  bug, fix the code instead, with a test that fails before and passes after. A rewrite keeps
  exactly the claims the old text made, except a claim the code shows to be false. Printed lines
  and JSON are behaviour: update the tests that assert on them in the same commit and name the
  change in the note. Run write-docs' 'Before handing back' checklist over every line changed."
- `closeBrief`: "the new text is true to the code, keeps every old claim that was true, follows
  write-docs and the project's Documentation voice, and passes the checklist; a code change has
  a test that fails without it"
- `outOfScope`: what step 1 found, plus "rewording text that already follows the rules"
- `gate`: the docs gate from step 1, plus the formatter and linter, since doc lints and
  formatting run on comments too

In the report, add the summary-length median and 90th percentile before and after for each
domain with rendered docs, and list every change to printed output or messages.
