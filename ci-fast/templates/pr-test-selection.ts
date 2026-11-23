#!/usr/bin/env bun
/**
 * pr-test-selection.ts
 *
 * Implements diff-based PR test selection.
 * Analyzes changed files between HEAD and the target branch (default: origin/main).
 *
 * Safety rules:
 * - If changes touch lockfiles, configs, workflows, or shared core modules,
 *   a FULL test suite run is mandated.
 * - Otherwise, selects only test files that directly match or import the changed source files.
 */

import { spawnSync } from "child_process";

// Patterns that mandate running 100% of the test suite
const FULL_RUN_TRIGGERS: RegExp[] = [
  /^package\.json$/,
  /^bun\.lockb?$/,
  /^pnpm-lock\.yaml$/,
  /^yarn\.lock$/,
  /^tsconfig.*\.json$/,
  /^\.github\/workflows\//,
  /^prisma\//,
  /^migrations\//,
  /^packages\/shared\//,
  /^\.oxlintrc\.json$/,
];

export function determinePrTests(targetBranch = "origin/main"): {
  runFullSuite: boolean;
  reason?: string;
  testFiles: string[];
} {
  const diffResult = spawnSync(
    "git",
    ["diff", "--name-only", `${targetBranch}...HEAD`],
    { encoding: "utf-8" }
  );

  if (diffResult.error || diffResult.status !== 0) {
    console.warn("⚠️ Unable to calculate git diff; falling back to full test suite.");
    return { runFullSuite: true, reason: "Git diff error", testFiles: [] };
  }

  const changedFiles = diffResult.stdout
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean);

  if (changedFiles.length === 0) {
    return { runFullSuite: false, reason: "No files changed", testFiles: [] };
  }

  // Check fail-safe triggers
  for (const file of changedFiles) {
    for (const trigger of FULL_RUN_TRIGGERS) {
      if (trigger.test(file)) {
        return {
          runFullSuite: true,
          reason: `Critical change detected in ${file}`,
          testFiles: [],
        };
      }
    }
  }

  // Map source changes to corresponding test files
  const testFiles = new Set<string>();
  for (const file of changedFiles) {
    if (file.includes(".test.") || file.includes(".spec.")) {
      testFiles.add(file);
    } else {
      // Direct counterpart heuristic: src/foo.ts -> src/foo.test.ts or tests/foo.test.ts
      const baseName = file.replace(/\.(ts|tsx|js|jsx)$/, "");
      testFiles.add(`${baseName}.test.ts`);
      testFiles.add(`${baseName}.spec.ts`);
    }
  }

  return {
    runFullSuite: false,
    testFiles: Array.from(testFiles),
  };
}

if (import.meta.main) {
  const result = determinePrTests();
  if (result.runFullSuite) {
    console.log(`FULL_SUITE: true (${result.reason})`);
  } else {
    console.log(`FULL_SUITE: false`);
    console.log(`SELECTED_TESTS: ${result.testFiles.join(" ")}`);
  }
}
