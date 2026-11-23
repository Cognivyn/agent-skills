---
name: ci-fast
description: >-
  Accelerate repository CI to achieve sub-1-minute PR feedback at median and under 2 minutes
  at p95 without hiding failures or skipping checks. Performs run-data auditing, enforces strict
  time budgets (waiting <5s, setup <15s, slowest job <35s, local <9s), implements intelligent
  timing-based test sharding, PR test selection, and zero-overhead git hooks.
---

# ci-fast

Drive repository continuous integration (CI) to sub-minute feedback loops while strictly
preserving test fidelity, lint rules, and merge security.

## Target

- **Median PR result**: `< 1 minute`
- **p95 PR result**: `< 2 minutes`

## Three Rules That Outrank Speed

1. **Full suite in merge queue**: The full test and check suite must run before anything reaches `main` in a merge queue. Test selection only narrows PR feedback; it never bypasses validation before landing.
2. **Never hide failures**: Zero retries, zero widened timeouts, zero skipped tests. A check that needs a retry has a bug; identify and fix it.
3. **Never check less**: Lint rules, type checks, and required status gates only stay or grow. Never disable rules to meet a budget.

## Slash Command

OpenCode exposes this skill as `/ci-fast` through `.opencode/commands/ci-fast.md`.
The slash command forwards `$ARGUMENTS` directly to this skill.

Supported argument intents:
- `audit`: Run the 150-run telemetry audit only and report p50/p95 breakdowns across waiting, setup, and execution buckets.
- `shard`: Implement or recalibrate recorded-time test sharding and bin-packing.
- `selection`: Set up PR diff-based test selection and run the intentional defect falsification test.
- `hooks`: Install local pre-commit and pre-push hooks (<9s budget).
- `(empty)`: Run the full phased optimization lifecycle.

---

## Workflow

### Phase 1: Audit and Baseline Telemetry

Never optimize based on intuition. Always audit the real bottleneck first.

1. **Pull telemetry for the last 150 CI runs**:
   Use the bundled audit script or GitHub CLI:
   ```bash
   bun agent-skills/ci-fast/scripts/audit-ci-runs.ts
   ```
   Or via manual `gh` command:
   ```bash
   gh run list --limit 150 --json status,conclusion,createdAt,startedAt,updatedAt,jobs
   ```

2. **Split metrics into three buckets at p50 and p95**:
   - **Waiting (Queue latency)**: Time from `createdAt` to `startedAt`. Target: `< 5s`.
   - **Setup (Environment bootstrap)**: Checkout, runner toolchain prep, package installation, cache retrieval. Target: `< 15s`.
   - **Running (Execution)**: Slowest required job execution time. Target: `< 35s`.

3. **Identify the dominant bucket**:
   Prioritize fixing the largest bucket first. Do not micro-optimize test execution if jobs spend 90 seconds waiting for an available runner.

---

### Phase 2: External Dependencies and Cost Gate

Before introducing paid infrastructure, external runners, or new secrets:

1. **Prepare the External Change List**:
   Present any required external accounts, secrets, or billed services (such as Blacksmith warm runner pools) as a single transparent list with expected monthly costs.
2. **Obtain user approval**:
   Do not commit configurations requiring external subscriptions without explicit user sign-off.
3. **Dual-path architecture**:
   - **Primary path (Warm runners)**: Blacksmith or dedicated warm runner pool (<5s queue time).
   - **Fallback path (GitHub-hosted runners)**: Concurrency cancellation (`cancel-in-progress: true`), blobless clones, and optimized GitHub Action dependency caching.

---

### Phase 3: Budget Optimization Targets

Enforce the following concrete budgets across the repository:

#### 1. Waiting Budget (< 5 seconds)
- **Warm runners**: Migrate off cold GitHub-hosted runners to Blacksmith or warm self-hosted pools.
- **Cancel redundant runs**: Configure GitHub Actions concurrency group to automatically cancel obsolete in-progress runs when a new commit pushes to a branch:
  ```yaml
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  ```

#### 2. Setup Budget (< 15 seconds)
- **Blobless clone**: Avoid downloading full git history:
  ```yaml
  - uses: actions/checkout@v4
    with:
      fetch-depth: 1
      filter: 'blob:none'
  ```
- **Seeded cache & node_modules**: Bake runtime toolchains into runner images where possible. Seed caches from `main`. Cache `node_modules` directly to bypass postinstall scripts when lockfiles are unchanged. Achieve `> 95%` cache hit rate on PRs.

#### 3. Slowest Job Budget (< 35 seconds)
- **Eliminate serialized dependencies**: Ensure no required job waits on another (`needs:` chains between independent checks are banned).
- **Parallel shape**: Run `lint`, `typecheck`, `build`, and `tests` concurrently.
- **Fold lightweight checks**: Combine sub-second checks (lint, format check, spellcheck) into a single aggregator job that runs in parallel and lists every failure in one report.

#### 4. Toolchain Acceleration (JS/TS Reference Stack)
- **Package manager & runtime**: Use `bun`. Eliminate redundant wrappers.
- **Lint (< 1 second)**: Use `bun lint` with `.oxlintrc.json`. Maximize enabled rules.
- **Format (< 1 second)**: Use `bun fmt` / `oxfmt` for formatting verification.
- **Typecheck (< 5 seconds)**: Run `bun check` on TypeScript.
- **Tests (< 30 seconds per shard)**:
  - Migrate execution to `bun test` while retaining existing `vitest` imports where compatible.
  - Isolate modules, not processes; reset state between test files; run in randomized order to detect leaked state.

#### 5. Sharding and Recorded-Time Balancing
- **Scale cores before shards**: Maximize CPU utilization per runner before spinning up additional virtual machines. Match test workers directly to available core count.
- **Throwaway database per shard**: When integration tests require databases, provision isolated ephemeral databases per shard worker.
- **Split oversized test files**: Any individual test file exceeding `20 seconds` execution time must be split into smaller test units.
- **Greedy bin-packing with `TimeSequencer`**:
  - Distribute test files using historical execution metrics from `timings.json` (see `templates/time-sequencer.ts`).
  - Sort test suites `longestFirst` and assign each suite to the shard with the lowest cumulative load.
  - Smooth noisy test timings over runs using an exponential moving average: `timings[file] = (old + current) / 2`.
  - Validate that the union of all executed shards ran 100% of discovered test files.

#### 6. PR Test Selection and Falsification
- **Diff-based selection on PRs**: Run only test suites directly covering modified files and reverse dependencies.
- **Fail-safe full run triggers**: Run the full suite if changes touch:
  - Package manifests / lockfiles (`package.json`, `bun.lockb`, `bun.lock`)
  - Shared core libraries, utility roots, or ORM/database schemas
  - CI workflows (`.github/workflows/**`)
  - Root configuration files (`tsconfig.json`, build configs)
- **Intentional Defect Falsification**:
  Before approving a test-selection mechanism, verify safety:
  1. Hide a deliberate defect / breaking change inside a covered file.
  2. Run the selective PR pipeline.
  3. Confirm that CI turns RED.
  4. Revert the defect.

#### 7. Test Pruning on Evidence
- Monitor test failures across runs for two weeks.
- Classify failures as either:
  - **Caught regression**: True behavioral defect caught by the test.
  - **Change detector**: Brittle snapshot or implementation-detail test that broke only because code structure shifted.
- Safely delete tests that only act as change detectors; document and ban their patterns in `AGENTS.md`.
- **Protected tests sentinels**: NEVER delete tests covering authorization, authentication, privacy, data migrations, or concurrency/race conditions.

#### 8. Local Feedback Budget (< 9 seconds)
- Install zero-overhead git hooks using `hk` or `lefthook`:
  - **pre-commit (< 1s)**: Format and lint staged files only (`bun fmt`, `bun lint --staged`).
  - **pre-push (< 9s)**: Run the identical fast check suite executed in PR CI.
  - Always enforce via executable git hooks rather than documentation guidelines, ensuring AI agents and developers execute checks reliably.

#### 9. Budget Enforcement Guardrails
- Keep CI fast by failing any job that exceeds its budget.
- Set strict `timeout-minutes` on GitHub Actions jobs (e.g. `timeout-minutes: 2`).

---

## Execution Rules for Agents

1. **One small PR per change**:
   Deliver each optimization as an isolated pull request (e.g. PR 1: Concurrency cancellation and blobless clone; PR 2: Caching and node_modules; PR 3: Parallel job folding; PR 4: Test sharding).
2. **Dual-run verification**:
   Before replacing an established tool (e.g. ESLint -> `bun lint` or Vitest -> `bun test`), run the legacy and accelerated tools side-by-side on the same commit to verify zero loss of coverage or missed diagnostics.
3. **Transparent Reporting**:
   Conclude every optimization with a before-and-after metrics table:
   - Median and p95 waiting latency
   - Median and p95 total PR turnaround time
   - Total CI compute cost and minutes saved per week
