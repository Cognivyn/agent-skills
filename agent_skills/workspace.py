"""Filesystem operations for the agent-skills CLI."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any

CONFIG_DIR = ".agent-skills"
CONFIG_FILE = "config.json"
MANIFEST_FILE = "manifest.json"
SKILL_FILE = "SKILL.md"
SKILL_NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


class WorkspaceError(RuntimeError):
    """Raised for expected workspace or skill errors."""


@dataclass(frozen=True)
class Workspace:
    repository: Path
    config_dir: Path
    skills_dir: Path
    manifest_path: Path


def repository_root(start: Path | None = None) -> Path:
    current = (start or Path.cwd()).resolve()
    for candidate in (current, *current.parents):
        if (candidate / ".git").exists() and (candidate / "README.md").exists():
            return candidate
    raise WorkspaceError("could not find the agent-skills repository from the current directory")


def _read_json(path: Path, default: dict[str, Any]) -> dict[str, Any]:
    if not path.exists():
        return default.copy()
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise WorkspaceError(f"invalid JSON state file: {path}") from exc
    if not isinstance(value, dict):
        raise WorkspaceError(f"state file must contain a JSON object: {path}")
    return value


def _write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def load_workspace(repository: Path, initialized: bool = True) -> Workspace:
    config_dir = repository / CONFIG_DIR
    config_path = config_dir / CONFIG_FILE
    if initialized and not config_path.exists():
        raise WorkspaceError("workspace is not initialized; run `agent-skills init` first")
    config = _read_json(config_path, {})
    configured = config.get("skills_dir")
    skills_dir = Path(configured).expanduser() if configured else Path.home() / ".agents" / "skills"
    if not skills_dir.is_absolute():
        skills_dir = (repository / skills_dir).resolve()
    return Workspace(repository, config_dir, skills_dir, config_dir / MANIFEST_FILE)


def init_workspace(repository: Path, skills_dir: Path | None = None) -> tuple[Workspace, bool]:
    config_dir = repository / CONFIG_DIR
    config_path = config_dir / CONFIG_FILE
    selected = (skills_dir or (Path.home() / ".agents" / "skills")).expanduser().resolve()
    existing = config_path.exists()
    if existing:
        workspace = load_workspace(repository)
        if skills_dir is not None and workspace.skills_dir != selected:
            raise WorkspaceError(f"workspace already points to {workspace.skills_dir}; use that path or edit config deliberately")
    else:
        config_dir.mkdir(parents=True, exist_ok=True)
        _write_json(config_path, {"skills_dir": str(selected), "version": 1})
        workspace = load_workspace(repository)
    workspace.skills_dir.mkdir(parents=True, exist_ok=True)
    if not workspace.manifest_path.exists():
        _write_json(workspace.manifest_path, {"version": 1, "skills": []})
    return workspace, not existing


def validate_skill_name(name: str) -> None:
    if not SKILL_NAME_RE.fullmatch(name):
        raise WorkspaceError("skill name must use lowercase letters, numbers, and single hyphens")


def skill_path(repository: Path, name: str) -> Path:
    validate_skill_name(name)
    return repository / name


def validate_skill(path: Path) -> None:
    skill_file = path / SKILL_FILE
    if not path.is_dir() or not skill_file.is_file():
        raise WorkspaceError(f"{path} is not a valid skill directory with {SKILL_FILE}")
    text = skill_file.read_text(encoding="utf-8")
    if not text.startswith("---\n") or "\nname:" not in text or "\ndescription:" not in text:
        raise WorkspaceError(f"{skill_file} must contain YAML frontmatter with name and description")


def available_skills(repository: Path) -> list[str]:
    result = []
    for child in repository.iterdir():
        if child.is_dir() and not child.name.startswith(".") and child.name not in {"docs", "tests", "agent_skills"}:
            if (child / SKILL_FILE).is_file():
                result.append(child.name)
    return sorted(result)


def manifest_skills(workspace: Workspace) -> list[str]:
    value = _read_json(workspace.manifest_path, {"skills": []})
    skills = value.get("skills", [])
    if not isinstance(skills, list) or not all(isinstance(item, str) for item in skills):
        raise WorkspaceError("manifest skills must be a list of names")
    return sorted(set(skills))


def _save_manifest(workspace: Workspace, skills: list[str]) -> None:
    _write_json(workspace.manifest_path, {"version": 1, "skills": sorted(set(skills))})


def add_skill(workspace: Workspace, name: str, link: bool = False) -> str:
    source = skill_path(workspace.repository, name)
    validate_skill(source)
    current = manifest_skills(workspace)
    destination = workspace.skills_dir / name
    if name in current and destination.exists():
        return "already added"
    if destination.exists() or destination.is_symlink():
        raise WorkspaceError(f"destination already exists: {destination}")
    workspace.skills_dir.mkdir(parents=True, exist_ok=True)
    if link:
        try:
            destination.symlink_to(source, target_is_directory=True)
        except OSError as exc:
            raise WorkspaceError(f"could not create link at {destination}: {exc}") from exc
    else:
        shutil.copytree(source, destination)
    _save_manifest(workspace, [*current, name])
    return "added"


def remove_skill(workspace: Workspace, name: str, force: bool = False) -> str:
    validate_skill_name(name)
    current = manifest_skills(workspace)
    destination = workspace.skills_dir / name
    if name not in current:
        return "not added"
    if destination.is_dir() and not destination.is_symlink() and not force:
        source = skill_path(workspace.repository, name)
        source_files = {p.relative_to(source) for p in source.rglob("*") if p.is_file()}
        destination_files = {p.relative_to(destination) for p in destination.rglob("*") if p.is_file()}
        if destination_files != source_files:
            raise WorkspaceError(f"refusing to remove locally modified skill: {name}; use --force")
    if destination.is_symlink() or destination.is_file():
        destination.unlink()
    elif destination.is_dir():
        shutil.rmtree(destination)
    _save_manifest(workspace, [item for item in current if item != name])
    return "removed"


def create_skill(repository: Path, name: str, destination: Path | None = None) -> Path:
    validate_skill_name(name)
    root = (destination or repository).resolve()
    path = root / name
    if path.exists():
        raise WorkspaceError(f"skill already exists: {path}")
    path.mkdir(parents=True)
    (path / SKILL_FILE).write_text(
        f"---\nname: {name}\ndescription: >-\n  Describe when this skill should be used.\n---\n\n# {name}\n\nDescribe the workflow, safety rules, and validation steps for this skill.\n",
        encoding="utf-8",
    )
    if destination is None:
        docs_path = repository / "docs" / name / "README.md"
        docs_path.parent.mkdir(parents=True, exist_ok=True)
        docs_path.write_text(f"# {name}\n\nDocument how to use the `{name}` skill.\n", encoding="utf-8")
    return path


def list_skills(workspace: Workspace) -> list[tuple[str, str]]:
    added = set(manifest_skills(workspace))
    return [(name, "added" if name in added else "available") for name in available_skills(workspace.repository)]


def remote_skills(repository: Path, remote: str = "origin", branch: str = "main") -> list[str]:
    """List top-level skills from a remote-tracking branch without fetching."""
    try:
        result = subprocess.run(
            ["git", "ls-tree", "-d", "--name-only", f"{remote}/{branch}"],
            cwd=repository,
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return []
    if result.returncode != 0:
        return []
    excluded = {"docs", "tests", "agent_skills"}
    names = []
    for line in result.stdout.splitlines():
        name = line.strip()
        if name and not name.startswith(".") and name not in excluded and SKILL_NAME_RE.fullmatch(name):
            names.append(name)
    return sorted(names)


def list_skill_sources(workspace: Workspace) -> tuple[list[tuple[str, str]], list[str]]:
    """Return local status rows and skills visible on origin/main."""
    return list_skills(workspace), remote_skills(workspace.repository)
