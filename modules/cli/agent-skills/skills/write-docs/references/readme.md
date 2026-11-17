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

## Section order

Use the sections that apply, in this order, with these plain names:

1. `# name`, the italic tagline directly under it, badges, then one or two sentences on what
   it is, naming concrete things it does
2. `## Features`: one-line bullets of what it does
3. `## Methodology` (or `## How it works`): a short paragraph and a table, only for projects
   whose method matters to whether a reader trusts the output
4. `## Supported formats` / platforms: a table
5. `## Installation`: the one command
6. `## Usage`, with `### CLI` and `### Library` when both exist: a real command with real
   output first, then options as a table, exit codes as a table; the library's dependency line,
   one compiled example, a few bullets on behaviour, feature flags as a table
7. `## Limitations`: one-line bullets of what it cannot do or tell
8. `## References`: full citations (authors, title, venue, year, DOI or link) for papers and
   standards the method draws on
9. `## License`

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
  "Usage" and "Installation".
- The library example is compiled as a doc test from the crate (`#[cfg(doctest)]` including
  the README), so a change to the API breaks the build instead of the README.
- Badges: crates.io version, docs.rs, CI, license. No vanity badges.
- `SKILL.md`'s rules for all text apply: no contrast framing, no lead-ins, no "you".
