---
name: "comment-audit"
description: "Audit a codebase's comments: fix or delete inaccurate ones, cut noise and big blocks, rewrite unclear code instead of explaining it, keep only terse why-comments, and cut session narrative (what was tried, what broke, which hosts it was verified on) down to the present-tense constraint."
---

# Comment audit

Goal: after this pass, every surviving comment is **true, short, and necessary**. The code is the source of truth; comments exist only to carry information the code cannot.

The default for any implementation **commentary** is deletion. Commentary must earn its place.

Not every comment is commentary. **If removing or changing a comment could alter how the code builds, runs, formats, type-checks, lints, is covered by tests, or is processed by any tool, it is not commentary** and is out of scope (see Never touch). When in doubt about whether a comment is read by some tool, treat it as a directive.

## Scope: comments are not documentation

This skill audits **implementation comments**: the notes inside and around code that explain it to maintainers.

Documentation is a different obligation. Public API docs, user-facing docs, protocol/spec docs, and doc comments consumed by tooling (doc generators, linters, IDE hovers for library users) may intentionally carry information the implementation doesn't express, such as contracts, guarantees, and usage guidance. Preserve them according to the project's documentation conventions. You may fix falsehoods in them (when the correction can be established) and trim lines that only restate the signature, but never delete them wholesale.

The protection covers docs that people *outside the code* rely on. An internal/private docstring that only restates the function signature is an implementation comment and is fair game.

## The decision procedure (apply to every comment)

Ask in order, stop at the first yes:

1. **Is it a directive, legal header, generated code, or documentation per the Scope section?** (see Never touch) -> leave it (for docs you may still fix established falsehoods and trim pure restatement).
2. **Is it false or stale?**
   - If the correct information **can be established** (from code, tests, issues, docs, or history): fix it if it's still needed; otherwise delete it.
   - If you **cannot establish** the correction: do not guess. Preserve the original meaning and flag it as unverified.
   - If the comment describes *intended* behavior and the code disagrees, the code may be the bug: **flag it under Suspected bugs, do not silently change behavior**.
3. **Does the code already say it?** -> delete.
4. **Could the code be rewritten *locally and behavior-preservingly* so it says it?** (a rename, explaining variable, named constant, or small extraction within the same function or file, following the rewrite rules below) -> prefer the rewrite, then delete the comment. If making it self-explanatory would need a larger refactor, the answer is no: keep a terse comment and suggest the refactor in the report.
5. **Does it explain something the code cannot?** Keep it, compressed to the fewest words that preserve the meaning (one line preferred), if it covers any of:
   - *why* something non-obvious is done (perf, security, ordering, invariants)
   - externally imposed behavior: third-party API quirks, protocol violations by a peer, OS/browser/hardware bugs, compatibility with old clients or data
   - code that **looks wrong but is intentional**, where a reasonable engineer would be tempted to "fix" it

   If the why is wrapped in a story of how it was found, keep only the present-tense fact (see 19).
6. Otherwise -> delete.

## Do not invent rationale

Never write or reword an explanation you can't back up. A rationale or correction may only be added, replaced, or rephrased when you can establish it from the code, tests, linked issues, docs, or repository history (`git log -S`, `git blame`, commit messages).

- If you can establish it: write it concretely and cite the source if helpful (issue link, commit).
- If you cannot: keep the original claim with its meaning intact, even if clumsy. You may trim filler words but must not sharpen, generalize, or specify it. Flag it in the report as unverified.
- Delete a rationale comment only when it's demonstrably unnecessary (the workaround it describes is gone, the constraint no longer applies and you can show that), not because you couldn't verify it.

Bad (plausible, invented): `// Needed because the payment API rejects this format.` -> `// Payment API requires normalized currency codes.`
Good: leave it as is, or trim to `// payment API rejects this format`, and flag it if the format in question isn't identifiable.

This rule takes precedence over every remedy below that involves rewriting a comment, especially 1 (inaccurate), 12 (hedging), 17 (shouting), 18 (compression) and 19 (session narrative).

The principle: when uncertain about the code, don't become more confident in the comment. Become more explicit about the uncertainty.

## Verifying accuracy beyond the file

Many comments make claims about code elsewhere: "callers always pass a sorted list", "only used by the billing job", "set by the auth middleware". Reading the current file can't confirm these.

- Check such claims with a quick search (find references, grep call sites, check where the value is set).
- If confirmed: the comment may stay (as a terse invariant) or become unnecessary if the code can enforce it (an assertion, a type).
- If contradicted: treat as inaccurate (category 1), and if callers depend on the broken assumption, list it under Suspected bugs.
- If it can't be settled (dynamic dispatch, external consumers, reflection): treat as unverified. Keep it, and flag it. Don't assume it's true or false.

## Taxonomy of bad comments and the remedy

### 1. Inaccurate / stale
Comment contradicts the code: wrong param names, old return type, describes removed behavior, wrong units, wrong complexity.
```python
# returns None if user not found
def get_user(id): ... raise UserNotFound(id)
```
**Remedy:** Read the code, determine actual behavior. If the correct behavior is established, correct the comment only if it still adds value; usually delete. If the comment reflects clearly intended behavior (e.g. a documented contract callers rely on) and the code diverges, leave the code alone and list it under "Suspected bugs". If you can't tell which is right, preserve and flag.

### 2. Restating the code ("what" comments)
```js
// increment i
i++;
// loop over users
for (const user of users) {
```
**Remedy:** Delete.

### 3. Explaining unclear code that could be clearer
```ts
// check if user is eligible for discount
if (u.a > 65 || (u.s && u.y < 2)) {
```
**Remedy:** Make the code say it (locally), then delete the comment:
```ts
const isSenior = user.age > 65;
const isNewStudent = user.isStudent && user.yearsEnrolled < 2;
if (isSenior || isNewStudent) {
```
Tools, cheapest first: rename a local/private identifier; introduce an explaining variable; extract a well-named function in the same file; replace a boolean arg with a named option/enum (private call sites only); replace an index with destructuring.

### 4. Magic values explained by a comment
```go
time.Sleep(86400 * time.Second) // one day
```
**Remedy:** Named constant or expressive expression: `time.Sleep(24 * time.Hour)` / `const retryWindow = 24 * time.Hour`. Keep a comment only if the *choice* of value needs justifying and that justification can be established (`// upstream rate limit resets daily`).

### 5. Big essay blocks
Multi-paragraph comments narrating design history, alternatives considered, or how the whole module works.
**Remedy:** Extract the one or two load-bearing facts (the why, the invariant, the external constraint, the gotcha) into a terse line at the exact place it matters, keeping their meaning intact. Drop the rest. If the rationale is genuinely valuable architecture knowledge, mention in the report that it belongs in a design doc/ADR/commit message; don't create docs unasked. If the block is actually module-level documentation for users (see Scope), treat it as docs, not an essay.

### 6. Commented-out code
**Remedy:** Delete. Version control has it. Exception: none, unless the user says otherwise. (Make sure it's really dead code and not a directive or template that a tool reads.)

### 7. Banners and section dividers
```java
//////////////////// HELPERS ////////////////////
// ===== Getters =====
```
**Remedy:** Delete. If a file genuinely needs sections to be navigable, note in the report that it may want splitting; don't split unasked. Exception: editor/IDE region markers (`#region`, `// region`, `// MARK:`) that the team uses for folding or navigation are directives; leave them.

### 8. Journal / attribution / changelog comments
`// Added by Bob 2019-03-02`, `// v2: fixed null bug`, `// modified for JIRA-123`.
**Remedy:** Delete. Git blame and history cover this. If a ticket reference is the only pointer to *why* odd code exists, keep it as a terse why with the ticket link instead.

### 9. Redundant doc comments
```python
def _set_name(self, name: str) -> None:
    """Sets the name.

    Args:
        name: The name.
    """
```
**Remedy:** Private/internal: delete entirely. Public API (see Scope): keep, but trim lines that only restate the signature; keep everything carrying real information (units, ranges, side effects, errors raised, thread-safety, ownership, usage guidance). If the language/linter requires a doc comment (e.g. Go exported identifiers), never go below one terse sentence.

### 10. Types in comments when the language has types
`// @param {string} name` in TypeScript, `# name: str` beside an untyped Python param.
**Remedy:** Move the info into real annotations where it's safe (local/private code, or the project already uses annotations), then delete. Do **not** strip JSDoc types in plain JS projects that rely on them for type checking, or Python `# type:` comments a type checker reads.

### 11. Closing-brace / end markers
`} // end if`, `} // end for users`, `end # class Foo`.
**Remedy:** Delete. If the block is so long the marker felt necessary, mention it in the report as a function worth splitting.

### 12. Hedging, confusion, and apology
`// not sure why this works`, `// might be needed?`, `// hack, sorry`, `// DO NOT TOUCH`.
**Remedy:** Investigate (code, tests, git history, linked issues). Then:
- (a) If you *establish* why, replace with a concrete one-line reason.
- (b) If you can *prove* the code is dead (no references, tests pass, no dynamic access), remove it; otherwise flag it.
- (c) If still unknown, keep a factual note of what is known, without inventing a cause (`// removing this breaks X; cause unknown`, or keep the original wording minus the apology), and flag it under Unresolved mysteries.

### 13. Stale or unowned TODO / FIXME / XXX
**Remedy:** If already done -> delete. If obviously trivial and in scope -> just do it only when behavior-preserving; otherwise leave. If vague with no actionable content (`// TODO: clean up`) -> delete. Keep actionable TODOs, trimmed to one line (keep ticket refs).

### 14. Misplaced comments
Comment sits far from the code it describes, or above the wrong line after edits drifted.
**Remedy:** Move it to the exact line it explains, or delete if steps 3-4 apply.

### 15. Duplicated comments
Same explanation copy-pasted at every call site.
**Remedy:** Keep one at the definition (or better: encode it in the function's name, if private); delete the copies.

### 16. Boilerplate / generated noise
`// Auto-generated method stub`, `// Constructor`, `/* Default constructor */`, template file headers with empty fields.
**Remedy:** Delete, unless it sits inside a generated region (see Never touch).

### 17. Noise, jokes, emotion, shouting
`// here be dragons`, `// lol`, `// IMPORTANT!!!`.
**Remedy:** Delete, preserving any real content as a plain terse fact. `// IMPORTANT: don't reorder!!!` becomes `// order matters: X must run before Y` only if you can establish X and Y; otherwise `// order matters` and flag.

### 18. Over-long versions of good comments
The comment is a legitimate why but wordy.
**Remedy:** Compress without changing the claim. Cut filler; don't add specifics that weren't there or generalize ones that were.
`// We need to do this because the API sometimes returns duplicates when paginating, so we dedupe here` -> `// API can repeat items across pages`.

### 19. Session narrative
The comment retells the work that produced the code: what was tried, what broke, which machines or environments it was checked on, the order things were discovered. Usually written mid-task as a status report to whoever asked for the change, so it only makes sense to someone who was there.
```sh
# tried putting this in the service config first but host-b failed to start,
# verified the fix on host-a and host-c, then found the daemon reads it
# before the config is loaded so it has to go here
export DAEMON_OPTS=...
```
Tells: past tense about the work, "we"/"I", "tried", "first", "then", "turned out", "verified/tested/confirmed on <host>", and before/after framing ("now uses", "no longer", "moved from", "the new approach") that only reads correctly next to the diff.
**Remedy:** Test: would this make sense to someone who never saw the task, the PR, or the conversation? Keep only the fact that still constrains the code, in present tense: `# the daemon reads this before its config loads`. Drop the attempts, the discovery order, and the verification record; that history belongs in the commit message or issue, not the file. If the story never states a present-tense constraint, delete it. A contrast that describes current behavior (`# fails the unit instead of hanging`) is not narrative and stays. The surviving line must be a fact the story actually states; don't distill a cleaner cause than it gives.

## What a good surviving comment looks like

- Explains **why**, a **constraint**, an **invariant**, an **external quirk**, or a **surprise**, never what.
- One line when possible; wrap to a second only if truly needed.
- Concrete: `// Safari <17 fires resize twice` beats `// browser quirk` (but only if you know it's Safari <17).
- Links a bug/issue/spec when that's the real explanation.
- Matches the repo's existing comment style (case, punctuation, `//` vs `/* */`).

Legit keepers, examples:
- `// workaround for libfoo#1234; remove after 3.2`
- `// must run before auth middleware: sets request id`
- `// O(n^2) is fine here, n <= 8`
- `// constant-time compare to avoid timing leaks`
- `// server sometimes returns 200 with an error body`
- `// monotonic clock: wall-clock jumps would expire leases early`
- `// intentionally not awaited: fire-and-forget metrics`
- Short explanation of a non-trivial regex or bit trick.
- Units when the type can't carry them.

## Never touch (except to fix established falsehoods in docs)

- License / copyright headers.
- **Directives and semantic comments**, anything a tool or runtime reads. Apply the test from the top: if changing it could change behavior of the build, runtime, formatter, type checker, linter, coverage, bundler, or editor, it's a directive. Examples (not exhaustive):
  - Linters/type checkers: `eslint-disable`, `@ts-expect-error`, `@ts-ignore`, `@ts-nocheck`, `# noqa`, `# type: ignore`, `# type:` annotations, `# pyright:`, `# mypy:`, `// nolint`, `rubocop:disable`, `// NOSONAR`, `// @flow`
  - Formatters: `// prettier-ignore`, `# fmt: off` / `# fmt: on`, `# isort: skip`, `// clang-format off`
  - Coverage: `istanbul ignore`, `c8 ignore`, `# pragma: no cover`, `// LCOV_EXCL_LINE`
  - Build/compiler/runtime: `//go:build`, `// +build`, `//go:generate`, `//go:embed`, `//go:linkname`, cgo `//export` and preambles, `# frozen_string_literal: true`, `# -*- coding: ... -*-`, shebangs, `/** @jsx */`, `/** @jsxImportSource */`, `/* webpackChunkName: */` and other bundler magic comments, `/*#__PURE__*/`, `/* @vite-ignore */`
  - Editor/IDE: `// language=SQL`, `// region` / `#region`, `// MARK:`, `// swiftlint:`, `vim:` / `-*- mode:` modelines, `// @formatter:off`
  - Other: doctest blocks, SQL optimizer hints (`/*+ INDEX(...) */`), HTML conditional comments, Rust `#[doc]` attrs, template-engine comments that affect output
  - You may trim a trailing human explanation on a directive, but keep the directive itself intact.
- Documentation per the Scope section: public API docs, doc comments required by the build/linter/doc generator, user-facing and protocol/spec docs (fix established falsehoods and trim pure restatement only).
- **Generated files**: generated, vendored, and third-party code (`vendor/`, `node_modules/`, `third_party/`, `*.pb.go`, `*_generated.*`, `*.g.dart`, minified files, lockfiles, migrations the framework regenerates), and any file whose header marks it generated (`Code generated ... DO NOT EDIT.`, `@generated`, `<auto-generated>`).
- **Generated regions inside otherwise editable files**: anything between markers such as `// GENERATED CODE START` / `END`, `<auto-generated>` ... `</auto-generated>`, `#region Windows Form Designer generated code`, `// <editor-fold desc="Generated Code">`, or other codegen/snippet sentinels (`BEGIN`/`END` blocks that tools rewrite). Leave the markers and everything between them untouched, unless the repository's generation workflow explicitly says hand edits there are allowed.
- Test fixtures and snapshot files where comments may be data.

## Rules for rewriting code instead of commenting

- **Behavior must not change.** Pure refactors only: renames, explaining variables, extracting functions, named constants.
- **Local only.** The rewrite stays within the function or file the comment lives in. If clarity would require touching other modules, changing signatures used elsewhere, or restructuring, don't: keep a terse comment and suggest the refactor in the report.
- Never rewrite code inside a generated region.
- Rename freely: locals, private members, unexported functions.
- Do **not** rename without asking: exported/public symbols, anything serialized (JSON keys, DB columns, config keys), anything accessed by string/reflection, CLI flags, env vars, API routes.
- If a rewrite is desirable but risky, keep a terse comment and list the refactor as a suggestion in the report.

## Workflow

1. **Scope.** List tracked source files (`git ls-files`), exclude the never-touch paths and generated files above. Work on a branch if in a git repo.
   - **Pre-existing changes:** check `git status`. Never modify, revert, stage, or commit the user's existing uncommitted changes. If they're in files outside the audit scope, proceed and leave them alone. If they overlap files you'd audit, either skip those files (and list them in the report) or ask before proceeding when you can't cleanly separate your edits from theirs.
2. **Baseline.** Find and run the project's test, typecheck, and lint commands (package.json scripts, Makefile, CI config, etc.). Record results so later failures can be attributed.
3. **Plan the pass.** For large repos, split by directory/package. Fan out to subagents per chunk if available, giving each this entire rubric verbatim (including the commentary test, Scope, Do not invent rationale, Never touch, and the rewrite rules); instruct them to return a list of flagged items alongside their edits.
4. **Per file:** read the whole file first, noting any generated regions. Walk every comment through the decision procedure. For comments that make claims about other code, search to verify (see Verifying accuracy beyond the file). Apply edits.
5. **Verify after each chunk:** run typecheck/lint/tests. Any new failure caused by the audit is reverted or fixed before moving on. Review removed lines in *your* diff for directive patterns and generated-region markers; restore any that were lost.
6. **Self-review the diff.** Every removed comment: was it really redundant, false, or demonstrably unnecessary? Every rewritten comment: is the claim identical or established from a source, never guessed? Every code rewrite: local and behavior-identical? Every kept comment you edited: as short as it can be?
7. **Final inventory.** The diff only shows what changed, so comments you left untouched haven't been checked twice. Re-scan every audited file and classify **every** surviving comment as one of:
   - directive / legal / generated
   - documentation (per Scope)
   - why / constraint / external quirk / intentional oddity
   - actionable TODO
   - unverified (kept and flagged)
   - other
   Anything in **other** must be removed, or reclassified with an explicit justification. The invariant when you finish: every surviving implementation comment has a stated reason to exist.
8. **Commit** in logical chunks (per package/directory) with clear messages, if the user wants commits. Stage only your own hunks.
9. **Report** (keep it short):
   - Counts: comments removed / shortened / corrected / replaced by code rewrites, and the final inventory breakdown by class.
   - **Suspected bugs**: comments whose described behavior disagrees with the code, with file:line and both versions. This is the most valuable part of the report.
   - Unverified claims kept as-is (rationales or corrections you couldn't establish, cross-file claims you couldn't settle).
   - Unresolved mysteries (hedging comments you couldn't explain).
   - Suggested refactors you didn't do (non-local rewrites, public renames, long functions, files needing splits).
   - Files or regions skipped (pre-existing uncommitted changes, generated regions found inside source files).
   - Test/lint status vs baseline.

## Calibration

- When unsure whether a why-comment is needed, imagine a competent engineer new to the file: would they be surprised, or tempted to "fix" this line wrongly? If yes, keep a one-liner. If no, delete.
- When unsure whether a rationale or correction is true, it stays in its original meaning and gets flagged. Uncertainty is never a license to rewrite.
- When unsure whether a comment is read by a tool, treat it as a directive and leave it.
- A file with zero comments is a fine outcome.
- Don't add new comments except to replace a worse one or to document a surprise you uncovered and verified while auditing.