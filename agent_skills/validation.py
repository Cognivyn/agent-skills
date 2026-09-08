"""Read-only validation for repository skills."""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

from .workspace import SKILL_FILE, SKILL_NAME_RE, WorkspaceError, available_skills, skill_path


@dataclass(frozen=True)
class ValidationReport:
    name: str
    errors: tuple[str, ...]

    @property
    def valid(self) -> bool:
        return not self.errors


def _frontmatter(text: str) -> tuple[str, str] | None:
    if not text.startswith("---\n"):
        return None
    match = re.search(r"\n---\s*(?:\n|$)", text[4:])
    if not match:
        return None
    end = 4 + match.start()
    return text[4:end], text[4 + match.end():]


def _field(frontmatter: str, field: str) -> str | None:
    match = re.search(rf"^{re.escape(field)}:\s*(.*)$", frontmatter, re.MULTILINE)
    if not match:
        return None
    value = match.group(1).strip().strip('"\'')
    if value in {"", ">-", ">", "|"}:
        continuation = []
        remainder = frontmatter[match.end():].lstrip("\r\n")
        for line in remainder.splitlines():
            if line.startswith(" ") or line.startswith("\t"):
                continuation.append(line.strip())
            else:
                break
        value = " ".join(continuation).strip()
    return value or None


def _dependencies(frontmatter: str) -> tuple[list[str], list[str]]:
    """Read metadata.dependencies from the intentionally small supported YAML subset."""
    lines = frontmatter.splitlines()
    in_metadata = False
    dependencies: list[str] = []
    errors: list[str] = []
    for index, line in enumerate(lines):
        stripped = line.strip()
        if stripped == "metadata:":
            in_metadata = True
            continue
        if in_metadata and stripped and not line.startswith((" ", "\t")):
            in_metadata = False
        if not in_metadata or not stripped.startswith("dependencies:"):
            continue
        value = stripped.split(":", 1)[1].strip()
        if value.startswith("[") and value.endswith("]"):
            raw = value[1:-1].strip()
            dependencies = [item.strip().strip('"\'') for item in raw.split(",") if item.strip()]
        elif value:
            errors.append("metadata.dependencies must be a YAML list")
        else:
            for item in lines[index + 1:]:
                item_stripped = item.strip()
                if not item_stripped:
                    continue
                if item_stripped.startswith("-"):
                    dependencies.append(item_stripped[1:].strip().strip('"\''))
                else:
                    break
    return dependencies, errors


def validate_skill_report(repository: Path, name: str) -> ValidationReport:
    errors: list[str] = []
    if not SKILL_NAME_RE.fullmatch(name):
        return ValidationReport(name, ("invalid skill name",))
    path = skill_path(repository, name)
    skill_file = path / SKILL_FILE
    if not path.is_dir():
        return ValidationReport(name, ("skill directory not found",))
    if not skill_file.is_file():
        return ValidationReport(name, ("SKILL.md not found",))
    try:
        text = skill_file.read_text(encoding="utf-8")
    except OSError as exc:
        return ValidationReport(name, (f"cannot read SKILL.md: {exc}",))
    parsed = _frontmatter(text)
    if parsed is None:
        return ValidationReport(name, ("missing or unterminated YAML frontmatter",))
    frontmatter, _body = parsed
    declared_name = _field(frontmatter, "name")
    description = _field(frontmatter, "description")
    if not declared_name:
        errors.append("frontmatter is missing name")
    elif declared_name != name:
        errors.append(f"frontmatter name is {declared_name!r}, expected {name!r}")
    if not description:
        errors.append("frontmatter is missing description")
    dependencies, dependency_errors = _dependencies(frontmatter)
    errors.extend(dependency_errors)
    known = set(available_skills(repository))
    for dependency in dependencies:
        if not SKILL_NAME_RE.fullmatch(dependency):
            errors.append(f"invalid dependency name: {dependency!r}")
        elif dependency == name:
            errors.append("skill cannot depend on itself")
        elif dependency not in known:
            errors.append(f"missing dependency: {dependency}")
    return ValidationReport(name, tuple(errors))


def dependency_names(repository: Path, name: str) -> list[str]:
    """Return syntactically readable dependencies for graph validation."""
    skill_file = skill_path(repository, name) / SKILL_FILE
    if not skill_file.is_file():
        return []
    parsed = _frontmatter(skill_file.read_text(encoding="utf-8"))
    if parsed is None:
        return []
    dependencies, _errors = _dependencies(parsed[0])
    return [item for item in dependencies if SKILL_NAME_RE.fullmatch(item)]


def _cycles(repository: Path, names: list[str]) -> dict[str, str]:
    graph = {
        name: [item for item in dependency_names(repository, name) if item in names and item != name]
        for name in names
    }
    found: dict[str, str] = {}
    visiting: list[str] = []
    visited: set[str] = set()

    def visit(name: str) -> None:
        if name in visiting:
            start = visiting.index(name)
            cycle = visiting[start:] + [name]
            message = "circular dependency: " + " -> ".join(cycle)
            for member in cycle[:-1]:
                found[member] = message
            return
        if name in visited:
            return
        visiting.append(name)
        for dependency in graph.get(name, []):
            visit(dependency)
        visiting.pop()
        visited.add(name)

    for name in names:
        if name not in visited:
            visit(name)
    return found


def validate_skills(repository: Path, names: list[str] | None = None) -> list[ValidationReport]:
    selected = names if names else available_skills(repository)
    if not selected:
        raise WorkspaceError("no skills found")
    reports = []
    cycles = _cycles(repository, available_skills(repository))
    for name in selected:
        report = validate_skill_report(repository, name)
        cycle = cycles.get(name)
        if cycle and cycle not in report.errors:
            report = ValidationReport(report.name, (*report.errors, cycle))
        reports.append(report)
    return reports
