---
name: sync-skills-and-policies
description: Audit and synchronize shared skills and global policies across Antigravity, GitHub Copilot, Codex, and Claude as equal peers on demand, prompt for conflict resolution when divergent edits occur, and commit synchronized changes in the skills repository.
---

# Sync Skills and Policies

Use `scripts/sync.ps1` in this skill directory. Resolve `-RepoRoot` to the shared skills repository containing `antigravity/`, `copilot/`, `codex/`, and `claude/`; never use an unrelated application's repository. From the skills repository root:

```powershell
pwsh -File copilot/skills/sync-skills-and-policies/scripts/sync.ps1 -Check
pwsh -File copilot/skills/sync-skills-and-policies/scripts/sync.ps1 -Sync
pwsh -File copilot/skills/sync-skills-and-policies/scripts/sync.ps1 -Check -PoliciesOnly
pwsh -File copilot/skills/sync-skills-and-policies/scripts/sync.ps1 -Sync -PoliciesOnly
```

By default, `-Check` audits both skills and policies across all four harnesses as equal peers, and `-Sync` synchronizes all targets. `-PoliciesOnly` limits the run to policies.

All four harnesses (Antigravity, GitHub Copilot, OpenAI Codex, and Claude Code) are active upstream authoring peers:
- **Skills**: Discovered across all four global registries and repository mirrors. Content is normalized and translated between tool styles (`run_command` / `view_file` for Antigravity, `run_in_terminal` / `read_file` for Copilot, and neutral descriptions for Codex and Claude).
- **Policies**: Section-aware compilation and decomposition. An edit originating in any harness (`CLAUDE.md`, `copilot-instructions.md`, `AGENTS.md`, or Antigravity's modular `rules/*.md`) is automatically detected, decomposed, and fanned out to all other harnesses.
- **Interactive Conflict Resolution**: If divergent edits are detected across harnesses during a sync run, `sync.ps1` prompts interactively for which harness to treat as the authoritative source:
  ```text
  [CONFLICT DETECTED] Divergent policy/skill detected across harnesses:
    [1] Antigravity
    [2] Copilot
    [3] Codex
    [4] Claude
  Select authoritative source [1-4/S to Skip]:
  ```
  In non-interactive environments, it resolves by selecting the latest modified harness. You can also bypass prompting by specifying `-PolicySource <Antigravity|Copilot|Codex|Claude|Repository>` or `-SkillSource <Antigravity|Copilot|Codex|Claude>`.

On another machine, clone or pull the reviewed repository and run `sync.ps1 -Sync -PoliciesOnly -PolicySource Repository`. This installs the repository policy snapshot into all four global locations.

## Automatic commit after synchronization

When this skill is explicitly invoked, run `-Sync`; the script verifies synchronization across all four harnesses and automatically stages and commits the synchronized policy and skill files in the shared skills repository before reporting success. This is a required terminal step authorized by the current invocation. Do not stop after updating files. An audit-only request runs `-Check`, which never stages or commits. Implicit skill selection requires an explicit commit instruction before running `-Sync`.

Before running, review pending changes in the synchronization scope and `.gitignore` hygiene. Exclude credentials, local manifests, caches, tests, and scratch artifacts. The script refuses existing staged changes and limits staging to the selected policy/skill directories; unrelated changes outside those directories remain untouched. Failed synchronization, verification, or commits must be reported as incomplete. A no-change sync reports that no commit was needed.

Report the commit hash and any remaining unrelated changes. Push only when the current prompt explicitly requests it, and only after a successful commit. Standalone `sync.ps1 -Sync` also commits automatically; `-PoliciesOnly` limits both synchronization and commit scope to policies.
