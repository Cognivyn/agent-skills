"""Command-line interface for managing Cognivyn agent skills."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .validation import validate_skills
from .workspace import (
    WorkspaceError,
    add_skill,
    create_skill,
    init_workspace,
    list_skill_sources,
    load_workspace,
    remove_skill,
    repository_root,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="agent-skills", description="Manage skills in a Cognivyn agent-skills workspace.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    init = subparsers.add_parser("init", help="initialize a local skills workspace")
    init.add_argument("--skills-dir", type=Path, help="directory where added skills are stored")

    create = subparsers.add_parser("create", help="create a new skill scaffold")
    create.add_argument("name")
    create.add_argument("--directory", type=Path, help="directory in which to create the skill")

    subparsers.add_parser("list", help="list available and added skills")

    validate = subparsers.add_parser("validate", help="validate skill frontmatter and dependencies")
    validate.add_argument("names", nargs="*", help="skill names; validate all when omitted")

    add = subparsers.add_parser("add", help="add one or more skills to the workspace")
    add.add_argument("names", nargs="+")
    add.add_argument("--link", action="store_true", help="link skills instead of copying them")

    remove = subparsers.add_parser("remove", help="remove one or more added skills")
    remove.add_argument("names", nargs="+")
    remove.add_argument("--force", action="store_true", help="remove locally modified skill files")
    return parser


def run(args: argparse.Namespace) -> int:
    repository = repository_root()
    if args.command == "init":
        workspace, created = init_workspace(repository, args.skills_dir)
        state = "initialized" if created else "already initialized"
        print(f"{state}: {workspace.skills_dir}")
        return 0
    if args.command == "create":
        path = create_skill(repository, args.name, args.directory)
        print(f"created skill: {path}")
        return 0
    if args.command == "list":
        workspace = load_workspace(repository, initialized=False)
        local_rows, remote_rows = list_skill_sources(workspace)
        if not local_rows and not remote_rows:
            print("no skills found")
            return 0
        print("local:")
        if local_rows:
            for name, state in local_rows:
                print(f"  {name}\t{state}")
        else:
            print("  none")
        print("remote (origin/main):")
        if remote_rows:
            for name in remote_rows:
                print(f"  {name}")
        else:
            print("  unavailable or empty")
        return 0
    if args.command == "validate":
        reports = validate_skills(repository, args.names)
        failed = False
        for report in reports:
            if report.valid:
                print(f"{report.name}: valid")
            else:
                failed = True
                for error in report.errors:
                    print(f"{report.name}: error: {error}", file=sys.stderr)
        return 1 if failed else 0
    workspace = load_workspace(repository)
    if args.command == "add":
        for name in args.names:
            print(f"{name}: {add_skill(workspace, name, args.link)}")
        return 0
    if args.command == "remove":
        for name in args.names:
            print(f"{name}: {remove_skill(workspace, name, args.force)}")
        return 0
    raise WorkspaceError(f"unknown command: {args.command}")


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    try:
        return run(parser.parse_args(argv))
    except WorkspaceError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
