# GitHub Pages Plan for Cognivyn Agent Skills

## 1. Overview & Objective
This document outlines the design and architectural specification for the GitHub Pages landing page of **Cognivyn Agent Skills**.

The goal is to showcase Cognivyn's open-source agent skills repository with a high quality, modern, light-themed web interface that directly reflects Cognivyn's core brand identity as seen on [cognivyn.in](https://cognivyn.in).

---

## 2. Brand Identity & Visual System (Light Theme)
In alignment with `cognivyn.in` and avoiding dark themes, the design adopts a clean, technical light aesthetic inspired by structural engineering precision and modern AI software tooling.

### Color Palette
- **Background Main**: `#F8FAFC` (Slate 50)
- **Card / Container Background**: `#FFFFFF` (Pure White with crisp borders)
- **Text Primary**: `#0F172A` (Slate 900 - Deep, readable charcoal/black)
- **Text Muted / Secondary**: `#475569` (Slate 600)
- **Primary Accent**: `#2563EB` (Cognivyn Blue / Royal Indigo)
- **Secondary Accent / Highlight**: `#0284C7` (Sky Blue) & Amber/Gold subtle highlights (`#D97706`)
- **Border / Subtle Lines**: `#E2E8F0` (Slate 200) / `#CBD5E1` (Slate 300)
- **Code Block Background**: `#F1F5F9` (Slate 100) with dark syntax contrast (`#1E293B`)

### Typography
- **Headings**: Clean sans-serif with geometric weight (Inter / System UI font stack)
- **Monospace**: `JetBrains Mono`, `Fira Code`, or `ui-monospace` for terminal commands, CLI output, and frontmatter code snippets.

### Aesthetic Elements
- Structural grid alignment (subtle 1px border cards, clean engineering grid motifs)
- Category & status badges (e.g., `Available`, `CLI Utility`, `Infrastructure`)
- Interactive copy buttons for CLI commands (`./agent-skills add ...`)
- Real-time search/filter for agent skills

---

## 3. Page Structure & Component Hierarchy

1. **Header / Navigation Bar**
   - Cognivyn Brand Logo & Title (`Cognivyn Open Agent Skills`)
   - Links: Home, Skills Directory, CLI Quickstart, Documentation, GitHub Repository

2. **Hero Section**
   - Badge: `Founder-Led Engineering Practice × Open Source AI Tools`
   - Main Heading: "Task-Focused Agent Skills for Kilo, Claude Code & AI Assistants"
   - Subtitle: "Modular, self-contained workflows with strict discovery contracts, dependency verification, and safety boundaries."
   - Quick CTAs: "Explore Skills", "View on GitHub", Quick CLI Copy Box (`./agent-skills init`)

3. **Live Skill Search & Catalog**
   - Search bar + Category filter pills (e.g. `All`, `Deployment`, `Environment`, `GitHub`, `Git`)
   - Grid of Skill Cards featuring:
     - Skill Name & Icon
     - One-line description & target runtime
     - Key requirements / dependencies
     - Quick Install / Copy Command (`./agent-skills add <name>`)
     - Link to `SKILL.md` and companion guide

4. **CLI Interactive Quickstart & How It Works**
   - Interactive terminal preview showing CLI usage:
     - `init`, `list`, `validate`, `add`, `remove`
   - Explanatory breakdown of discovery contract (`SKILL.md` frontmatter & folder convention)

5. **Safety, Validation & Architecture Standards**
   - Highlighting safety guarantees: non-destructive git workflows, dependency cycle checking, frontmatter validation.

6. **Footer**
   - Cognivyn Infrasys LLP branding & links (`cognivyn.in`, GitHub, Docs, License).

---

## 4. Implementation Strategy
- **File Location**: `docs/index.html` (served directly via GitHub Pages from the `docs/` folder or root).
- **Single-file standalone page**: Self-contained CSS & minimal vanilla JavaScript for speed, zero external build tool dependencies, responsive on all screen sizes.
