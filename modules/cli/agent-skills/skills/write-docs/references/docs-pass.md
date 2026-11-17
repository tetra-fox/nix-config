# Documentation pass

A full pass over a crate or package's text: comments, rendered docs, README, metadata, examples
and the strings people read. Part of the `write-docs` skill; its rules apply throughout.

## Ground rules

- The pass covers every piece of text a person reads. List the tracked files (`git ls-files`)
  at the start and account for each in the report.
- No logic, identifiers or test names change. String literals change only in step 5.
- Rephrase, never add claims. A rewrite keeps exactly the claims the old text made. Doc
  examples are the one addition, and show only behaviour the code and existing docs establish.
  Where a rewrite would force a choice between two meanings, keep the old meaning and list it.
- Nothing leaves the machine: no push, tag, publish or remote change unless asked. Small signed
  commits per the owner's commit rules, the project's check command green before each.
- The owner's working files (`CLAUDE.md`, `.claude/`, prompts, reports) are ignored through
  `.git/info/exclude`, never staged, never named in `.gitignore`.
- When fanning out to subagents, give each a disjoint file list, tell it to touch nothing else
  and not to stage or commit, and review every diff.

## Step 1: comment audit

Run `references/comments.md` over the code and tooling files (sources, build files, workflows,
manifests). Implementation comments only; rendered docs are step 4's. Commit on its own.

## Step 2: learn the field's voice

As `SKILL.md` describes: pick 6 to 10 widely used projects shaped like this one, download
current releases, read without building. Measure with a small script over rendered docs only
(crate and module docs, docs directly above public items, fields and variants):

- summary length (first sentence of the first paragraph): median and 90th percentile
- share of summaries capitalized, and ending in a period
- share of first paragraphs longer than one line
- which `#` sections appear and how often (Examples, Errors, Panics, Cancel safety, ...)
- first and second person per 1000 doc lines, and the role nouns used instead
- how the crate root is laid out

Run the same script on this project before changing anything. Then read for what numbers miss:
how the main types and their methods are documented, how options and errors are worded, how
examples are written, how the README is organized.

## Step 3: rules, then one exemplar

Write the derived conventions into the project's `CLAUDE.md` under "Documentation voice",
naming the reference projects and the measured targets. Rewrite one representative module to
them, measure it, and name it in `CLAUDE.md` as the exemplar for the rest of the pass.

## Step 4: apply

Rewrite the rendered docs of the whole project to the rules: the crate root, every public
module, type, method, field, variant and constant, the README (per `references/readme.md`), the
manifest description, and comments in examples. Write the doc examples as `SKILL.md` says.
Commit the examples separately from the prose.

## Step 5: strings people read

`#[error]` and other error text, `panic!`/`expect`/`assert!`/`unreachable!` messages, log
messages, CLI help and printed output. Same rules; one form across the project. Wording only,
never fields, levels or which message fires. Update tests that assert on a changed string in
the same commit, keep this in its own commit, and list every changed string, old and new.

## Step 6: verify

- With every comment line stripped, each source file's diff shows only step 5's strings and
  their tests.
- The project's checks green, the docs build clean with warnings as errors, doc tests pass.
- `SKILL.md`'s "Before handing back" list holds for every changed line.
- Rerun the measuring script and compare with the references.

## Report

The reference projects and versions and why; measured before and after next to the reference
ranges; the rules added to `CLAUDE.md`; the exemplar; counts of comments removed or changed and
docs rewritten; every example added; every wrong claim fixed (file:line); every claim kept but
unverified; every ambiguous spot; what was not done. Note that published docs keep the old text
until the next release, and propose the repository description and topics for the owner.
