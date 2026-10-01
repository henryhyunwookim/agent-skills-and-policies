---
name: sync-skills-and-policies
description: Audit and synchronize shared skills and global policies across Antigravity, GitHub Copilot, Codex, and Claude on demand, then commit synchronized changes in the skills repository.
---

# Sync Skills and Policies

Use `scripts/sync.ps1` in this skill directory. Resolve `-RepoRoot` to the shared skills repository containing `antigravity/`, `copilot/`, `codex/`, and `claude/`; never use an unrelated application's repository. From the skills repository root:

```powershell
pwsh -File copilot/skills/sync-skills-and-policies/scripts/sync.ps1 -Check
pwsh -File copilot/skills/sync-skills-and-policies/scripts/sync.ps1 -Sync
pwsh -File copilot/skills/sync-skills-and-policies/scripts/sync.ps1 -Check -PoliciesOnly
pwsh -File copilot/skills/sync-skills-and-policies/scripts/sync.ps1 -Sync -PoliciesOnly
```

By default, `-Check` audits both skills and policies, and `-Sync` updates both. `-PoliciesOnly` limits the run to policies. Skills are reconciled between Antigravity and Copilot, then adapted for Codex and Claude. Policy sync mirrors Antigravity's global `config/AGENTS.md`, nonempty `GEMINI.md`, and `always_on` modular rules under `antigravity/policies/`. It generates repository policy mirrors under the other three tool folders and updates marked shared sections in their global instructions. Other global text is preserved. Nothing runs continuously.

On another machine, clone or pull the reviewed repository and run `sync.ps1 -Sync -PoliciesOnly -PolicySource Repository`. This installs the repository Antigravity policy and refreshes the other three global policies. Review local Antigravity policy changes before replacing them with the repository version.

Skill sync stops on a global/repository conflict. Review and reconcile it before retrying.

## Automatic commit after synchronization

When this skill is explicitly invoked, run `-Sync`; the script verifies synchronization and automatically stages and commits the synchronized policy and skill files in the shared skills repository before reporting success. This is a required terminal step authorized by the current invocation. Do not stop after updating files. An audit-only request runs `-Check`, which never stages or commits. Implicit skill selection requires an explicit commit instruction before running `-Sync`.

Before running, review pending changes in the synchronization scope and `.gitignore` hygiene. Exclude credentials, local manifests, caches, tests, and scratch artifacts. The script refuses existing staged changes and limits staging to the selected policy/skill directories; unrelated changes outside those directories remain untouched. Failed synchronization, verification, or commits must be reported as incomplete. A no-change sync reports that no commit was needed.

Report the commit hash and any remaining unrelated changes. Push only when the current prompt explicitly requests it, and only after a successful commit. Standalone `sync.ps1 -Sync` also commits automatically; `-PoliciesOnly` limits both synchronization and commit scope to policies.
