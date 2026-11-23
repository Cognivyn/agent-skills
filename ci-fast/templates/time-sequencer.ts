/**
 * time-sequencer.ts
 *
 * Recorded-time test sharder and balancer.
 *
 * Integrates into Vitest (or Bun test runners) by dynamically distributing test files
 * across shards using historical execution duration recorded in `timings.json`.
 * Uses greedy bin-packing (longestFirst -> lightest shard) to guarantee balanced shard durations.
 *
 * Usage in vitest.config.ts:
 *   import { defineConfig } from "vitest/config";
 *   import { TimeSequencer } from "./time-sequencer";
 *
 *   export default defineConfig({
 *     test: {
 *       sequence: { sequencer: TimeSequencer },
 *     },
 *   });
 */

import { readFileSync, writeFileSync, statSync, existsSync } from "fs";
import { relative } from "path";
import glob from "fast-glob";

// BaseSequencer interface definition compatible with Vitest
let BaseSequencerClass: any;
try {
  // @ts-ignore
  const vitest = await import("vitest/sequencer");
  BaseSequencerClass = vitest.BaseSequencer || vitest.default;
} catch {
  // Fallback stub if vitest is not installed in the current environment
  BaseSequencerClass = class {
    ctx: any;
    constructor(ctx: any) {
      this.ctx = ctx;
    }
    async shard(specs: any[]) {
      return specs;
    }
    async sort(specs: any[]) {
      return specs;
    }
  };
}

const timingsFile = "timings.json";
const timings: Record<string, number> = existsSync(timingsFile)
  ? JSON.parse(readFileSync(timingsFile, "utf8"))
  : {};

const key = (path: string): string =>
  relative(process.cwd(), path).replace(/\\/g, "/");

// Fallback estimation based on file size if no historical execution time exists
const guess = (path: string): number => {
  try {
    return statSync(path).size * 0.05;
  } catch {
    return 100;
  }
};

const weigh = (spec: { moduleId: string }): number =>
  timings[key(spec.moduleId)] ?? guess(spec.moduleId);

const longestFirst = (specs: any[]): any[] =>
  [...specs].sort(
    (a, b) => weigh(b) - weigh(a) || a.moduleId.localeCompare(b.moduleId)
  );

export class TimeSequencer extends BaseSequencerClass {
  async shard(specs: any[]): Promise<any[]> {
    const shardConfig = this.ctx?.config?.shard;
    if (!shardConfig) return specs;

    const { index, count } = shardConfig;
    const loads = Array(count).fill(0);
    const mine: any[] = [];

    // Greedy bin-packing: assign longest spec to the currently lightest shard
    for (const spec of longestFirst(specs)) {
      const lightest = loads.indexOf(Math.min(...loads));
      loads[lightest] += weigh(spec);
      if (lightest === index - 1) {
        mine.push(spec);
      }
    }

    return mine;
  }

  async sort(specs: any[]): Promise<any[]> {
    return longestFirst(specs);
  }
}

/**
 * Recalibrate and smooth timings across shard runs.
 * Call this post-test in CI:
 *   bun agent-skills/ci-fast/templates/time-sequencer.ts --update-timings
 */
export async function updateRecordedTimings(reportPattern = "shard-*.json") {
  const reports = glob.sync(reportPattern);
  if (reports.length === 0) {
    console.log(`No test report files matching ${reportPattern} found.`);
    return;
  }

  const total = (fileResult: any): number =>
    fileResult.assertionResults?.reduce(
      (ms: number, t: any) => ms + (t.duration ?? 0),
      0
    ) ?? 0;

  for (const report of reports) {
    try {
      const parsed = JSON.parse(readFileSync(report, "utf8"));
      const testResults = parsed.testResults || [];
      for (const file of testResults) {
        const name = key(file.name);
        const recorded = total(file);
        const old = timings[name];
        // Exponential moving average to smooth out environment noise
        timings[name] = old ? Math.round((old + recorded) / 2) : recorded;
      }
    } catch (err) {
      console.warn(`Failed to process shard report: ${report}`, err);
    }
  }

  writeFileSync(timingsFile, JSON.stringify(timings, null, 2) + "\n");
  console.log(`✅ Updated ${timingsFile} with smoothed execution metrics.`);
}

if (import.meta.main && process.argv.includes("--update-timings")) {
  await updateRecordedTimings();
}
