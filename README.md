# Shared Agent Skills

This repository maintains two local skill trees for two different agent environments:

- Antigravity source: `C:\Users\hyunwookim\.agents\skills`
- GitHub Copilot source: `C:\Users\hyunwookim\.gemini\config\skills`

The repository mirrors those trees under separate folders so each environment can be maintained independently:

```text
skills/
|- .agents/skills/              # Antigravity skills
`- .gemini/config/skills/       # GitHub Copilot skills
```

## Source-of-Truth Rules

1. Add or edit a skill in the local source tree that uses it.
2. Copy the changed files into the matching repository folder.
3. Keep `.agents/skills` and `.gemini/config/skills` separate. A skill may exist in one tree, the other, or both.
4. Never copy `.git` directories, caches, credentials, or machine-specific files into either repository folder.
5. Review the staged file list before committing.

The repository's `.agents/skills` and `.gemini/config/skills` folders are synchronization targets, not a third source of truth.

## Sync From Local Folders

Run these commands from PowerShell after changing local skills:

```powershell
$repo = 'C:\Users\hyunwookim\skills'
$antigravity = 'C:\Users\hyunwookim\.agents\skills'
$copilot = 'C:\Users\hyunwookim\.gemini\config\skills'

Get-ChildItem -LiteralPath (Join-Path $repo '.agents\skills') -Force |
    Remove-Item -Recurse -Force
Get-ChildItem -LiteralPath (Join-Path $repo '.gemini\config\skills') -Force |
    Where-Object Name -ne '.git' |
    Remove-Item -Recurse -Force

Get-ChildItem -LiteralPath $antigravity -Force |
    Copy-Item -Destination (Join-Path $repo '.agents\skills') -Recurse -Force
Get-ChildItem -LiteralPath $copilot -Force |
    Where-Object Name -ne '.git' |
    Copy-Item -Destination (Join-Path $repo '.gemini\config\skills') -Recurse -Force
```

The cleanup step prevents deleted or renamed local skills from remaining in Git. The `.git` exclusion is required because the Copilot source folder may itself be a Git checkout.

## Verify Before Commit

Compare relative file lists and SHA-256 hashes for each source and target pair. At minimum, confirm that:

- Every source file has a matching repository file.
- No repository file exists only in the target.
- Hash mismatches are zero.
- No path contains a nested `.git` directory.

Then inspect the staged paths:

```powershell
git -C C:\Users\hyunwookim\skills status --short
git -C C:\Users\hyunwookim\skills diff --cached --name-only
```

Only the two maintained trees and intentionally changed documentation should be staged.

## Commit And Push

```powershell
$repo = 'C:\Users\hyunwookim\skills'
git -C $repo add README.md .agents .gemini
git -C $repo commit -m 'chore: sync agent skill trees'
git -C $repo push origin main
git -C $repo status --short --branch
```

The expected final state is a clean `main` branch synchronized with `origin/main`.

## Adding A New Skill

Create the skill directory in the appropriate local source tree with a `SKILL.md` file containing valid frontmatter:

```markdown
---
name: example-skill
description: Explain when this skill should be used.
---
```

Sync the matching repository folder, verify the result, and commit the change. If both environments should use the skill, add it to both local source trees and verify both copies independently.