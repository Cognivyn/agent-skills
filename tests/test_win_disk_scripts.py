"""Static regression guards for the win-disk-diagnostics PowerShell sources.

These assertions read the ``.ps1`` files as text. That is deliberate: the
defects they cover are all statically decidable, and a PowerShell test runner
is not a dependency this repository carries (the locally available Pester is
3.4.0, far older than the tests require).

If a check here ever needs to execute the scripts instead, that is a signal the
repository should gain a real PowerShell harness rather than that these checks
should grow clever.
"""

from __future__ import annotations

import unittest
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent / "win-disk-diagnostics"
SCRIPTS = SKILL_DIR / "scripts"
SRC = SCRIPTS / "src"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


class DeleteGuardTest(unittest.TestCase):
    """Every deletion must be gated by ShouldProcess, never a bare Remove-Item."""

    def setUp(self) -> None:
        self.text = _read(SCRIPTS / "Clean-NodeModules.ps1")

    def test_declares_supports_should_process(self) -> None:
        self.assertIn("SupportsShouldProcess = $true", self.text)

    def test_calls_should_process(self) -> None:
        self.assertIn(
            "$PSCmdlet.ShouldProcess(",
            self.text,
            "Clean-NodeModules.ps1 deletes files but never consults ShouldProcess, "
            "so -WhatIf silently performs real deletions",
        )

    def test_deletion_is_not_unguarded(self) -> None:
        delete_line = next(
            line for line in self.text.splitlines() if "Remove-Item -LiteralPath $targetLiteral" in line
        )
        should_process = self.text.index("$PSCmdlet.ShouldProcess(")
        delete_at = self.text.index(delete_line)
        self.assertLess(
            should_process,
            delete_at,
            "Remove-Item must be reached only after a ShouldProcess decision",
        )

    def test_confirm_impact_not_raised_to_high(self) -> None:
        # ConfirmImpact High makes ShouldProcess raise its own prompt, which
        # throws NullReferenceException under `powershell -File` with no host
        # UI, and double-prompts under -Force. Only executable code counts: the
        # rationale for leaving it alone is documented in a comment block.
        code = [
            line for line in self.text.splitlines()
            if not line.strip().startswith("#")
        ]
        self.assertFalse(
            [line for line in code if "ConfirmImpact" in line],
            "ConfirmImpact must stay at its default; see the comment above [CmdletBinding]",
        )

    def test_force_still_gated(self) -> None:
        # -Force skips the interactive prompt but must not bypass ShouldProcess.
        force_index = self.text.index("if ($Force) {")
        should_process = self.text.index("$PSCmdlet.ShouldProcess(")
        self.assertLess(force_index, should_process)


class HardcodedPathTest(unittest.TestCase):
    """A machine-specific path must never ship in a distributed skill."""

    def test_no_personal_workspace_path(self) -> None:
        for path in sorted(SCRIPTS.rglob("*.ps1")):
            text = _read(path)
            self.assertNotIn(
                "Z:\\WSL",
                text,
                f"{path.name} hardcodes a personal workspace path",
            )

    def test_no_personal_path_in_skill_md(self) -> None:
        self.assertNotIn("Z:\\WSL", _read(SKILL_DIR / "SKILL.md"))

    def test_path_parameter_defaults_to_cwd(self) -> None:
        text = _read(SCRIPTS / "Clean-NodeModules.ps1")
        self.assertIn("[string]$Path = '.'", text)


class PrivacyScrubbingTest(unittest.TestCase):
    """SKILL.md promises path scrubbing; the code must actually do it."""

    def test_scrubber_exists(self) -> None:
        text = _read(SRC / "Formatters.ps1")
        self.assertIn("function Protect-SensitivePath", text)

    def test_collectors_scrub_before_returning(self) -> None:
        text = _read(SRC / "Collectors.ps1")
        self.assertIn("Protect-SensitivePath -Path $f.FullName", text)
        self.assertIn("Protect-SensitivePath -Path $dir.FullName", text)

    def test_node_modules_scrubber_present(self) -> None:
        text = _read(SCRIPTS / "Clean-NodeModules.ps1")
        self.assertIn("function Protect-SensitivePath", text)

    def test_hostname_not_rendered(self) -> None:
        # The banner echoed $env:COMPUTERNAME verbatim, identifying the machine.
        # Only the guard expression may read it; nothing may interpolate it into
        # a rendered line.
        text = _read(SRC / "TerminalUI.ps1")
        code = [line for line in text.splitlines() if not line.strip().startswith("#")]
        for line in code:
            self.assertNotIn(
                "$env:COMPUTERNAME",
                line,
                f"banner reads the computer name directly: {line.strip()}",
            )


class TraversalSafetyTest(unittest.TestCase):
    """Traversal must be depth-bounded and must skip reparse points."""

    def setUp(self) -> None:
        self.text = _read(SRC / "Collectors.ps1")

    def test_max_depth_is_bounded(self) -> None:
        self.assertIn("[int]$MaxDepth = 4", self.text)

    def test_depth_is_enforced_in_walk(self) -> None:
        self.assertIn("if ($current.Depth -lt $MaxDepth)", self.text)

    def test_skips_reparse_points(self) -> None:
        self.assertIn("function Test-IsReparsePoint", self.text)
        self.assertIn("if (Test-IsReparsePoint -Path $dir)", self.text)

    def test_excludes_cloud_sync_roots(self) -> None:
        for name in ("OneDrive", "iCloudDrive", "Dropbox"):
            self.assertIn(f"'{name}'", self.text)

    def test_node_modules_scan_skips_reparse_points(self) -> None:
        text = _read(SCRIPTS / "Clean-NodeModules.ps1")
        self.assertIn("[System.IO.FileAttributes]::ReparsePoint", text)

    def test_no_unbounded_recursive_walk(self) -> None:
        # Get-ChildItem -Recurse without a -Depth bound is the original defect:
        # it follows junctions and cloud placeholders. Prose inside comment and
        # doc blocks is excluded so the check only sees executable lines.
        in_block_comment = False
        for number, line in enumerate(self.text.splitlines(), start=1):
            stripped = line.strip()
            if stripped.startswith("<#"):
                in_block_comment = True
            if in_block_comment:
                if stripped.endswith("#>"):
                    in_block_comment = False
                continue
            if stripped.startswith("#"):
                continue
            if "Get-ChildItem" in stripped and "-Recurse" in stripped:
                self.assertIn(
                    "-Depth",
                    stripped,
                    f"line {number}: unbounded recursive walk: {stripped}",
                )


class BoundedMemoryTest(unittest.TestCase):
    """Top-N must not materialize every file on the volume before sorting."""

    def test_files_collector_keeps_bounded_list(self) -> None:
        text = _read(SRC / "Collectors.ps1")
        heaviest_files = text[text.index("function Get-HeaviestFiles"):text.index("function Get-HeaviestFolders")]
        self.assertNotIn(
            "| Sort-Object Length -Descending",
            heaviest_files,
            "Get-HeaviestFiles must not sort the full file list; keep a bounded top-N",
        )
        self.assertIn("$kept.Count -lt $Count", heaviest_files)


class MachineReadableOutputTest(unittest.TestCase):
    """Sub-agents need JSON on stdout, not ANSI tables."""

    def setUp(self) -> None:
        self.text = _read(SCRIPTS / "Analyze-DiskSpace.ps1")

    def test_json_switch_exists(self) -> None:
        self.assertIn("[switch]$Json", self.text)

    def test_json_suppresses_tables(self) -> None:
        self.assertIn("if ($Json) { $Quiet = $true }", self.text)

    def test_drive_alone_resolves_to_summary_set(self) -> None:
        # Regression: -Drive C: previously landed in an AnalyzeDrive set with no
        # dispatch branch and silently reported every volume.
        summary_drive = "[Parameter(ParameterSetName = 'Summary')]\n    [Parameter(ParameterSetName = 'Files')]\n    [Parameter(ParameterSetName = 'Folders')]\n    [ValidatePattern('^[a-zA-Z]:?$')]\n    [string]$Drive"
        self.assertIn(summary_drive, self.text)
        self.assertNotIn("AnalyzeDrive", self.text)

    def test_json_is_emitted_for_every_mode(self) -> None:
        self.assertGreaterEqual(self.text.count("ConvertTo-DiagnosticJson -Data"), 3)


class EncodingTest(unittest.TestCase):
    """A UTF-16 file is a binary blob to git: no diffs, no review, no grep."""

    def test_scripts_are_not_utf16(self) -> None:
        for path in sorted(SCRIPTS.rglob("*.ps1")):
            raw = path.read_bytes()
            with self.subTest(script=path.name):
                self.assertFalse(
                    raw.startswith(b"\xff\xfe") or raw.startswith(b"\xfe\xff"),
                    f"{path.name} is UTF-16; git will treat it as binary",
                )

    def test_box_drawing_characters_survive(self) -> None:
        text = _read(SRC / "TerminalUI.ps1")
        self.assertIn("\u2500", text)
        self.assertNotIn("\ufffd", text, "decoding produced replacement characters")


class StaleDocumentationTest(unittest.TestCase):
    """The guide referenced a `bun run` engine that does not exist here."""

    def setUp(self) -> None:
        self.text = _read(SKILL_DIR / "references" / "winspace-lens-guide.md")

    def test_no_bun_run_invocations(self) -> None:
        code_lines = [
            line for line in self.text.splitlines()
            if line.strip().startswith("bun run")
        ]
        self.assertEqual(
            code_lines,
            [],
            "guide still instructs running a bun engine absent from this repository",
        )

    def test_scope_note_present(self) -> None:
        self.assertIn("not part of this skill", self.text.lower())

    def test_runbook_paths_are_repo_relative(self) -> None:
        skill = _read(SKILL_DIR / "SKILL.md")
        self.assertIn("./win-disk-diagnostics/scripts/Analyze-DiskSpace.ps1", skill)
        self.assertNotIn(r"-File .\scripts\Analyze-DiskSpace.ps1", skill)

    def test_stale_threshold_is_interpolated(self) -> None:
        text = _read(SCRIPTS / "Clean-NodeModules.ps1")
        # Hardcoded "2d" labels contradicted -DaysOlderThan.
        self.assertIn('$statusEligible = "ELIGIBLE (> $DaysOlderThan d)"', text)
        self.assertNotIn('"ELIGIBLE (> 2d)"', text)


if __name__ == "__main__":
    unittest.main()
