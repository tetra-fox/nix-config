---
name: write-rust
description: How to write idiomatic, correct, safe Rust and how to review or audit Rust code for real problems, current through Rust 1.100 and edition 2024. Covers when a clone is fine or a smell, error design, modelling with types, API design, async and tokio pitfalls (blocking, locks across .await, cancel safety, futurelock, detached tasks, unbounded channels), concurrency, unsafe and soundness, and the modern features and lint changes models get wrong. Use it whenever writing, reviewing, refactoring or auditing Rust, when asked whether some Rust is idiomatic, when a borrow-checker fight, a !Send future, a deadlock, a panic or a clippy warning needs fixing, or when someone asks to "audit", "review" or "clean up" a Rust crate or workspace, even if they don't mention idioms.
---

# Write Rust

How to write Rust the way the language wants to be written, and how to review it without
inventing problems. Current through **Rust 1.100 stable (2026-11-12), edition 2024**.

Check the project's `rust-toolchain.toml`, `rust-version` and edition before using a feature:
nothing newer than its MSRV, and no edition-2024-only syntax (let chains) on an older edition.
`references/modern.md` has the version of every feature named here.

The through-line: **say what's true in the types, and pay for flexibility only where you can
point at the reason.** Start with owned data, concrete types, plain functions, synchronous code
and safe code; move down a level only with a reason you could write in one sentence.

| Need | Reach for | Move down only when |
|---|---|---|
| Data in a struct | owned fields (`String`, `Vec<T>`) | profiling shows the copies matter → borrowed fields with lifetimes |
| A parameter | a borrow (`&str`, `&[T]`, `&Path`) | the function stores it → take it by value, or `impl Into<String>` |
| Abstraction | a concrete type, then a generic | you need values of different types in one place → `dyn Trait` |
| Shared state | single owner, `&mut` | several tasks need it → `Arc<Mutex<_>>`, or an actor with a channel |
| Execution | synchronous code | there is real waiting on I/O → `async` |
| Errors | `Result` with a typed error | the program cannot continue → panic |
| Memory access | safe APIs | FFI, or measured hot code no safe API serves → `unsafe` with a `SAFETY:` proof |

## Verify, don't trust

A comment, a doc line, a test name or your own memory that claims a property is a claim, not a
fact. "This future is `Send`", "this is cancel safe", "the lock is released before the await",
"this can't panic", "this builds on 1.85": check each one before you rely on it or repeat it.

- Ask the compiler: `fn assert_send<T: Send>(_: &T) {}` and `assert_send(&thing.method(..))`
  in a test settles `Send`; building on the MSRV toolchain settles the version.
- Write the test that would fail if the claim were false (a short interval for a deadlock, a
  split write for a cancel-safety loss, an empty input for a panic), and run it against the
  original code before fixing.
- When the code and its comment disagree, the comment is the bug until shown otherwise.

This matters most where it's least obvious. `drop(guard)` before an `.await` reads as releasing
a `std::sync::MutexGuard`, but the compiler still treats the future as `!Send`; only ending
the guard's scope in a block fixes it. A reader who trusts the comment misses that.

## 1. Ownership and clones

A clone is not a smell. A clone *you can't justify* is. For any `.clone()`, say in one sentence
who needs their own copy and why. If the honest answer is "the borrow checker complained", the
ownership shape is wrong.

- **Cheap, needing no justification:** `Arc`, `Rc`, `Bytes`, channel senders,
  `CancellationToken`, `tracing::Span`, handles wrapping an `Arc`, `Copy` types. Cloning one
  into `tokio::spawn` is how a task gets ownership. `Arc::clone(&x)` vs `x.clone()` is repo style.
- **Owned data handed over, also normal:** an event, message, snapshot or error that outlives
  the borrow needs owned data; `to_owned()` at that boundary is right. Move instead when the
  value isn't used afterwards.
- **Real smells:**
  - cloning a whole collection to iterate it, or a field to call a `&mut self` method. Split
    the borrow by destructuring (`let Self { a, b, .. } = self;`), narrow it with a block, use
    `mem::take`/`mem::replace`, or give the data one owner;
  - allocating to look something up (`map.get(&(a.to_string(), b.to_string()))`): key the map
    so a borrow can find it (nested maps, or `Borrow` on the key);
  - `fn f(x: &T)` whose first line clones `x`: take `T` and let the caller decide;
  - `&String`, `&Vec<T>`, `&Box<T>`, `&PathBuf` parameters (`clippy::ptr_arg`);
  - `Rc<RefCell<_>>` object graphs: use indices or an arena.

Prefer structs that own their data; lifetimes on a struct spread to every user.

## 2. Errors

- **Libraries return typed errors** (an enum, often with `thiserror`, or an opaque struct with
  `kind()`); **applications** use one opaque error with context (`anyhow`, `.context(..)`).
  `Result<_, String>`, `Box<dyn Error>` and `anyhow::Error` in a library's public API are wrong:
  callers can't match on them.
- Keep the cause's kind; add context to the message rather than wrapping a crate error in
  another of the same crate.
- **`Display` vs `source()`:** the error-handling project group's rule is one or the other, not
  both, or chain printers repeat the cause. Some crates deliberately include it in `Display` so
  plain `{}` shows it. Pick one per crate and don't flag the other as a bug.
- **Never drop an error silently.** `let _ = fallible();`, `.ok();`, `unwrap_or_default()` on a
  `Result` lose failures. When ignoring is right, a comment says why.
- **Panics mean a bug or "cannot go on":** `expect("why this holds")` for an invariant is fine,
  and `.lock().unwrap()` is accepted practice. On input from files, sockets or users, every
  `unwrap`, index, slice, `as` cast and unchecked arithmetic is a crash an attacker can
  trigger: use `?`, `.get()`, `checked_*`, `TryFrom`.
- Prefer `?`, combinators and `let ... else` over hand-written `match`. Public fallible
  functions document `# Errors`; ones that can panic, `# Panics`.

## 3. Modelling with types

- **Make invalid states unrepresentable.** Two bools that can't both be true are one enum; a
  struct of `Option`s plus a "kind" is an enum with data; `f(true, false)` at a call site is a sign.
- **A newtype with an invariant enforces it:** fallible constructor, no `pub` inner field, no
  infallible `From` from the weaker type. `Default` and a derived `Deserialize` bypass it.
- **Parse, don't validate:** refine raw input once at the boundary (`NonZeroU32`, `PathBuf`, an
  `Email` type), then pass the refined type inward.
- **Right std types:** `Path`/`PathBuf`, `OsString`, `Vec<u8>`, `Duration`; don't round-trip OS
  data through `String`. Prefer `From`/`TryFrom` and `checked_`/`saturating_` to `as`.
- Match your own enums exhaustively, without `_ =>`, so new variants fail to compile.

## 4. API design

- **Naming:** `as_` free borrow, `to_` expensive or borrowed-to-owned, `into_` consumes; no
  `get_` on getters; `iter`/`iter_mut`/`into_iter`; no `Manager`/`Service`/`Factory`/`Helper`;
  `user::Id`, not `user::UserId`.
- **Parameters:** borrow by default; `impl Into<String>` where it's stored; generic bounds
  (`impl AsRef<Path>`) at public entry points only, never on a struct.
- **Builders** for four or more optional settings: setters named after the field, infallible,
  `build() -> Result` validates; required values go in `builder(..)`.
- **Conversions:** implement `From`, never `Into`; a `From` that can panic is a `TryFrom`.
- **Traits:** `Debug` on every public type (redact secrets by hand); `Clone`, `PartialEq`/`Eq`,
  `Hash`, `Default`, `Display` where they fit. Essential behaviour is inherent; prefer concrete,
  then generic, then `dyn`. Not every service needs an interface. `Deref` is for smart pointers.
- **Future-proofing:** private fields; sealed traits where needed; `#[non_exhaustive]` on enums
  mirroring an external or growing set, not on closed domain enums.
- **Visibility:** private by default, one public path per item (refactors often leave an old
  re-export behind), no glob re-exports or preludes. `#[must_use]` on builders, guards and
  handles whose drop has an effect. Cargo features are additive.

## 5. Async and tokio

- **Never block the executor:** no `std::thread::sleep`, `std::fs`, blocking clients,
  `block_on` or long CPU loops in `async` (aim for 10 to 100 µs between `.await`s). Blocking I/O
  goes in `spawn_blocking` (batch it: one call per job, not one per file operation; it can't be
  aborted), CPU work in `rayon`, forever-loops on their own `std::thread`.
- **`std::sync::Mutex` is fine in async** when no guard crosses an `.await`. That's tokio's own
  advice; "always use tokio's Mutex in async" is folklore. A std guard or `RefCell` borrow held
  across `.await` makes the future `!Send` and can deadlock. Scope it in a block that ends
  first (`drop(guard)` is not enough, see above). Use `tokio::sync::Mutex` only when the lock
  must span an `.await`.
- **Cancel safety:** any future can be dropped at any `.await`, and `loop { select! { .. } }`
  recreates every branch each iteration.
  - Cancel safe: `mpsc`/`broadcast` `recv`, `watch::changed`, `accept`, `AsyncReadExt::read`,
    `AsyncWriteExt::write`, `StreamExt::next`.
  - Not: `read_exact`, `read_to_end`, `read_to_string`, `write_all` (partial progress lost);
    tokio `Mutex::lock`, `RwLock::read`/`write`, `Semaphore::acquire`, `Notify::notified` (queue
    place lost); a dropped `mpsc::Sender::send` loses its message.
  - Fix: create the future once before the loop, `tokio::pin!` it, select on `&mut fut`.
- **Futurelock:** a task holding a future (pinned for `select!`, or in `FuturesUnordered`) that
  `.await`s something else stops polling it. If that future holds a lock the other `.await`
  needs, the task hangs forever. Don't `.await` inside `select!` arms while a held future may
  own a resource; spawn it, or use `JoinSet`.
- **Tasks:** dropping a `JoinHandle` detaches the task (its panic is lost); dropping a `JoinSet`
  aborts its tasks. Decide which, and handle `JoinError`. `join!`/`select!` are concurrency on
  one task, not parallelism. Shutdown: a `CancellationToken` per task plus `JoinSet` or
  `TaskTracker`.
- **Backpressure:** every channel and queue is bounded; `unbounded_channel` and std's
  `mpsc::channel()` only where the producer is bounded by construction. Timeouts on everything
  external.
- **Async traits:** native `async fn` in traits since 1.75; no `#[async_trait]` for static
  dispatch. Callers can't require the future to be `Send` (return-type notation isn't stable in
  1.100), so a public trait for multi-threaded use writes `fn f(&self) -> impl Future<Output =
  T> + Send`. Such traits aren't dyn compatible; keep `#[async_trait]` for `dyn`. Assert a
  library's futures are `Send` in a test.
- Async closures (`async |x| ..`, `AsyncFn*`, 1.85) replace `|x| async move ..`. An `async fn`
  with no `.await` is overhead. Box very large or recursive futures.

## 6. Concurrency

- Data that must stay consistent goes under one lock; short critical sections; no user code
  under a lock; never hand out a guard. Shard or restructure a contended lock; an actor with a
  bounded channel suits I/O resources.
- Check-then-act across two lock acquisitions is a race even in Rust (two callers both miss a
  cache and both load).
- `std::thread::scope` borrows into threads. Atomics: `Relaxed` only for counters nobody
  synchronises on; `Acquire`/`Release` to publish data; test lock-free code with `loom`.
- std `Mutex` and `mpsc` are fine; swapping them for `parking_lot`/`crossbeam` by reflex is
  outdated. No `static` for correctness-relevant state in a library.

## 7. Unsafe and soundness

- `unsafe` needs a reason: FFI, a novel abstraction, or benchmarked hot code with no safe
  equivalent. Never to shorten code or to quiet a `Send` bound.
- **Soundness is absolute:** a safe function that lets any safe caller cause UB is unsound. If
  the danger can't be encapsulated, it's an `unsafe fn` with `# Safety`. The module is the
  soundness boundary. `unsafe` means "misuse is UB", not "dangerous".
- Every `unsafe` block has a `// SAFETY:` comment proving each requirement
  (`clippy::undocumented_unsafe_blocks` is opt-in). `get_unchecked`, `from_utf8_unchecked`,
  `assume_init`, `set_len` move a check onto you; if the safe version costs nothing measurable,
  use it.
- Common UB: data races, dangling or misaligned pointers, a non-unique `&mut`, mutation through
  `&T` outside `UnsafeCell`, invalid values, unwinding through `extern "C"` (use `"C-unwind"`).
- Edition 2024: `unsafe {}` inside `unsafe fn`, `unsafe extern`, `#[unsafe(no_mangle)]`,
  `static mut` references denied, `env::set_var` is `unsafe`. Run Miri on unsafe code.

## 8. Strings, performance, testing, macros

- `&s[..n]` panics off a char boundary; use `s.get(..n)` or `char_indices`. `.len()` is bytes.
  Paths and environment may not be UTF-8.
- **Performance:** measure first, in release. Flag only known cheap costs: allocation in
  loops, `collect()` then iterate, deep clones of large values, unbuffered I/O, index loops,
  large enum variants and errors (box them), SipHash on small keys where HashDoS doesn't apply.
  `#[inline]`, mimalloc, `panic = "abort"`, fat LTO and `target-cpu=native` are deployment
  choices, not defaults.
- **Testing:** test what could regress unnoticed; no tautological tests that restate the code.
  Property tests for round trips. Public behaviour in `tests/`, internals inline.
  `#[tokio::test(start_paused = true)]` for time; `#[should_panic(expected = "..")]`; release-mode
  runs for arithmetic and unsafe code; `cargo hack --feature-powerset` for feature combinations.
- **Macros** are for when you run out of language: try a generic, a trait or a `const fn` first.

## 9. Stale knowledge

Models get these wrong; check `references/modern.md` and `references/lints.md` before relying on
memory about a feature or lint.
- Use `LazyLock`/`OnceLock` (not `lazy_static`/`once_cell`), native async traits (not
  `#[async_trait]` for static dispatch), `#[expect(lint, reason = "..")]` (not bare `#[allow]`),
  `&raw const` (not `addr_of!`), `use<..>` (not `Captures` hacks).
- Stable now: let chains (1.88, edition 2024 only), `if let` guards (1.95), async closures
  (1.85), `assert_matches!` (1.96), `cfg_select!` (1.95), `core::mem::DropGuard` (1.100). Not
  stable in 1.100: gen blocks, `try` blocks, return-type notation, async drop, specialisation.
- Edition 2024: `-> impl Trait` captures all in-scope lifetimes; temporaries in an `if let`
  scrutinee drop before `else`, and a block's tail temporaries drop before its locals.
- `redundant_clone` and `needless_collect` are in **nursery** (off by default); `unused_async`,
  `needless_pass_by_value`, `manual_let_else` are **pedantic**. Never enable all of `restriction`.

## 10. Reviewing code

A review that invents problems costs the author time and teaches them to ignore you.

1. **A pattern match is a candidate, not a finding.** Read the code around every grep hit or
   lint before calling it wrong; most clones, `to_owned`s and `unwrap`s in good code are right.
2. **State what goes wrong, concretely,** with how to trigger it. "Holding this guard across
   `.await` makes `tokio::spawn(store.refresh())` fail to compile" is a finding; "clone
   overuse" is not. Reproduce it when that's cheap (see "Verify, don't trust").
3. **Rank by consequence:** unsoundness, then bugs (wrong results, reachable panics, deadlocks,
   lost data), then API problems costly to change later, then idiom. Report in that order.
4. **Separate defects from preferences.** Contested choices (`Display`/`source()`, `Arc::clone`
   spelling, `non_exhaustive`, `pedantic`, a trade-off like holding a short lock vs copying) are
   the repo's call; offer them as optional.
5. **Fixes keep behaviour** unless the behaviour was the bug, and leave build, tests and clippy
   green. Run them.
6. **Say what's good.** "These clones are correct because..." is a useful result. List what you
   didn't cover.

For a whole crate or workspace, follow `references/audit.md`, which makes coverage systematic.

## Before handing code back

- Builds, tests pass, `cargo clippy --all-targets` clean, with the project's features; on the
  MSRV toolchain if there is one.
- Every claim you make about it (`Send`, cancel safe, can't panic, version) was checked, not
  assumed.
- No `unwrap`/indexing on paths untrusted input reaches; every `expect` says why it holds.
- No std guard across `.await`, no blocking in async, every `select!` branch cancel safe or
  pinned outside the loop, every `JoinHandle` dropped on purpose, every channel bounded.
- `unsafe` blocks have `SAFETY:` comments; errors are typed and none is silently dropped;
  every clone you added has a one-sentence reason.
