# READMEs

Part of the `write-docs` skill. A README is a project's first impression: a stranger should
know what it is, whether it fits, and how to start within a minute of skimming.

## Model it on the field

Fetch the READMEs of 4 to 8 well-regarded projects of the same kind (raw URLs) and list their
headings before writing. Projects that model a README well:

- CLI tools: ripgrep, fd, hyperfine, bat
- Rust libraries: lofty, Symphonia, rubato, serde, tokio
- Both at once: tools that ship a library and a binary from one crate

Copy their shape (section order, use of tables, length of bullets, where examples go), never
their wording.

## Sections

The smallest README that answers what it is, whether it fits, and how to start. Every README
has the top block, Usage and License; every other section is optional and earns its place
only with content a reader could not infer from the title and the summary. Copy the sections
the reference projects in the field actually have: most library crates have no Installation
or Limitations section at all. When in doubt, leave a section out.

Always:
- `# name`, the italic tagline directly under it, badges, then one or two sentences on what it
  is, naming concrete things it does
- `## Usage`: the dependency line or install command, then a real example (a compiled library
  example, or a command with its real output), then the few facts the example does not show
- `## License`

Only when it has something to say, in this order:
- `## Features`: when the summary cannot hold what it does; one-line bullets
- `## Methodology` (or `## How it works`): when how it decides matters to whether a reader
  trusts the output (an analyzer, a detector); a short paragraph and a table
- `## Supported formats` / platforms: when support is partial and the reader needs the list
- `## Installation`: only when installing takes more than the one line Usage already shows (a
  CLI with packages, system dependencies, build steps). A library's `cargo add` line belongs
  at the top of Usage, not in its own section
- `### CLI` and `### Library` under Usage: when the project ships both
- `## Limitations`: only caveats that would surprise someone who already read the summary (a
  case it gets wrong, an input it cannot read). Never a restatement of what the project is or
  is not ("no I/O" in a codec crate, "not a GUI" in a CLI)
- `## References`: when the method draws on papers or standards; full citations (authors,
  title, venue, year, DOI or link)

## Shape

- Tables for anything with columns: formats, options, exit codes, verdicts, feature flags.
- Bullets fit on one line where they can; two at most.
- Paragraphs only where a list cannot carry the content, and short. A paragraph that states
  three separate facts is three bullets (an events section: "a stream on the client", "grouped
  by topic", "one stream per topic on its handle").
- A table cell is one short phrase. Caveats about a row (what is excluded, a security note)
  go in bullets directly under the table, one fact each; never several sentences in a cell,
  and never a paragraph under the table that restates its rows.
- An API pattern is shown with a line of code, never described in the abstract.
- No heading that is a phrase or a joke ("What it reads", "The program"). A reader scans for
  plain names like "Usage" and "Features".
- The library example is compiled as a doc test from the crate (`#[cfg(doctest)]` including
  the README), so a change to the API breaks the build instead of the README.
- Badges: crates.io version, docs.rs, CI, license. No vanity badges.
- `SKILL.md`'s rules for all text apply: no contrast framing, no lead-ins, no "you".
