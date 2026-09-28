# Shared Agent Skills and Policies

This repository keeps reusable skills and shared global instructions for Google Antigravity, GitHub Copilot, Codex, and Claude Code. Each tool has one folder containing `skills/` and `policies/`. These are reviewable repository mirrors of machine-global files. Run the sync commands with PowerShell 7 (`pwsh`) from the repository root.

| Tool | Repository skills | Repository policies | Global skills | Global policy |
| :--- | :--- | :--- | :--- | :--- |
| Antigravity | `antigravity/skills/` | `antigravity/policies/` | `~/.gemini/config/skills/` | `~/.gemini/config/AGENTS.md` and rules |
| GitHub Copilot | `copilot/skills/` | `copilot/policies/` | `~/.agents/skills/` | `~/.copilot/copilot-instructions.md` |
| Codex | `codex/skills/` | `codex/policies/` | `~/.codex/skills/` | `~/.codex/AGENTS.md` |
| Claude Code | `claude/skills/` | `claude/policies/` | `~/.claude/skills/` | `~/.claude/CLAUDE.md` |

## Sync

Use [sync-skills-and-policies](copilot/skills/sync-skills-and-policies/SKILL.md) from the repository root:

```powershell
pwsh -File copilot/skills/sync-skills-and-policies/scripts/sync.ps1 -Check
pwsh -File copilot/skills/sync-skills-and-policies/scripts/sync.ps1 -Sync
```

Both commands cover skills **and** policies. `-Check` reports differences without writing. `-Sync` first mirrors Antigravity's global policy and updates the other three policy mirrors and global instructions, then reconciles Antigravity and Copilot skills and generates Codex and Claude skill copies. A global skill that differs from its repository mirror stops the skill phase; inspect the two copies and reconcile them before retrying. Policy updates may already have completed when that happens. The scripts do not run continuously or perform Git operations.

For policies alone, add `-PoliciesOnly`. On another machine, after cloning or pulling the reviewed repository, install the repository policy into the four global locations with:

```powershell
pwsh -File copilot/skills/sync-skills-and-policies/scripts/sync.ps1 -Sync -PoliciesOnly -PolicySource Repository
```

The policy source is Antigravity's global `config/AGENTS.md`, any nonempty `GEMINI.md`, and `always_on` modular rules. The generated policies are bounded by `shared-agent-policy` markers, so other global instructions remain in place. `-PolicySource Repository` reverses the Antigravity policy copy direction; review local policy changes before using it. This sync covers text instructions; tool permissions and application settings remain tool specific.

## Skills

The seven skills are mirrored under each tool's `skills/` folder. Antigravity and Copilot global skills are the inputs for skill sync; Copilot's repository copies supply the Codex and Claude adapters. On a new machine, the repository policy command above installs policies, while skills need to be present in the global Antigravity and Copilot registries before running the full skill sync. The global synchronization manifest contains machine paths and timestamps and is not copied into the repository.

Each skill has a `SKILL.md` with YAML `name` and `description` fields. The harness can use that metadata to discover the skill and read its full instructions when relevant. Some skills include a `scripts/` folder for supporting code.

| Skill | Purpose |
| :--- | :--- |
| [clone-github-repo](copilot/skills/clone-github-repo/SKILL.md) | Clone and inspect a remote repository. |
| [cloud-deploy](copilot/skills/cloud-deploy/SKILL.md) | Prepare and deploy an application to cloud hosting. |
| [generate-workspace-readme](copilot/skills/generate-workspace-readme/SKILL.md) | Create or update repository documentation. |
| [safe-git-commit](copilot/skills/safe-git-commit/SKILL.md) | Review, commit, and push Git changes. |
| [sequential-image-extractor](copilot/skills/sequential-image-extractor/SKILL.md) | Extract ordered image content and compile a summary. |
| [sync-skills-and-policies](copilot/skills/sync-skills-and-policies/SKILL.md) | Audit and synchronize skills and policies. |
| [workspace-organizer](copilot/skills/workspace-organizer/SKILL.md) | Organize workspace files and improve code documentation. |

OpenCode and Cursor may discover some global skill directories, but this repository does not maintain separate mirrors for them.

## Updating a skill

Edit the appropriate machine-global Antigravity or Copilot skill, then run `-Check` and inspect any reported difference before running `-Sync`. The sync helper translates Antigravity tool names such as `run_command` and `view_file` for Copilot, while the Codex and Claude adapter generates their copies from Copilot. Review the four repository mirrors before committing them. Keep scripts beside the skill that uses them.

When adding a skill, create a folder named after the skill in the relevant global registry and include a `SKILL.md` file:

```markdown
---
name: example-skill
description: Explain when this skill should be used.
---

# Example Skill

Describe the workflow and how to verify its result.
```

Run `-Check` again after synchronization to confirm the global and repository copies agree. Review `git status` and the diff before staging; policy and skill sync do not commit files automatically.
