# Modern Rust features and the idioms they replace

Versions checked against `RELEASES.md` on the stable branch and the release posts, for Rust 1.100
(2026-11-12). Check a project's MSRV and edition before suggesting any of these.

| Feature | Stable | Replaces / note |
|---|---|---|
| `let … else` | 1.65 | `match x { Some(v) => v, None => return … }`. Lint: `manual_let_else` (pedantic). |
| GATs | 1.65 | Lending-iterator workarounds. |
| `std::thread::scope` | 1.63 | `crossbeam::scope`, or `Arc` just to borrow into threads. |
| Inline format args `{x}` | 1.58 | `"{}", x`. Lint: `uninlined_format_args` (pedantic in 1.100). |
| `OnceCell` / `OnceLock` | 1.70 | `lazy_static!`, `once_cell::sync::OnceCell`. |
| `Option::is_some_and`, `std::io::IsTerminal` | 1.70 | `map_or(false, …)`, the `atty` crate. |
| `async fn` / RPIT in traits | 1.75 | `#[async_trait]` (still needed for `dyn`). Send limitation: see 6.8. |
| `Result::inspect_err`, `Arc/Rc::unwrap_or_clone` | 1.76 | — |
| C-string literals `c"…"` | 1.77 | `CStr::from_bytes_with_nul(b"…\0")`. Lint: `manual_c_str_literals`. |
| `slice::chunk_by` | 1.77 | `itertools::group_by` for slices. |
| Inline `const { … }` blocks | 1.79 | Helper `const` items. Usable in array repeat and for compile-time asserts (`const { assert!(…) }`). |
| Associated type bounds `T: Trait<Assoc: Bound>` | 1.79 | Extra `where` clauses. |
| `LazyLock` / `LazyCell` | 1.80 | `lazy_static!`, `once_cell::sync::Lazy`. Lint: `clippy::non_std_lazy_statics` (pedantic). `LazyLock::get`/`force_mut` since 1.94. |
| Exclusive range patterns `a..b` | 1.80 | — |
| `Option::take_if` | 1.80 | — |
| `#[expect(lint, reason = "…")]` | 1.81 | `#[allow]`. Warns when the lint no longer fires (`unfulfilled_lint_expectations`). MS M-LINT-OVERRIDE-EXPECT. Lints: `clippy::allow_attributes`, `allow_attributes_without_reason` (restriction). |
| `core::error::Error` | 1.81 | — |
| `hint::assert_unchecked` | 1.81 | — |
| Abort on panic escaping `extern "C"` | 1.81 | Use `extern "C-unwind"` to unwind deliberately. |
| `use<..>` precise capturing | 1.82 (in traits: 1.87) | `Captures<'a>` trick. |
| `&raw const` / `&raw mut` | 1.82 | `ptr::addr_of!` / `addr_of_mut!`. |
| `unsafe extern` blocks, `#[unsafe(attr)]` | 1.82 (required in edition 2024) | — |
| `Option::is_none_or`, `iter::repeat_n`, `is_sorted` | 1.82 | — |
| Empty-type pattern omission | 1.82 | `Ok(x)` alone is exhaustive for `Result<T, !>`/`Infallible` (`let Ok(v) = r;`). |
| `expr_2021` fragment | 1.83 | — |
| `Option::get_or_insert_default`, `Entry::insert_entry` | 1.83 | — |
| Strict-provenance APIs (`ptr::without_provenance`, `addr`, `with_addr`, `map_addr`, `expose_provenance`) | 1.84 | `as usize` round-trips. |
| `isqrt` | 1.84 | — |
| **Edition 2024** | 1.85 | — |
| Async closures and `AsyncFn*` traits (in prelude) | 1.85 | `\|\| async move {}` and `Fn() -> Fut` bounds. |
| `#[diagnostic::do_not_recommend]` | 1.85 | — |
| `FromIterator`/`Extend` for tuples up to arity 12 | 1.85 | Multiple `unzip`s. |
| Trait-object upcasting (`&dyn Sub` → `&dyn Super`) | 1.86 | `as_super()` helper methods. |
| `get_disjoint_mut` (slices, HashMap), `Vec::pop_if`, `OnceLock::wait` | 1.86 | `split_at_mut` gymnastics. |
| `Vec::extract_if`, `LinkedList::extract_if` | 1.87 | Manual `retain` plus collect. |
| `io::pipe`, `split_off*` on slices, `cast_signed`/`cast_unsigned`, `is_multiple_of` | 1.87 | `as` casts between signed and unsigned. |
| **Let chains** `if let A = a && let B = b && cond {}` | **1.88, edition 2024 only** | Nested `if let`. **[verified compiles under edition 2024]** |
| `HashMap/HashSet::extract_if`, `Cell::update`, `as_chunks` | 1.88 | — |
| Naked functions, `cfg(true)`/`cfg(false)` | 1.88 | — |
| Inferred const args `[x; _]` | 1.89 | — |
| `mismatched_lifetime_syntaxes` lint | 1.89 | Fires on `fn f(&self) -> Ref<T>` with a hidden lifetime; write `Ref<'_, T>`. |
| `File::lock` / `try_lock` / `lock_shared` | 1.89 | The `fs2`/`fs4` crates. |
| `Result::flatten` | 1.89 | — |
| `strict_*` integer ops (`strict_add`, etc.) | 1.91 | Panic on overflow in all build modes. |
| `Path::file_prefix`, `PathBuf::add_extension`, `Duration::from_mins/hours`, `BTreeMap::extract_if`, `core::iter::chain`, `str::floor_char_boundary`/`ceil_char_boundary` | 1.91 | — |
| `RwLockWriteGuard::downgrade`, `Box/Rc/Arc::new_zeroed` | 1.92 | — |
| `fmt::from_fn` | 1.93 | Ad hoc `Display` wrapper structs. |
| `Vec::into_raw_parts`, `slice::as_array`, `VecDeque::pop_front_if` | 1.93 | — |
| `slice::array_windows`, `Peekable::next_if_map` | 1.94 | — |
| **`if let` guards in `match` arms** | 1.95 | Nested `if let` inside arms. Not counted for exhaustiveness. |
| **`cfg_select!`** | 1.95 | The `cfg-if` crate. |
| `Vec::push_mut`, `AtomicX::update`/`try_update`, `hint::cold_path`, `core::range` types | 1.95 | — |
| `assert_matches!` / `debug_assert_matches!` | 1.96 | `assert!(matches!(…))`. |
| `bool::ok_or`, `Option/Result::map_or_default`, `NumBuffer`/`format_into` | 1.98 | — |
| `Vec::into_parts`/`from_parts`, `String::from_utf8_lossy_owned` | 1.99 | — |
| **Never type `!` nameable everywhere** | **1.100** | `Infallible` is now an alias for `!`. Never-type fallback is `!` in all editions. |
| **`Allocator` API** (`Vec::new_in`, `Box::new_in`) | **1.100** | Core parts only. |
| **`core::mem::DropGuard`** | **1.100** | Hand-written scope-guard structs or the `scopeguard` crate. `DropGuard::dismiss` gives commit/rollback. |
| `mem::conjure_zst`, `Box::take`, `Box/Rc/Arc::map`, `str::trim_prefix`/`trim_suffix`, `Vec::from_fn`, `bool::toggle` | 1.100 | — |
| Cargo `[lints]` table | 1.74 | Crate-level `#![warn(...)]` attributes; use `[workspace.lints]`. |
| Cargo `unused_dependencies` warning (`[lints.cargo]`) | 1.100 | — |
| Cargo `registry.global-min-publish-age` (dependency cooldowns) | 1.100 | — |
| Cargo MSRV-aware resolver (`rust-version`) | default in edition 2024 | — |

**Edition 2024 semantic changes an LLM may get wrong** (edition guide, REL 1.85; checked with `cargo check` on 1.100):

- **RPIT lifetime capture.**
  - `-> impl Trait` now captures **all** in-scope generic parameters, including lifetimes. `fn f(v: &Vec<i32>) -> impl Iterator<Item = i32>` compiles in 2024 but gives E0700 in 2021 **[verified]**.
  - Opt out with `+ use<>` or `use<'a, T>`. `+ '_` and the `Captures` trick are obsolete.
  - The lint `impl_trait_redundant_captures` flags redundant `use<..>`.
- **`if let` temporary scope.**
  - The scrutinee's temporaries (e.g. a `MutexGuard` from `m.lock().unwrap()`) are dropped **before the `else` branch**. The classic `if let … = *m.lock().unwrap() {…} else { m.lock() }` deadlock is gone in 2024.
  - Since 1.91 this also applies to temporaries from `pin!`/`format_args!`/`write!` in `if let` scrutinees.
  - Migration lint: `if_let_rescope`.
- **Tail-expression temporary scope.**
  - Temporaries in a block's tail expression drop before the block's locals. `{ let c = RefCell::new(..); c.borrow().len() }` compiles in 2024 but gives E0597 in 2021 **[verified]**.
  - Lint: `tail_expr_drop_order`.
- **Never-type fallback** is `!` (since 1.100 in every edition).
- **Match ergonomics reservations.** You can't write `ref`/`mut`/`&` inside patterns that are already default-binding-mode.
- **`gen` is a reserved keyword.** Gen blocks are **not** stable as of 1.100.
- **Reserved syntax:** guarded strings `#"…"#` and `##` are reserved.
- **Prelude** adds `Future` and `IntoFuture`.
- **`Box<[T]>`** implements `IntoIterator` by value.
- **Unsafe changes** are listed in 5.5.
- **Doc tests** are merged into one binary; see 8.3.
- **Cargo:** MSRV-aware resolver; `default-features = false` on inherited workspace dependencies is now an error if unused.
- **Rustfmt:** `style_edition` is separate from the language edition.

**Not stable as of 1.100 (don't suggest on stable):**
- gen blocks and `AsyncIterator`;
- `try` blocks;
- return-type notation;
- `impl Trait` in type aliases / associated types (TAIT/ATPIT);
- async drop;
- specialisation;
- non-poisoning `std::sync::nonpoison` locks;
- a 2027 edition.

(From a grep of `RELEASES.md`; none of these appear as stabilised.)

**Outdated idioms to flag:**
- `lazy_static!` / `once_cell` → std `LazyLock`/`OnceLock` (`clippy::non_std_lazy_statics`).
- `#[allow]` without a reason → `#[expect(…, reason = "…")]`.
- `#![deny(warnings)]` in source → `RUSTFLAGS=-Dwarnings` in CI or `[lints]` (PAT anti_patterns/deny-warnings). The lint list on that PAT page is **stale**: `const_err` and `private_in_public` no longer exist.
- `try!` → `?`.
- `extern crate` (2018+).
- `Box<dyn Error>` in library APIs.
- `async_trait` without a `dyn` need.
- `cfg-if` → `cfg_select!`.
- `atty` → `IsTerminal`.
- `scopeguard` → `DropGuard`.
- `ptr::addr_of!` → `&raw`.
- `Captures`/`'_` hacks → `use<>`.
- `matches!` inside `assert!` → `assert_matches!`.
- `mem::uninitialized` → `MaybeUninit`.
- `static mut` → atomics, `OnceLock` or `Mutex`.


## Sources

- REL: Rust release notes, https://raw.githubusercontent.com/rust-lang/rust/stable/RELEASES.md
- MS: Microsoft Pragmatic Rust Guidelines (2026.6), https://microsoft.github.io/rust-guidelines/
- ER: Effective Rust (David Drysdale), https://www.effective-rust.com/
- PAT: Rust Design Patterns, https://rust-unofficial.github.io/patterns/
- CORRODE: https://corrode.dev/blog/ (pitfalls-of-safe-rust, defensive-programming, hardening-rust)
- [verified]: compiled or run on Rust 1.100 while this was written
