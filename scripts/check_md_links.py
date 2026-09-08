#!/usr/bin/env python3
"""Check local Markdown links and anchors across the repository."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def slugify(heading: str) -> str:
    """Convert heading text to Markdown anchor slug."""
    # Remove inline code ticks or markdown formatting inside heading if needed
    cleaned = re.sub(r"`([^`]+)`", r"\1", heading)
    cleaned = re.sub(r"[^\w\s-]", "", cleaned.lower())
    slug = re.sub(r"[\s_]+", "-", cleaned.strip())
    return slug


def extract_headings(text: str) -> set[str]:
    """Extract heading slugs from markdown content."""
    slugs = set()
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("#"):
            heading_text = line.lstrip("#").strip()
            if heading_text:
                slugs.add(slugify(heading_text))
    return slugs


def check_markdown_links(repo_root: Path) -> list[str]:
    errors = []
    md_files = [p for p in repo_root.rglob("*.md") if not any(part.startswith(".") for part in p.parts)]

    # Pre-parse all headings per file
    file_headings: dict[Path, set[str]] = {}
    for md_file in md_files:
        try:
            content = md_file.read_text(encoding="utf-8")
            file_headings[md_file.resolve()] = extract_headings(content)
        except OSError as exc:
            errors.append(f"Cannot read {md_file}: {exc}")

    # Link regex: [label](path)
    link_pattern = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")

    for md_file in md_files:
        try:
            content = md_file.read_text(encoding="utf-8")
        except OSError:
            continue

        for match in link_pattern.finditer(content):
            target = match.group(2).strip()

            # Ignore remote URLs, mailto, etc.
            if target.startswith(("http://", "https://", "mailto:", "ftp://")):
                continue

            # Split path and anchor
            if "#" in target:
                path_part, anchor_part = target.split("#", 1)
            else:
                path_part, anchor_part = target, None

            # Resolve target file
            if not path_part:
                target_file = md_file.resolve()
            else:
                target_file = (md_file.parent / path_part).resolve()

            # Verify target file exists
            if not target_file.exists():
                rel_file = md_file.relative_to(repo_root)
                errors.append(f"{rel_file}: broken link '{target}' -> file not found: {target_file}")
                continue

            # Verify anchor if specified and target is a .md file
            if anchor_part and target_file.suffix.lower() == ".md":
                headings = file_headings.get(target_file, set())
                expected_slug = slugify(anchor_part)
                if expected_slug not in headings:
                    rel_file = md_file.relative_to(repo_root)
                    rel_target = target_file.relative_to(repo_root) if repo_root in target_file.parents else target_file
                    errors.append(f"{rel_file}: broken anchor '#{anchor_part}' in '{rel_target}' (available slugs: {sorted(headings)})")

    return errors


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    errors = check_markdown_links(repo_root)
    if errors:
        print("Markdown link validation errors:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    print("All Markdown links and anchors are valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
