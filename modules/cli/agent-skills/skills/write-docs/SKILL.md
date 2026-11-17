---
name: write-docs
description: How to write and audit every piece of text a person reads in a software project, in the owner's voice and in the voice of well-regarded projects in the same field. Covers code comments, doc comments (rustdoc and the like), READMEs, crate and package metadata, CLI help and output, error and log messages, and UI copy. Use it whenever writing or editing any of these, when asked for a "docs pass", a "comment audit", a README, or to "clean up the docs/comments/copy", and before handing back any change that adds or rewrites text, even when docs are not the main task.
---

# Write docs

Every piece of text a person reads, written so they get what they came for fast and nothing
they have to wade through. The owner's `~/.claude/CLAUDE.md` holds the comment voice and the
forbidden words; read it first. This skill adds everything else.

| Text | Reader wants | Shape |
|---|---|---|
| Code comment | why this line is the way it is | one lowercase line, or nothing |
| Doc comment | what an item is and how to use it | one-line summary, then detail paragraphs |
| README | what this is, can I use it, how | skimmable sections, tables, short bullets |
| CLI help | what a flag does | imperative phrase, then sentences in long help |
| Error / log message | what went wrong, where | lowercase clause, no period |
| UI copy | what this does | a few plain words |

Procedures live in `references/`:
- `references/comments.md`: auditing code comments (keep, rewrite, delete)
- `references/docs-pass.md`: a full documentation pass over a crate or package
- `references/readme.md`: README structure and how to model it on reference projects

## Learn the voice from the field first

Before writing docs or a README for a project, find out how the best projects shaped like it
write theirs. Memory of "how READMEs usually look" is a poor guide.

1. Pick 6 to 10 widely used projects in the same field and shape: a CLI tool next to CLI tools,
   an audio library next to audio libraries, an async client next to async clients. Check
   popularity (crates.io downloads, stars) and say which you chose and why.
2. Fetch their current text: READMEs from the repository's raw URL, crate sources from
   `https://static.crates.io/crates/NAME/NAME-VERSION.crate` into a scratch directory. Read
   them. Never build or run anything inside them.
3. Measure what numbers can show (summary length median and 90th percentile, share
   capitalized and ending in a period, which `#` sections appear, how often examples appear,
   first and second person per 1000 lines) and read for what they cannot (README section
   order, how a handle or option or error is worded, how examples are written).
4. Write the derived rules into the project's `CLAUDE.md` under "Documentation voice", naming
   the projects and the measured targets, so the next session follows them without measuring
   again. If the project already has that section, follow it.

The owner's rules win where the field disagrees with them (no "you", see below).

## Rules for all text

- **Say what a thing is, then stop.** No contrast framing: "x, not y", "it's not y, it's x",
  "evidence, not proof", "a dependency rather than a subproject", "the name is not proof".
  State the positive fact ("a peer names itself; `confirmed` says whether that is known").
- **No negative tail** that restates the sentence before it ("Policy belongs to the
  application ... and the client decides none of them itself"), and no twist ending ("the same
  types have the same names and do not match"; say "are different types").
- **Show a pattern with code** when describing it takes an abstract sentence ("an operation
  with settings of its own returns a value to set up and await" becomes one line of
  `client.download(user, file).size(n).to_file(path).await`).
- **The first sentence names concrete things** a reader recognizes ("Connects to the Soulseek
  network: searches, transfers, rooms"), never an abstraction ("offers actions and reports what
  happens as events").
- **No lead-in sentence** that announces or summarizes the list or section under it.
- **No three-item lists by reflex** and no parallel triplets ("fast, reliable, simple").
- **Headings and table headers are nouns**, the plain ones a reader expects: "Option" and
  "Description", "Exit code" and "Description", "Usage", "Limitations". Never verbs, verb
  phrases or questions ("Does", "When", "Means", "Adds", "Asked for", "What it reads", "How to
  use").
- **Present tense, current state.** No session narrative: what was tried, what changed, "now",
  "no longer", "new". Those belong in the commit message.
- **Claims come from the code.** A rewrite keeps exactly the claims the old text made. A claim
  that looks wrong is checked against the code and fixed if the code settles it, listed in the
  report if not. Never invent a rationale, a guarantee or a default.
- **No first or second person** in docs, READMEs, help or messages: no I, we, us, our, you,
  your. Name the role instead: the caller, the client, the server, the user, the file. Many
  reference projects say "you"; the owner wants none.
- **ASCII only**, no em-dashes, no arrows, no curly quotes.
- **No spec section numbers, ticket ids or finding ids** in code text. Papers and specs go in a
  README's References section, with full citations.
- **Units in words** next to the number ("in seconds", "in Hz", "in bytes"), and a fraction
  says what it is a fraction of.
- The forbidden words in `~/.claude/CLAUDE.md` apply everywhere.

## Code comments

The owner's comment voice in `~/.claude/CLAUDE.md` applies: lowercase, plain, one or two
lines, no trailing period on a single line, why over what, nothing the code already says.
A comment exists only to carry what the code cannot: a reason, a constraint, an invariant, an
external quirk, or a line that looks wrong on purpose. The default for anything else is
deletion. `references/comments.md` has the full decision procedure and the taxonomy of bad
comments for an audit.

## Doc comments

Rendered documentation: the crate or module docs and docs on public items.

- **Summary:** one line, never wrapped, ending in a period. A capitalized noun phrase for a
  type, field, variant or constant ("Thresholds the measures are read with."); a third-person
  verb for a function ("Returns the reading of a measured file."). Aim under 60 characters.
- **Detail** goes in later paragraphs after a blank doc line, as full sentences.
- **Fields, variants, options:** terse. A default is stated once, where the project keeps its
  defaults.
- **`# Errors`** on public fallible functions and **`# Panics`** where one can happen, one
  sentence per condition, stated from the code. Async behaviour (cancel safety, what dropping
  a future does) only where the code was read for it.
- **Intra-doc links** for every type named.
- **`# Examples`** at the density the reference projects use, usually the crate root and the
  main entry points. An example compiles as a doc test (`no_run` when it would touch the
  network or a placeholder path; never `ignore` or a `text` block standing in for code), keeps
  setup in hidden lines, handles errors with `?`, uses placeholder names and hosts, and shows
  only behaviour the code establishes. Its comments follow the comment voice.
- **Crate root:** one-line summary, a short introduction, a quick-start example, then sections
  by topic.
- Docs describe the item, never one application that uses it.

## READMEs

The first thing a stranger reads. It must be skimmable in under a minute.

- Plain section names a reader expects: Features, Installation, Usage (with `### CLI` and
  `### Library` when both exist), Methodology or How it works, Supported formats, Limitations,
  References, License. Never clever headings ("What it reads", "The program").
- Tables for anything with columns (formats, options, exit codes, verdicts, feature flags).
  One-line bullets for lists. A paragraph only when a list cannot carry it, and then short.
- A tagline under the title, then a one or two sentence summary of what it is.
- Code first in Usage: a real command with real output, then the options.
- The library example is compiled as a doc test from the crate (`#[cfg(doctest)]` including the
  README) so it cannot drift.
- `references/readme.md` has the section order and how to model it on reference projects.

## CLI help, output and messages

- A flag's short help is an imperative phrase without a period ("Print each file as one line
  of JSON"); long help adds sentences after a blank line.
- Exit codes are stated: what each code means.
- Errors go to stderr as `program: what: why`, lowercase, no trailing period.
- Error types' messages (`#[error]`, `Display`) and log messages: lowercase, no trailing period,
  one consistent form across the project.
- `expect`, `assert!` and `unreachable!` messages say what holds, lowercase.
- Printed lines and JSON output are behaviour: a wording change is listed in the report, and
  any test asserting on the string is updated in the same commit.

## UI copy

- Say what it does in a few plain words: "Deletes old data, as set in Retention".
- Labels drop articles: "Show job", "Copy path". Sentences keep proper grammar.
- A hint stays only if it tells the user something they could not guess. No "click X" or "press
  Enter" instructions, no internal mechanics, no enumeration where a category name works.
- Single-sentence captions and notices drop the trailing period. Tool names spelled properly
  ("Nix", "FLAC").

## Before handing back

Run this over every line of text you added or changed:

- [ ] no "x, not y" or "not y, x" framing; no lead-in sentence summarizing what follows
- [ ] headings and table headers are plain nouns ("Option", "Exit code", "Description")
- [ ] no negative tail or twist ending; patterns shown as code; the first sentence concrete
- [ ] no forbidden words from `~/.claude/CLAUDE.md`; ASCII only
- [ ] no first or second person in docs, READMEs, help or messages
- [ ] every claim traced to the code; no invented rationale, guarantee or default
- [ ] no session narrative ("now", "no longer", "we tried", "verified on")
- [ ] summaries one line, period, under about 60 characters
- [ ] README skimmable: plain headings, tables, short bullets, compiled examples
- [ ] doc tests and the project's docs build pass (`cargo test --doc`,
      `RUSTDOCFLAGS="-D warnings" cargo doc --no-deps` or the project's equivalent)
