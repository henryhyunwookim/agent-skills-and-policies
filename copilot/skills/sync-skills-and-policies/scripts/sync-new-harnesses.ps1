<#
.SYNOPSIS
    Backward-compatibility wrapper delegating to 4-way sync_skills.ps1.
#>
[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$InstallGlobal,
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))),
    [string]$CodexGlobal = (Join-Path $HOME '.codex/skills'),
    [string]$ClaudeGlobal = (Join-Path $HOME '.claude/skills')
)

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'sync_skills.ps1'

if ($Check) {
    & pwsh -NoProfile -File $script -CheckOnly -RepoRoot $RepoRoot -CdxGlobal $CodexGlobal -CldGlobal $ClaudeGlobal
} elseif ($InstallGlobal) {
    & pwsh -NoProfile -File $script -SyncGlobal -SyncWorkspace -RepoRoot $RepoRoot -CdxGlobal $CodexGlobal -CldGlobal $ClaudeGlobal
} else {
    & pwsh -NoProfile -File $script -CheckOnly -RepoRoot $RepoRoot -CdxGlobal $CodexGlobal -CldGlobal $ClaudeGlobal
}
exit $LASTEXITCODE
