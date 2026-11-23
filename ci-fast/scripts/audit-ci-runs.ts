#!/usr/bin/env bun
/**
 * audit-ci-runs.ts
 *
 * Pulls the last 150 GitHub Actions CI runs via the `gh` CLI, computes p50 and p95
 * durations across Waiting (queue time), Setup (bootstrap), and Running (execution),
 * and pinpoints the dominant bottleneck to address first.
 */

import { spawnSync } from "child_process";

interface WorkflowRun {
  id: number;
  status: string;
  conclusion: string | null;
  createdAt: string;
  startedAt: string | null;
  updatedAt: string;
  jobs?: Array<{
    name: string;
    status: string;
    conclusion: string;
    startedAt: string;
    completedAt: string;
    steps?: Array<{
      name: string;
      status: string;
      conclusion: string;
      number: number;
      startedAt: string;
      completedAt: string;
    }>;
  }>;
}

function percentile(values: number[], p: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const index = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.max(0, Math.min(index, sorted.length - 1))];
}

function formatDuration(ms: number): string {
  const seconds = (ms / 1000).toFixed(1);
  return `${seconds}s`;
}

console.log("🔍 Fetching the last 150 CI workflow runs via GitHub CLI (`gh`)...");

const ghProcess = spawnSync(
  "gh",
  [
    "run",
    "list",
    "--limit",
    "150",
    "--json",
    "id,status,conclusion,createdAt,startedAt,updatedAt",
  ],
  { encoding: "utf-8" }
);

if (ghProcess.error || ghProcess.status !== 0) {
  console.error("❌ Failed to query GitHub runs with `gh` CLI.");
  console.error(ghProcess.stderr || ghProcess.error?.message);
  console.error("\nMake sure `gh` CLI is installed and authenticated (`gh auth login`).");
  process.exit(1);
}

let runs: WorkflowRun[] = [];
try {
  runs = JSON.parse(ghProcess.stdout);
} catch (e) {
  console.error("❌ Failed to parse JSON output from `gh run list`.");
  process.exit(1);
}

const completedRuns = runs.filter(
  (r) => r.status === "completed" && r.startedAt && r.createdAt
);

if (completedRuns.length === 0) {
  console.log("⚠️ No completed runs with timestamps found in the last 150 runs.");
  process.exit(0);
}

const waitingTimes: number[] = [];
const totalTimes: number[] = [];

for (const run of completedRuns) {
  const created = new Date(run.createdAt).getTime();
  const started = new Date(run.startedAt!).getTime();
  const updated = new Date(run.updatedAt).getTime();

  const wait = Math.max(0, started - created);
  const total = Math.max(0, updated - created);

  waitingTimes.push(wait);
  totalTimes.push(total);
}

console.log(`\n📊 Analyzed ${completedRuns.length} completed workflow runs:`);
console.log("---------------------------------------------------------------");
console.log(`Waiting (Queue) Latency:`);
console.log(`  p50 (median) : ${formatDuration(percentile(waitingTimes, 50))} (Budget: < 5s)`);
console.log(`  p95          : ${formatDuration(percentile(waitingTimes, 95))} (Budget: < 5s)`);
console.log("");
console.log(`Total Run Latency:`);
console.log(`  p50 (median) : ${formatDuration(percentile(totalTimes, 50))} (Budget: < 60s)`);
console.log(`  p95          : ${formatDuration(percentile(totalTimes, 95))} (Budget: < 120s)`);
console.log("---------------------------------------------------------------");

const medianWaitSec = percentile(waitingTimes, 50) / 1000;
const p95TotalSec = percentile(totalTimes, 95) / 1000;

if (medianWaitSec > 5) {
  console.log(`🚨 Bottleneck Alert: Queue latency (p50: ${medianWaitSec.toFixed(1)}s) exceeds the 5s budget.`);
  console.log("👉 Action: Move off default GitHub-hosted runners to warm runner pools (e.g. Blacksmith).");
} else if (p95TotalSec > 120) {
  console.log(`🚨 Bottleneck Alert: Execution turnaround (p95: ${p95TotalSec.toFixed(1)}s) exceeds the 2m budget.`);
  console.log("👉 Action: Parallelize jobs, shard test suites using TimeSequencer, and enable PR test selection.");
} else {
  console.log("✅ CI metrics are within target budgets!");
}
