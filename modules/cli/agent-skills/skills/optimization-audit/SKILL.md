---
name: optimization-audit
description: Crawl a codebase for micro- and macro-optimization candidates (algorithmic complexity, redundant work, allocation churn, data-structure choice, IO and syscall patterns, cache behavior), then surface them ranked by likely payoff so the user can decide what's worth doing. The companion to a perceived-latency pass: that one is about WHEN the user is unblocked, this one is about how much actual work the machine does. Use when the user wants to make code genuinely faster or lighter (throughput, memory, CPU, allocations), profile for hotspots, find algorithmic or allocation problems, or asks to "optimize" or speed up real computation. NOT for perceived responsiveness (use perceived-latency) and NOT a license to rewrite clear code for unmeasured gains.
---

# Optimization Audit

This skill finds places where the program does more work than it needs to: worse algorithmic complexity than necessary, repeated work that could be done once, allocations that could be avoided, data structures that don't fit their access pattern, IO done in a slow shape. It is the throughput/resource companion to the perceived-latency skill, which is about ordering work relative to the user. This one is about reducing the work itself.

The single most important thing about this skill: **it is mostly a measurement and triage skill, not an editing skill.** Most of the value is in finding and ranking candidates and proving which ones matter. Applying the change is the small last step, and it only happens for candidates that earned it.

## The discipline (read this before doing anything)

Optimization done by vibes makes code worse. These rules are not optional.

1. **Measure before you touch anything.** An optimization on a path that runs once at startup is wasted effort and added complexity. Find out what's actually hot before proposing changes. If there's no way to measure (no benchmark, no profiler, no representative workload), say so and ask the user whether it's worth setting one up, rather than guessing at hotspots from reading code. Reading code tells you what's *theoretically* expensive; measurement tells you what's *actually* expensive, and they disagree more often than not.

2. **Optimize the hot path, ignore the cold path.** 95% of runtime is usually in a tiny fraction of the code. Optimizing anything else trades real readability for imaginary gains. A clear O(n^2) loop over a list that's always 3 elements long is fine, leave it. The cold path should stay as readable as possible precisely because no one will ever profile it.

3. **Prove each change actually helped.** Every applied optimization needs a before/after measurement on a representative workload. "Should be faster" is not "is faster." Compilers, allocators, and CPUs routinely make the obvious-looking optimization a wash or a regression (a "zero-copy" rewrite that wrecks cache locality, a `Vec::with_capacity` that's now wrong because the size changed, an unrolled loop the compiler was already vectorizing). No measurement, no merge.

4. **Never trade correctness for speed.** Same rule as perceived-latency. A faster wrong answer is worthless. Optimizations frequently introduce subtle bugs (off-by-one in a manual loop that replaced an iterator, an overflow in integer math that replaced checked math, a race in code that was parallelized). The test suite must stay green and the observable output identical.

5. **Readability is a real cost, weigh it explicitly.** A 2% speedup on a cold path that turns five clear lines into twenty clever ones is a bad trade. A 10x speedup on the hottest loop that adds a comment explaining the trick is a good one. State the readability cost alongside the speed benefit for every candidate so the user can judge. Default to leaving clear code alone.

6. **One optimization per change, measured independently.** Batched optimizations hide which one helped and which one regressed. If you apply five and the benchmark improves 8%, you don't know that two of them helped 10% and three hurt 2%. One at a time, measured, committed (or reverted) on its own.

## Workflow

1. **Establish what "fast enough" means and what the workload is.** Ask the user: what's slow, in what scenario, and how would we know it got better? An optimization audit without a target workload is a fishing trip. If the user has a specific complaint ("processing a 4k frame takes 200ms and I want 16ms"), that's your benchmark. If they don't, help them define one before profiling.

2. **Measure to find hotspots.** Use the right tool for the language: a profiler (`perf`, `cargo flamegraph`, `py-spy`, `pprof`, the browser profiler), a benchmark harness (`criterion` for Rust, `pytest-benchmark`, etc.), or targeted timing if nothing else exists. Identify where time and allocations actually go. Bring back a ranked list of hotspots, not a vague sense.

3. **Generate candidates, ranked by expected payoff.** For each hotspot, identify what's making it slow and what could be done about it (categories below). Rank by (expected speedup) weighted against (readability cost) and (risk of introducing a bug). A safe 5x on the hottest function outranks a risky 1.2x everywhere.

4. **Present candidates before editing.** Give the user the ranked list with, for each: where it is, what's slow about it, the proposed change, the expected payoff, the readability cost, and the risk. Let them choose. Many candidates will be "technically true but not worth it" and the user should get to say so.

5. **Apply one at a time, measure each, keep or revert.** For each chosen candidate: make the change, run the benchmark, compare. If it helped and tests pass, keep it (commit). If it didn't help, or regressed, or the readability cost isn't worth the measured gain, revert it. Be willing to revert. A reverted optimization is a successful experiment, not a failure.

6. **Re-measure the whole workload at the end.** Per-change measurements can mislead because of interaction effects. Confirm the end-to-end workload actually improved by a meaningful amount. If the sum of "10% here, 15% there" produced a 3% end-to-end change, the hotspots were mismeasured, say so.

## Macro-optimizations (algorithmic, structural; usually the big wins)

These are where the real speedups live. A better algorithm beats a hand-tuned bad one every time.

- **Complexity reduction.** An O(n^2) that should be O(n log n) or O(n). Nested loops doing membership checks that a hash set would make O(1). Repeated linear scans that a sorted structure or index would collapse. This is the first thing to look for because it's the only category that changes the *shape* of the curve, not just the constant.
- **Redundant recomputation.** The same expensive value computed multiple times across calls when it could be computed once and cached or memoized. Work done per-iteration that's invariant across the loop. Re-parsing, re-hashing, re-sorting data that hasn't changed.
- **Doing work that gets thrown away.** Computing a full result when only part is used. Sorting an entire collection to find the top 3 (use a partial selection). Building a structure that's immediately discarded. Eager evaluation of things that are rarely needed.
- **Wrong data structure for the access pattern.** A `Vec` with frequent membership tests (wants a `HashSet`). A `HashMap` iterated in order every time (might want a sorted structure or a `Vec` of pairs). A linked structure with poor cache behavior where a flat array would do. Repeated front-insertion into a `Vec` (wants a `VecDeque` or a rethink).
- **Batching and amortization.** N syscalls / queries / round-trips that could be one batched call. Per-item IO that could be buffered. A database N+1 pattern. Lock acquired per-item in a loop instead of once around it.
- **Parallelism where it's safe and worth it.** Genuinely independent work done sequentially. But: only when the work per item exceeds the coordination overhead, only when it's actually independent (no hidden shared state), and measured, because parallelism overhead frequently eats the gain on small workloads.

## Micro-optimizations (constant-factor; smaller, riskier, weigh carefully)

These matter only on genuinely hot paths and are where readability gets endangered. Apply sparingly and only with measurement.

- **Allocation churn.** Allocating inside a hot loop what could be allocated once and reused. `collect()` into a temporary that's immediately consumed. String building that reallocates repeatedly (wants reserved capacity). Cloning where a borrow would do (but see CLAUDE.md, anxious-clone *removal* can also be a correctness change, do it carefully). Boxing that isn't needed.
- **Unnecessary copying.** Passing large values by move/copy where a reference works. Returning owned data that the caller only reads. Readback or serialization that a shared reference avoids.
- **Reserve capacity.** `Vec::with_capacity` / `String::with_capacity` / `HashMap::with_capacity` when the final size is known or estimable, to skip reallocation-and-copy as it grows. One of the safest micro-opts because it doesn't change logic.
- **Avoid redundant bounds checks / re-validation** on a hot path, where it's provably safe (iterators over indexing, validate-once instead of per-access). Be careful: this is where `unsafe` temptation lives, and unsafe-for-speed needs an extremely high measured bar.
- **Cheap-check-first ordering** in boolean conditions and match arms: put the condition most likely to short-circuit, and cheapest to evaluate, first. Free, safe, often missed.
- **Integer/float and bit-twiddling tricks.** Almost never worth it. The compiler does these better than you, and they destroy readability. Only on a measured, proven, extremely hot inner loop, with a comment, and even then be suspicious.

## What to leave alone

- **Anything not measured to be hot.** This is the cardinal rule restated. The cold path stays readable.
- **Code where the compiler already does it.** Modern compilers vectorize, inline, hoist invariants, elide bounds checks, and reuse allocations. Hand-doing what `-O2`/`--release` already does adds clutter for nothing. When in doubt, check the generated assembly or just measure, don't assume the compiler is naive.
- **Optimizations that fight the language.** Manual index loops in Rust/Python to "avoid iterator overhead" that doesn't exist. Reimplementing standard-library functions that are already optimal. These read as wrong-flavor idioms (see de-ai-smell) and usually aren't even faster.
- **Premature generality dressed as optimization.** Adding caching layers, object pools, or arenas "for performance" before there's a measured allocation problem. This is complexity that has to be maintained forever to solve a problem that may not exist.
- **Anything where the readability cost exceeds the measured benefit.** Stated for the third time because it's the rule most often violated.

## A note on the relationship to perceived-latency

Run perceived-latency first if the complaint is "it feels slow / it hangs / the UI freezes." Reordering so the user is unblocked sooner often makes the actual-throughput optimization unnecessary, because the slow work moves off the path the user waits on and nobody cares how long it takes in the background. Only reach for this skill when the work itself is genuinely too slow or too heavy: a computation that's too slow even in the background, memory use that's too high, a batch job whose wall-clock actually matters. Felt-speed problems are usually ordering problems, not throughput problems. Don't optimize the work if you can just move it.
