# Auditing a Rust codebase

Use this when asked to audit, review or clean up a whole crate or workspace rather than a
single change. The point is coverage: every file is looked at for every class of problem, so
the result doesn't depend on which files happened to be opened. The judgement comes from
`SKILL.md`; this is the procedure.

## 1. Orient (read-only)

- Read the repo's own rules first: `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, the README.
  Its conventions (error style, `Arc::clone` spelling, lint set) override the generic advice.
- Note the toolchain (`rust-toolchain.toml`), `rust-version`, edition, features and
  `[lints]`/`clippy.toml`. Advice must fit them.
- List the crates and the files in each (`cargo metadata`, or the `src/` trees). Separate
  library code, application code, tests, examples and benches: the standards differ (panics
  and `unwrap` are fine in tests).
- Find the gate: how the project builds, tests and lints (justfile, Makefile, CI workflow).
  Run it once to know the starting state.

## 2. Mechanical sweep

These produce candidates, not findings.

Clippy beyond the defaults, without changing the project's config:

```sh
cargo clippy --all-targets --all-features -- \
  -W clippy::pedantic \
  -W clippy::redundant_clone -W clippy::needless_collect \
  -W clippy::significant_drop_tightening -W clippy::future_not_send \
  -W clippy::undocumented_unsafe_blocks -W clippy::unwrap_used \
  -W clippy::clone_on_ref_ptr -W clippy::map_err_ignore -W clippy::unused_result_ok
```

Read the pedantic output selectively: `must_use_candidate`, `missing_errors_doc` and
`module_name_repetitions` are noise for most findings.

Greps worth running (count per file, then read each hit in context):

| What | Pattern (ripgrep) |
|---|---|
| Clones and copies | `\.clone\(\)`, `\.to_owned\(\)`, `\.to_string\(\)`, `\.to_vec\(\)` |
| Panics | `\.unwrap\(\)`, `\.expect\(`, `panic!`, `unreachable!`, `todo!`, `unimplemented!` |
| Indexing and slicing | `\[[^\]]*\.\.`, `\[\w+\]` in parsing code |
| `as` casts | `\bas (u8|u16|u32|u64|usize|i8|i16|i32|i64|isize)\b` |
| Unsafe | `unsafe`, `transmute`, `get_unchecked`, `from_utf8_unchecked`, `assume_init`, `set_len` |
| Locks | `std::sync::(Mutex|RwLock)`, `\.lock\(\)`, `\.read\(\)`, `\.write\(\)` near `\.await` |
| Blocking in async | `std::fs::`, `std::thread::sleep`, `block_on`, `blocking` in files with `async fn` |
| Tasks | `tokio::spawn`, `spawn_blocking`, `JoinHandle`, `let _ = .*spawn` |
| select! | `select!` (then read every branch) |
| Channels | `unbounded_channel`, `mpsc::channel\(\)` |
| Swallowed errors | `let _ = `, `\.ok\(\);`, `unwrap_or_default\(\)` on `Result` |
| Error types | `Result<[^,]+, String>`, `Box<dyn (std::error::)?Error`, `anyhow::` in library crates |
| Parameters | `&String`, `&Vec<`, `&Box<`, `&PathBuf` |
| Stale idioms | `lazy_static`, `once_cell`, `async_trait`, `#\[allow\(`, `addr_of!`, `cfg_if`, `atty` |
| Statics | `static mut`, `static .*: (Mutex|RwLock|OnceLock|LazyLock)` |

For clones especially, group the hits by what's being cloned (`Arc`/handle, `String`, a
collection, an error, a whole struct). Most of a well-written crate's clones fall in the cheap
group and need no further look.

## 3. Read and classify

Read each candidate in context and put it in exactly one bucket:

- **Fine**: correct as written (a cheap `Arc` clone into a task, an owned string for an event,
  an `expect` with a real invariant). Count these; don't list them individually.
- **Improve**: correct but not idiomatic, or a measurable cost (an avoidable deep clone, an
  allocating lookup, `&String`, a stale idiom). Note the fix.
- **Wrong**: a bug, unsoundness, a reachable panic, a deadlock or `!Send` hazard, a
  cancel-safety loss, a swallowed error. Note the scenario that triggers it.

Then read for what greps can't find, file by file, focusing on the areas that matter most:
public API shape (section 4 of `SKILL.md`), error design (2), modelling (3), and every
`select!`, spawn and lock (5, 6). Check the claims a module's docs make against what its code
does.

Verify anything you're about to call a bug: write a failing test or a minimal reproduction when
it's cheap. A finding with a reproduction is worth five without. Verify the code's own claims
the same way: a comment or doc saying a future is `Send`, a branch is cancel safe or a call
can't panic is a candidate finding until the compiler or a test agrees.

## 4. Report

Before changing anything, report:

```
## Findings
### Wrong
1. <file:line> <what goes wrong, concretely; how to trigger it> → <fix>
...
### Improve
...
## Fine
<counts per category, e.g. "214 clones: 180 handles into tasks, 30 owned event data, 4 listed above">
## Not covered
<what wasn't read or run>
```

Order within each section by consequence: unsoundness, then data loss and deadlocks, then
panics, then wrong results, then API cost, then idiom.

## 5. Fix

- One logical change per commit, in the repo's commit style. Wrong before improve.
- Keep the gate green after each fix: build, tests, clippy with the project's own flags.
- Behaviour-changing fixes get a test that fails before and passes after.
- Don't mix mechanical cleanups (spelling `Arc::clone`, reordering imports) with bug fixes, and
  don't make a contested style change the repo hasn't asked for.
- Public API changes in a published library are breaking: note them for the changelog.
