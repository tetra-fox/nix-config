---
name: perceived-latency
description: Audit a codebase for places where the user waits longer than they need to, and restructure so the interface responds at the earliest correct moment rather than the latest. Covers reordering work so visible/interactive milestones happen before background work, bailing early on operations that can be known to fail before they're attempted, short-circuiting redundant work, moving slow work off the path the user is waiting on, and warming or precomputing what can be ready before it's asked for. Use when the user wants to make an app "feel faster," reduce lag or jank, improve responsiveness, tighten interaction latency, or mentions a UI that hangs/stalls/freezes during an operation. This is about perceived latency (when the user can see and act), not raw throughput.
---

# Perceived Latency

The user experiences latency as the time between an action and the moment they can see the result and move on. That is almost never the same as the total work the program does. A program can do less work and feel slower, or do the same work and feel instant, depending entirely on _ordering_: what happens before the user is unblocked versus after.

Your job is to find every place where the user is waiting on work that didn't have to be on their critical path, and move it off. The critical path is the chain of operations between the user's action and the user being unblocked. Everything else is background, even if it's important.

This is not a throughput-optimization skill. You are not hunting for faster algorithms or fewer allocations (though if you spot an obvious one on the critical path, mention it). You are restructuring _when_ things happen relative to _when the user is freed_.

## The one question that drives everything

For any operation the user triggers, ask: **what is the earliest moment the user could correctly be unblocked, and is the code unblocking them then or later?**

"Correctly" is load-bearing. Unblocking the user before the result is actually valid is a bug, not an optimization. The skill is about finding the genuine earliest-correct moment, not faking responsiveness by lying about completion.

The example that motivates this skill: a region-select tool that dismisses its picker overlay _after_ encoding finishes leaves the picker hanging on screen during the encode. The encode doesn't need the picker visible. The earliest-correct moment to dismiss the picker is the instant the selection is confirmed, before the encode starts. Same total work, the interface feels done the moment the user expects it to.

## The patterns, roughly in order of impact

### Reorder: visible milestone before background work

The highest-impact pattern. Find operations where a user-visible state change (a window closing, a result appearing, a cursor freeing, a "done" indicator) happens _after_ work that the visible change doesn't depend on. Move the visible change earlier.

- Tear down UI the moment it's no longer needed, not after the operation it preceded completes.
- Show the result as soon as it exists, then do cleanup/logging/cache-writes/telemetry after.
- Free the user's input focus or cursor before starting work that doesn't need it held.
- If the user kicked off something fire-and-forget, return them to ready state immediately and let the work finish in the background.
  The test: for each line of work between the user's action and the user being freed, ask "does the user being freed actually _depend_ on this line?" If not, it belongs after the free, not before.

### Bail early: detect failure before doing expensive work

If an operation will fail, fail it before paying the cost, not after. Users forgive fast failures; they resent slow ones, and they _really_ resent a slow operation that was doomed from the first line.

- Validate cheaply-checkable preconditions up front: does the output path's directory exist and is it writable, is the requested region non-empty, is the required protocol/device/permission present, is the input non-degenerate.
- Check the things most likely to fail _first_, before the things that are expensive to set up. Don't allocate a pipeline and then discover the output is unwritable.
- Prefer a check that's cheap and certain ("this file handle is null") over starting work optimistically and unwinding on error.
- Distinguish "will definitely fail" (bail now) from "might fail" (can't bail, must attempt). Only short-circuit on certainties.

### Short-circuit: skip work that can't change the outcome

- Return early when the answer is already known. If a cache hit settles it, don't compute. If the input is empty, don't run the loop. If nothing changed since last time, don't recompute.
- Avoid recomputing values that are stable across a call. Hoist invariant work out of loops and out of per-frame/per-event paths.
- Collapse redundant passes over the same data into one.
- Guard expensive paths behind the cheap check that determines whether they're needed at all.
  Be careful: short-circuiting is the pattern most likely to introduce bugs, because "this can't change the outcome" is an assumption that's easy to get wrong. Each short-circuit must be defensible as _certainly_ not skipping necessary work. When in doubt, surface it rather than applying it.

### Move off the critical path: defer, background, or parallelize

- Work that must happen but that the user isn't waiting on (cache writes, logging, telemetry, cleanup, prefetch of the next thing) goes after the user is unblocked, or onto another thread/task.
- Work that the user _is_ waiting on but that's independent of other waited-on work can run concurrently rather than in sequence.
- Slow initialization that isn't needed for the first interaction can be lazy or deferred until first use.
- Be honest about what's actually independent. Backgrounding work that a later step depends on just moves the stall, or introduces a race.

### Warm ahead: have it ready before it's asked for

- State that's expensive to build and reused across invocations can be kept warm (a long-lived connection, a compiled pipeline, a cache that survives the operation).
- Work that can be started speculatively the moment intent is signaled, before the full request is known, shrinks the felt latency to near zero when the speculation is right.
- Speculative and warm work has a cost: the cancellation/discard path. If you start work early and the user does something that invalidates it, that work must be cleanly discardable without leaking resources or corrupting state. A warm/speculative optimization with a buggy cancel path is worse than no optimization. Always check the discard path when you find or add one.

## Consistency matters as much as speed

A path that's usually fast and occasionally slow feels worse than one that's reliably medium. People notice variance more than absolute latency. When auditing:

- Find the slow path, not just the fast path. The warm-cache hit being instant doesn't help the cold-start case the user hits first after launch.
- Look at the worst case (p99), not the median. The occasional 10x stall is what gets remembered and reported.
- A short-circuit that helps the common case but leaves a rare case much slower can _increase_ perceived-latency complaints even while improving the average. Note when an optimization widens the gap between best and worst case.

## The exit of an interaction counts too

Latency at the _end_ of an operation is as real as latency at the start. An operation that finishes its work but then takes a visible beat to tear down (flush a buffer, finalize a file, close a window, release a device) leaves the user waiting after they thought they were done. Audit the teardown path, not just the setup path. The user is unblocked when the interface returns to ready, which may be well after the "real work" completed.

## How to do the audit

1. **Map the critical paths first.** Identify the handful of operations the user actually triggers and waits on (the hot interactions, not every function). For each, trace the chain from user-action to user-unblocked. You can't optimize perceived latency without knowing what the user is perceiving, so find the interaction points before touching anything.
2. **For each critical path, walk it line by line asking the one question:** is the user being unblocked at the earliest correct moment? Note every place where work sits before the unblock that doesn't need to.
3. **Present findings before editing.** Group by pattern (reorder / bail-early / short-circuit / move-off-path / warm-ahead), with the specific location and the proposed change, and an estimate of whether it's on a hot path or a cold one. Let the user pick what to apply. Some "optimizations" trade complexity for latency the user won't perceive; the user decides if that trade is worth it.
4. **Apply in small, separately-reviewable changes.** Reordering and short-circuiting can change behavior in subtle ways (especially around error handling and partial-failure states). One change per commit, tests green between each. A perceived-latency change that introduces a correctness bug is a net loss — the user would rather wait than get a wrong or corrupt result.
5. **Verify the behavior didn't change.** For each reorder or short-circuit, confirm the observable result (not just that it compiles) is identical to before. The whole premise is _same correct outcome, sooner_ — if the outcome changed, it's not this skill's kind of change.

## What not to do

- **Don't fake completion.** Dismissing UI or signaling "done" before the result is actually valid is a bug dressed as a feature. Earliest _correct_ moment, never earlier.
- **Don't optimize cold code.** Restructuring a path the user hits once a session, or never waits on, adds complexity for no felt benefit. Spend the effort on the hot interactions.
- **Don't trade correctness for speed.** Every short-circuit and reorder must produce the identical observable outcome. When you can't be certain it does, surface it as a question instead of applying it.
- **Don't introduce races to look fast.** Backgrounding or parallelizing work that has real ordering dependencies moves the stall or creates a heisenbug. Only background what's genuinely independent.
- **Don't add speculative/warm work without auditing its discard path.** The cancellation case is where these optimizations rot.
- **Don't micro-optimize in the name of perceived latency.** Shaving microseconds off work the user can't perceive is throughput work, not this. If it's not on a path the user waits on, it's out of scope.
