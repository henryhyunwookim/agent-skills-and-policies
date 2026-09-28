---
name: sync-skills-and-policies
description: Audit and synchronize shared skills and global policies across Antigravity, GitHub Copilot, Codex, and Claude on demand.
---

# Sync Skills and Policies

Use `scripts/sync.ps1` in this skill directory. From the repository root:

```powershell
pwsh -File codex/skills/sync-skills-and-policies/scripts/sync.ps1 -Check
pwsh -File codex/skills/sync-skills-and-policies/scripts/sync.ps1 -Sync
pwsh -File codex/skills/sync-skills-and-policies/scripts/sync.ps1 -Check -PoliciesOnly
pwsh -File codex/skills/sync-skills-and-policies/scripts/sync.ps1 -Sync -PoliciesOnly
```

By default, `-Check` audits both skills and policies, and `-Sync` updates both. `-PoliciesOnly` limits the run to policies. Skills are reconciled between Antigravity and Copilot, then adapted for Codex and Claude. Policy sync mirrors Antigravity's global `config/AGENTS.md`, nonempty `GEMINI.md`, and `always_on` modular rules under `antigravity/policies/`. It generates repository policy mirrors under the other three tool folders and updates marked shared sections in their global instructions. Other global text is preserved. Nothing runs continuously.

On another machine, clone or pull the reviewed repository and run `sync.ps1 -Sync -PoliciesOnly -PolicySource Repository`. This installs the repository Antigravity policy and refreshes the other three global policies. Git transfer remains manual. Review local Antigravity policy changes before replacing them with the repository version.

Skill sync stops on a global/repository conflict. Review and reconcile it before retrying. Do not commit or push unless the user asks.
