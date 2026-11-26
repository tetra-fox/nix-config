---
name: audit-loop
description: Audit a codebase domain by domain with two models in a loop. A reviewer model audits each domain, an implementer model fixes or disputes every finding in its own git worktree, and the reviewer rules on each answer until no violation remains. Nothing is handed back to the owner. Use when asked to "audit in a loop", run a reviewer/implementer back and forth, or repeat this audit on a repo.
argument-hint: "[reviewer model] [implementer model] [focus or paths]"
---

# Audit loop

Runs `workflow.js` (next to this file) through the Workflow tool. Invoking this skill is the
opt-in to multi-agent orchestration. The defaults are reviewer `claude-mythos-5-2[1m]` and
implementer `claude-opus-5-5[1m]`. Models, a focus or paths given in the arguments override them.

The rule that shapes everything: **the reviewer makes every call.** Findings end fixed or
disputed, the reviewer closes or reopens each one, and a domain is done when the reviewer finds
no violation left. There is no "owner" or "defer" outcome. The round cap is only a backstop
against a loop that never converges.

## 1. Orient (inline, before the workflow)

- Read the repo's CLAUDE.md and README, its toolchain and its gate (justfile, Makefile, CI).
  Note what the repo says is out of scope for a change: for example, a threshold retune that
  needs corpus scores. That becomes `outOfScope`, so the reviewer leaves it out instead of
  raising something the implementer cannot settle.
- Check that both models resolve with a two-agent probe workflow (`Reply with ok.`, effort low).
- Run the gate once on the base branch so a red start isn't blamed on the loop.
- Pick the language guides the agents read: `~/.claude/skills/write-rust/SKILL.md` and its
  `references/audit.md` for Rust, the matching skill for another language, and the docs skill
  when docs are in scope.

## 2. Split into domains

List every source file with its line count, then group the files into domains of a few thousand
lines, one subsystem each. Keep tests with what they test unless the test suite is big enough to
be a domain of its own. Every file belongs to exactly one domain, so nothing goes unread. Give
each domain:

- `key`: short kebab-case, also used for the worktree and branch name
- `files`: the paths in scope
- `focus`: one sentence on what is most likely to be wrong there (hostile input in parsers,
  cancel and deadline paths in an engine, exit status and output in a program, tests that would
  pass on broken code)

## 3. One worktree per domain

Implementers edit in parallel, so each domain gets its own worktree and branch, outside the repo
on a disk with room for a build per worktree (not a tmpfs):

```sh
mkdir -p ../<repo>-audit
for d in <keys>; do git worktree add -q ../<repo>-audit/$d -b audit/$d <base>; done
```

Copy any locally excluded instruction files the agents need (CLAUDE.md under
`.git/info/exclude`) into each worktree. The exclude file is shared, so the copies stay out of
commits.

## 4. Run the workflow

```
Workflow({ scriptPath: "~/.claude/skills/audit-loop/workflow.js" (absolute), args: {
  project, root, base, prefix: "audit", reviewer, implementer, maxRounds: 20,
  auditBrief, fixBrief, closeBrief, guides: [...], gate: [...], outOfScope, domains: [...]
}})
```

The three briefs for a code audit:

- `auditBrief`: "Audit the files in scope systematically: orient, run the mechanical sweep the
  guides describe (extra lints, greps), then read every candidate in context and read each file
  for what a sweep misses. A pattern match is a candidate, not a finding. Each finding says
  concretely what goes wrong and how to trigger it; reproduce it (a failing test or a small
  program, then discard it) when that is cheap. Doc and comment findings count when a doc claims
  more than the code does or breaks the project's documentation rules."
- `fixBrief`: "Fix root causes. A behaviour-changing fix comes with a test that fails before it
  and passes after."
- `closeBrief`: "root cause, a test that fails without it, docs and comments in the project's
  voice"

`docs-audit-loop` runs the same script with briefs for text. A change to the loop itself goes in
`workflow.js`, and the briefs stay in the skill that passes them.

`gate` is the list of commands the implementer runs green before it answers. Use the repo's
own targets (`just lint`, `just test`) when they exist, so that the gate is defined in one
place. Split them only to drop a step a worktree can't run, such as one that needs a toolchain
the worktree lacks. Pass `args` as a JSON object, never as a string.

Implementers commit unsigned (`git -c commit.gpgsign=false`) because parallel signing would
raise a 1Password prompt per commit. Tell the owner this when the run starts.

While it runs, report what is happening when asked. Never predict the results.

## 5. Bring it home

- Read the result. A domain with `satisfied: false` hit the backstop or had an agent fail. Read
  its journal, then resume the workflow (`resumeFromRunId`) or run that domain again. Don't hand
  its open findings to the owner.
- Cherry-pick each branch onto the base in domain order (`git cherry-pick <base>..audit/<key>`).
  With `commit.gpgsign` on, this signs every commit. Resolve conflicts where two domains touched
  the same file: keep both intents, and if one fix makes the other wrong, fix that too.
- Run the repo's full gate on the result. A failure is a bug in the merge or in a fix, so fix
  the cause.
- Remove the worktrees and branches (`git worktree remove`, `git branch -D audit/<key>`).
- Report per domain: findings by severity, how many were fixed and how many disputed and
  upheld, the rounds it took, what the reviewer judged fine, what wasn't covered, and the
  commits now on the base. Don't push.
