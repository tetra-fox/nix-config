# Lint facts and configuration

From `cargo clippy -- -W help` on Rust 1.100. Group membership changes between releases: check
it, don't assume it.

**Facts (from 1.100's `cargo clippy -- -W help`):**
- **On by default (`clippy::all`):** `correctness` (deny), `suspicious`, `style`, `complexity`, `perf`.
- **Opt-in:** `pedantic`, `nursery`, `restriction`, `cargo`.
- **Some lints moved groups. LLMs often get this wrong:**
  - `redundant_clone`, `needless_collect`, `or_fun_call`, `significant_drop_tightening`, `significant_drop_in_scrutinee`, `future_not_send`, `missing_const_for_fn`, `use_self` and `derive_partial_eq_without_eq` are **nursery**.
  - `module_name_repetitions` is **restriction**.
  - `uninlined_format_args` is **pedantic**.
  - `large_futures`, `unused_async`, `needless_pass_by_value`, `manual_let_else`, `non_std_lazy_statics` and `unchecked_time_subtraction` are **pedantic**.
  - `unchecked_duration_subtraction` was renamed `unchecked_time_subtraction`.
  - `transmute_int_to_char` and `transmute_int_to_float` were moved into rustc's `unnecessary_transmutes`.
  - CORRODE's pitfalls post still uses the old names **[verified via renamed_and_removed_lints warnings]**.
- **Never enable the whole `restriction` group.** Clippy itself warns (`blanket_clippy_restriction_lints`); its lints contradict each other.
- **Group priority:** Group levels in `[lints]` need `priority = -1` so individual overrides win (`lint_groups_priority`, correctness).

**Recommended baseline (Cargo.toml).** This synthesises the MS M-STATIC-VERIFICATION set, CORRODE pitfalls and defensive-programming, and ER Item 29.

```toml
[lints.rust]
unsafe_op_in_unsafe_fn = "warn"        # default in 2024; keep explicit for older editions
missing_debug_implementations = "warn" # MS
unreachable_pub = "warn"               # libraries
redundant_imports = "warn"             # MS
redundant_lifetimes = "warn"           # MS
unused_lifetimes = "warn"              # MS
trivial_numeric_casts = "warn"         # MS
ambiguous_negative_literals = "warn"   # MS
let_underscore_drop = "warn"
# unsafe_code = "forbid"               # crates with no unsafe

[lints.clippy]
all = { level = "warn", priority = -1 }
pedantic = { level = "warn", priority = -1 }   # MS and many projects; prune noisy ones below
cargo = { level = "warn", priority = -1 }      # MS; drop for internal crates (multiple_crate_versions noise)
# pedantic opt-outs commonly taken:
module_name_repetitions = "allow"   # (restriction now; listed for older configs)
must_use_candidate = "allow"
missing_errors_doc = "allow"        # for apps only
# restriction lints worth enabling (MS list + safety):
allow_attributes_without_reason = "warn"
undocumented_unsafe_blocks = "warn"
multiple_unsafe_ops_per_block = "warn"
unnecessary_safety_comment = "warn"
unnecessary_safety_doc = "warn"
clone_on_ref_ptr = "warn"            # style-contested, see 1.4
map_err_ignore = "warn"
unused_result_ok = "warn"
assertions_on_result_states = "warn"
if_then_some_else_none = "warn"
empty_drop = "warn"
empty_structs_with_brackets = "warn"
empty_enum_variants_with_brackets = "warn"
deref_by_slicing = "warn"
renamed_function_params = "warn"
semicolon_outside_block = "warn"
as_pointer_underscore = "warn"
fn_to_numeric_cast_any = "warn"
redundant_type_annotations = "warn"
unneeded_field_pattern = "warn"
disallowed_script_idents = "warn"
dbg_macro = "warn"
todo = "warn"
print_stdout = "warn"                # libraries / services (MS M-LOG-NOT-PRINT)
print_stderr = "warn"
# panic-surface lints for untrusted-input / service code (corrode); usually allow in tests via clippy.toml:
unwrap_used = "warn"
expect_used = "warn"                 # contested: MS accepts expect("reason") for invariants
indexing_slicing = "warn"            # noisy; scope to parsing modules with #[warn]
panic_in_result_fn = "warn"
unwrap_in_result = "warn"
# selected nursery lints with good signal:
redundant_clone = "warn"
significant_drop_tightening = "warn"
needless_collect = "warn"
```

`clippy.toml`: `allow-unwrap-in-tests = true`, `allow-expect-in-tests = true`, `allow-indexing-slicing-in-tests = true`, `allow-panic-in-tests = true`, `msrv = "1.85"` (or the crate's MSRV), `await-holding-invalid-types = [...]`, `disallowed-methods` / `disallowed-types` (e.g. ban `std::thread::sleep` in async crates, `std::collections::HashMap` if mandating a fast hasher).

**Contested points:**
- **`unwrap_used` / `expect_used`.**
  - MS M-PANIC-IS-STOP: `expect("…")` is right for programming errors and for lock poisoning.
  - ER Item 18 and CORRODE: minimise them; in untrusted-input code, treat each as a potential CVE.
  - Recommendation: deny `unwrap_used`, allow `expect` with a message for invariants. Or scope both lints to input-handling modules.
- **`pedantic` wholesale.**
  - MS enables pedantic, cargo and every default group.
  - ER Item 29: be warning-free, but don't necessarily enable noisy groups ("unlikely to want to enable … overly pedantic").
  - Middle ground: enable pedantic, then `#[expect]` or allow specific lints with reasons.
- **`nursery`.** MS comments it out as "optional, might cause more false positives". Cherry-pick instead.

**Process:**
- Run `cargo clippy --all-targets --all-features -- -D warnings` in CI; never use `#![deny(warnings)]` in source (PAT).
- Run `cargo fmt --check`, `cargo hack --feature-powerset check`, `cargo audit` / `cargo deny`, `cargo +nightly miri test` (for unsafe), and an MSRV build in CI (MS M-STATIC-VERIFICATION; ER Items 31–32).
- Cargo 1.100 now warns about unused dependencies natively, which partly replaces `cargo-udeps`.
- Lint overrides use `#[expect(lint, reason = "…")]` (MS M-LINT-OVERRIDE-EXPECT).

## Sources

- REL: Rust release notes, https://raw.githubusercontent.com/rust-lang/rust/stable/RELEASES.md
- MS: Microsoft Pragmatic Rust Guidelines (2026.6), https://microsoft.github.io/rust-guidelines/
- ER: Effective Rust (David Drysdale), https://www.effective-rust.com/
- PAT: Rust Design Patterns, https://rust-unofficial.github.io/patterns/
- CORRODE: https://corrode.dev/blog/ (pitfalls-of-safe-rust, defensive-programming, hardening-rust)
- [verified]: compiled or run on Rust 1.100 while this was written
