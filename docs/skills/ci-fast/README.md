# ci-fast

Accelerate repository CI pipelines to sub-1-minute median turnaround without hiding test failures, weakening lint rules, or bypassing required merge gates.

## Use it when

Ask an agent to **speed up CI**, **make CI run under 1 minute**, **audit CI run bottlenecks**, **shard tests by execution time**, **implement PR test selection**, or **set up fast local git hooks**.

## Core Philosophy

Speed optimization must never compromise code quality or falsify test results:
1. **Full suite in merge queue**: Selection only narrows PR feedback loops; the full validation suite always executes before landing on `main`.
2. **Never hide failures**: Zero retries, zero widened timeouts, zero skipped tests. A test requiring a retry points to a bug.
3. **Never check less**: Lint rules and required checks only stay or grow.

## Concrete Budgets

- **Waiting (Queue latency)**: `< 5 seconds` (Warm runners / Blacksmith / concurrency cancellation)
- **Setup**: `< 15 seconds` (Bake toolchain, blobless clone `filter:blob:none`, node_modules cache)
- **Slowest required job**: `< 35 seconds` (Parallel execution, small checks folded into one job)
- **Lint**: `< 1 second` (`bun lint` with `.oxlintrc.json`)
- **Format**: `< 1 second` (`bun fmt` / `oxfmt`)
- **Typecheck**: `< 5 seconds` (`bun check` on TypeScript)
- **Tests**: `< 30 seconds per shard` (`bun test` / Vitest with greedy `TimeSequencer` bin-packing)
- **Local hooks**: `< 9 seconds` (`hk` / `lefthook` zero-overhead pre-commit and pre-push hooks)

## Safety & Change Gate

All external infrastructure changes requiring secrets, paid accounts, or new recurring bills (e.g. Blacksmith runner subscriptions) must be presented as a single itemized monthly cost list for user confirmation before implementation. Each optimization lands as an isolated, single-concern PR with real before-and-after metrics.

See [`../../../ci-fast/SKILL.md`](../../../ci-fast/SKILL.md) for the authoritative workflow, scripts, and templates.
