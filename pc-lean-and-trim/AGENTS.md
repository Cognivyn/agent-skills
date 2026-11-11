# PC Lean & Trim Skill (Codex / ChatGPT)

When the user asks to clean, audit, or trim PC disk space, or reports high disk usage:
1. Refer to `SKILL.md` in this directory.
2. Run `scripts/Audit-DiskSpace.ps1` to see current disk allocation without modifying any files.
3. Check and configure `.wslconfig` and WSL sparse VHD mode if WSL/Docker is taking space.
4. Run `scripts/Clean-IdleNodeModules.ps1` to clean node_modules in projects idle for >14 days. Protect active projects.
5. Guide the user to run `scripts/Trim-Windows11.bat` as Administrator for elevated DISM and virtual disk compacting.
