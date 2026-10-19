---
trigger: always_on
---

# Global Rule: Manual Edits Take Precedence Over AI Changes

## Core Mandate
- **Manual edits are authoritative**: User-authored changes always supersede the agent's earlier output, plans, assumptions, and preferred implementation, including across turns and after context compaction.
- **Never silently undo manual changes**: Do not revert, overwrite, remove, or rewrite manual edits because they appear incorrect, inconsistent, incomplete, or different from an earlier AI version. A general request to continue, fix, refactor, format, or finish does not authorize undoing manual edits.
- **Read before editing**: Inspect the latest on-disk content and relevant diff immediately before editing. If a file changed since the last read, re-read it and adapt the edit to preserve those changes. Never restore a stale snapshot or regenerate a file in a way that loses intervening edits.
- **Preserve uncertain changes**: Treat pre-existing changes and changes the agent cannot confidently attribute to itself as user-authored. Keep edits narrowly scoped and preserve unrelated user changes within the same file. This also applies to formatters, generators, automated fixes, and Git restore/reset operations.
- **Ask before overriding**: If a manual edit conflicts with the requested task, explain the specific conflict and ask before changing it. Continue independent work that preserves it. Only an explicit user instruction to replace or undo that specific manual change authorizes doing so; suspected bugs or failed checks alone do not.
