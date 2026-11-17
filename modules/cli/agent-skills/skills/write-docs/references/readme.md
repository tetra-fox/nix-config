# READMEs

Part of the `write-docs` skill. A README is a project's first impression: a stranger should
know what it is, whether it fits, and how to start within a minute of skimming.

## What popular crates do

Measured 2026-11-17 over 291 READMEs: the 300 most-downloaded crates (one per repository) plus
the top crates in command-line-utilities, audio, network-programming, encoding and
parser-implementations.

| Measure | Libraries (n=253) | CLI tools (n=38) |
|---|---|---|
| Words, median (p25 to p75) | 310 (165 to 515) | 810 (500 to 1950) |
| Headings, median | 4 | 10 |
| Code blocks, median | 1 to 2 | 8 to 9 |
| Has any table | 11 to 14% | 34% |
| Paragraph length, median | 15 words | 16 words |
| Longest paragraph, median | about 48 words | 68 words |

Share of READMEs with a section:

| Section | Libraries | CLI tools |
|---|---|---|
| License | 44 to 57% | 58% |
| Contributing / Contribution | 35 to 38% | 45% |
| Usage | 29 to 30% | 74% |
| Example(s) | 29 to 43% | 42% |
| Minimum Rust version | 20 to 23% | 11% |
| Features / crate features | 13 to 21% | 18% |
| Performance / benchmarks | 8 to 9% | 18% |
| Installation | 5 to 7% | 42% |
| Quick start / getting started | 2 to 4% | 21% |
| Limitations / caveats | 2% | 8% |

What that means:

- A library README is short: a few hundred words, about four headings, one or two code blocks.
- A CLI README is longer and is the place for Installation, usage walkthroughs and tables.
- Installation and Limitations are rare for libraries. The typical library puts its dependency
  line at the top of Usage or Example.
- An italic tagline is rare (2%). The common opening is the title, badges, then one plain
  sentence naming what it is: "A utility library for working with bytes.", "A push parser for
  the HTTP 1.x protocol.", "A wav encoding and decoding library in Rust."
- Short paragraphs are normal; bullets are a tool, not a rule. Use them for lists, keep
  paragraphs under about 50 words.
- Caveats show up as sections named by their subject, when there is something to say: "no_std
  support", "Platform support", "Scope of this crate", "Comparison to X". A generic
  "Limitations" section is rare.

## Model it on the field

Before writing, fetch the READMEs of 4 to 8 well-regarded projects of the same kind (raw
GitHub URLs, or `https://crates.io/api/v1/crates?sort=downloads&category=...` to find them) and
list their headings. Copy their shape (which sections, their order, how long, where examples
go), never their wording. To redo the survey above, fetch READMEs for the top crates by
downloads and count headings by pattern.

## Sections

The smallest README that answers what it is, whether it fits, and how to start. Every README
has the top block and a way to start (Usage or Example); every other section earns its place
with content a reader could not infer from the summary. When in doubt, leave it out.

Always:
- `# name`, badges, then one or two plain sentences on what it is, naming concrete things it
  does. A tagline line only when the project has one worth keeping
- `## Usage` (or `## Example`): the dependency line or install command, a real example (a
  compiled library example, or a command with its real output), then the few facts the example
  does not show

Common, when they apply:
- `## License` (and `## Contribution` with the standard terms) for anything published
- `## Features` or `## Crate features`: when the summary cannot hold what it does, or when it
  has cargo features to list
- `## Minimum supported Rust version`: when the crate has an MSRV policy

Only with something to say:
- `## Installation`: for a CLI with packages, system dependencies or build steps. Never for a
  library whose install is the `cargo add` line Usage already shows
- `### CLI` and `### Library` under Usage: when the project ships both
- `## Methodology` (or `## How it works`): when how it decides matters to whether a reader
  trusts the output (an analyzer, a detector)
- `## Supported formats` / platforms: when support is partial and the reader needs the list
- A caveat section named by its subject ("Platform support", "Scope", "Comparison to X") or
  `## Limitations`: only for caveats that would surprise someone who already read the summary
  (a case it gets wrong, an input it cannot read). Never a restatement of what the project is
  or is not ("no I/O" in a codec crate, "not a GUI" in a CLI). A caveat that belongs to one
  part of the API goes in that part's section instead
- `## Performance`: with real numbers
- `## References`: when the method draws on papers or standards; full citations (authors,
  title, venue, year, DOI or link)

## Shape

- Tables for anything with columns: formats, options, exit codes, verdicts, feature flags.
  Libraries rarely need one; CLIs often do.
- A table cell is one short phrase. Caveats about a row go in bullets directly under the
  table, one fact each; never several sentences in a cell, and never a paragraph under the
  table that restates its rows.
- Bullets fit on one line where they can; two at most.
- A paragraph that lists separate facts is bullets. A paragraph that explains is fine, under
  about 50 words.
- An API pattern is shown with a line of code, never described in the abstract.
- No heading that is a phrase or a joke ("What it reads", "The program").
- The library example is compiled as a doc test from the crate (`#[cfg(doctest)]` including
  the README), so a change to the API breaks the build instead of the README.
- Badges: crates.io version, docs.rs, CI, license. No vanity badges.
- `SKILL.md`'s rules for all text apply: no contrast framing, no lead-ins, no "you".
