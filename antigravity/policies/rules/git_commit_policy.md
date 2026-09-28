---
trigger: always_on
---

# Git Commit Policy

## 1. Core Principle: Zero Unprompted Commits
- **STRICT PROHIBITION ON AUTOMATIC COMMITS**: Under NO circumstances may the agent spontaneously stage (`git add`), commit (`git commit`), or push (`git push`) changes to any Git repository without explicit, unambiguous instruction from the user in the **current prompt**.
- **Content Requests != Commit Requests**: Directives that describe what to edit, write, or build (e.g., *"update README"*, *"add architectural decisions"*, *"highlight permanent memory"*, *"refactor this class"*, *"fix the error"*) are strictly file-editing instructions. They NEVER authorize a Git commit or push.

## 2. Strict Per-Turn Scope Isolation (No Carryover)
- **One-Shot Authorization Only**: A directive to commit or push (e.g., `/safe-git-commit`, *"commit and push"*, *"save to git"*) is strictly a **single-turn, one-shot action**.
- **NEVER Carry Over Across Turns**: Once a commit or push requested in turn N is completed, that authorization expires immediately.
- **Subsequent Follow-Ups Are Uncommitted**: If the user submits a follow-up request in turn N+1 (e.g., *"also add section X"*, *"adjust the wording"*, *"highlight memory"*), that follow-up MUST be treated as an uncommitted file edit. Do NOT stage, commit, or push unless the user explicitly commands a commit again in that specific follow-up message.
- **No Persistent "Commit Mode"**: There is no persistent session-wide "commit mode". Never assume prior commit instructions apply to ongoing or subsequent edits.

## 3. Explicit Instruction Criteria
A Git commit or push is ONLY authorized if the user's **current prompt** contains an explicit version control directive:
- Explicit slash commands: `/safe-git-commit`
- Explicit imperative phrases: *"commit this"*, *"commit and push"*, *"push to origin"*, *"save changes to git"*, *"make a commit"*
- Standard runbooks or skills that explicitly require committing as their documented terminal step (only when that runbook/skill was directly invoked in the current turn).

In all other cases:
- Inspect and modify the relevant files.
- Verify changes and show the diffs/summary to the user.
- **STOP** and wait for the user to review. Do not stage, commit, or push.

## 4. Forbidden Assumptions
- **FORBIDDEN**: Do NOT commit because "the repository was clean before".
- **FORBIDDEN**: Do NOT commit because "the edits are complete and tested".
- **FORBIDDEN**: Do NOT commit because "we committed earlier in this conversation".
- **FORBIDDEN**: Do NOT commit because "the skill workflow usually commits".
- **FORBIDDEN**: Do NOT commit because "it would be convenient or safe to save progress now".