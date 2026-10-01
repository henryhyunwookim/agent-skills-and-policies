---
name: sync-skills-and-policies
description: Audit and synchronize shared skills and global policies across Antigravity, GitHub Copilot, Codex, and Claude on demand, then commit synchronized changes in the skills repository.
---

# Sync Skills and Policies

Use `scripts/sync.ps1` in this skill directory. Resolve `-RepoRoot` to the shared skills repository containing `antigravity/`, `copilot/`, `codex/`, and `claude/`; never use an unrelated application's repository. From the skills repository root:

```powershell
pwsh -File claude/skills/sync-skills-and-policies/scripts/sync.ps1 -Check
pwsh -File claude/skills/sync-skills-and-policies/scripts/sync.ps1 -Sync
pwsh -File claude/skills/sync-skills-and-policies/scripts/sync.ps1 -Check -PoliciesOnly
pwsh -File claude/skills/sync-skills-and-policies/scripts/sync.ps1 -Sync -PoliciesOnly
```

By default, `-Check` audits both skills and policies, and `-Sync` updates both. `-PoliciesOnly` limits the run to policies. Skills are reconciled between Antigravity and Copilot, then adapted for Codex and Claude. Policy sync mirrors Antigravity's global `config/AGENTS.md`, nonempty `GEMINI.md`, and `always_on` modular rules under `antigravity/policies/`. It generates repository policy mirrors under the other three tool folders and updates marked shared sections in their global instructions. Other global text is preserved. Nothing runs continuously.

On another machine, clone or pull the reviewed repository and run `sync.ps1 -Sync -PoliciesOnly -PolicySource Repository`. This installs the repository Antigravity policy and refreshes the other three global policies. Review local Antigravity policy changes before replacing them with the repository version.

Skill sync stops on a global/repository conflict. Review and reconcile it before retrying.

## Commit after synchronization

Direct invocation of this skill in the current prompt authorizes synchronization followed by a local Git commit in the shared skills repository as the workflow's terminal step. Authorization applies only to that invocation. An audit-only request (`-Check`) never stages or commits. Implicit skill selection requires an explicit commit instruction before staging.

1. Record the skills repository's initial Git status. After successful synchronization, run `-Check` with the same scope and policy source; resolve any remaining drift before committing.
2. Review the diff and new files, check `.gitignore` hygiene, and exclude credentials, local manifests, caches, tests, and scratch artifacts. Include reviewed policy and skill changes involved in synchronization, including pending changes from an earlier sync; leave unrelated pre-existing edits and staged changes untouched. If unrelated staged changes prevent an isolated commit, stop and report the conflict.
3. Run `git diff --check`, selectively stage the reviewed synchronization files, and inspect the staged diff. Commit with a descriptive Conventional Commit message such as `chore(sync): synchronize shared skills and policies`. If there are no relevant changes, report that no commit was needed.
4. Verify Git status and report the commit hash, summary, and any remaining unrelated changes. Do not push unless the current prompt explicitly requests a push.

The agent performs this Git step after the synchronization script succeeds; standalone script execution does not commit automatically.
