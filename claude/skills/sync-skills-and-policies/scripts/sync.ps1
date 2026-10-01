<#
.SYNOPSIS
Audit or synchronize shared skills and global instructions for four agent harnesses.
.EXAMPLE
pwsh -File copilot/skills/sync-skills-and-policies/scripts/sync.ps1 -Check
.EXAMPLE
pwsh -File copilot/skills/sync-skills-and-policies/scripts/sync.ps1 -Sync
.EXAMPLE
pwsh -File copilot/skills/sync-skills-and-policies/scripts/sync.ps1 -Sync -PoliciesOnly
#>
[CmdletBinding(DefaultParameterSetName='Check')]
param(
    [Parameter(ParameterSetName='Check')][switch]$Check,
    [Parameter(ParameterSetName='Sync')][switch]$Sync,
    [ValidateSet('Antigravity','Repository')][string]$PolicySource = 'Antigravity',
    [switch]$PoliciesOnly,
    [string]$RepoRoot,
    [string]$AntigravityPolicy = (Join-Path $HOME '.gemini/config/AGENTS.md'),
    [string]$AntigravityGemini = (Join-Path $HOME '.gemini/GEMINI.md'),
    [string]$AntigravityRules = (Join-Path $HOME '.gemini/config/rules'),
    [string]$CopilotPolicy = (Join-Path $HOME '.copilot/copilot-instructions.md'),
    [string]$CodexPolicy = (Join-Path $HOME '.codex/AGENTS.md'),
    [string]$ClaudePolicy = (Join-Path $HOME '.claude/CLAUDE.md')
)
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) {
    foreach ($startPath in @($PSScriptRoot, (Get-Location).Path)) {
        $candidate = $startPath
        while ($candidate -and -not (Test-Path -LiteralPath (Join-Path $candidate '.git'))) {
            $parent = Split-Path -Parent $candidate
            if ($parent -eq $candidate) { break }
            $candidate = $parent
        }
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate '.git'))) {
            $RepoRoot = $candidate
            break
        }
    }
    if (-not $RepoRoot) { throw 'Could not find repository root; pass -RepoRoot.' }
}
$legacy = Join-Path $PSScriptRoot 'sync_skills.ps1'
$mirrors = Join-Path $PSScriptRoot 'sync-new-harnesses.ps1'
$start = '<!-- shared-agent-policy:start -->'
$end = '<!-- shared-agent-policy:end -->'
$policySnapshot = Join-Path $RepoRoot 'antigravity/policies'

function Copy-PolicyFileIfChanged {
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path -LiteralPath $Source)) { return }
    $same = (Test-Path -LiteralPath $Destination) -and
        (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    if (-not $same) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
    }
}

function Transfer-PolicySnapshot {
    param([switch]$ToRepository)
    $globalRules = $AntigravityRules
    if ($ToRepository) {
        Copy-PolicyFileIfChanged -Source $AntigravityPolicy -Destination (Join-Path $policySnapshot 'AGENTS.md')
        if ((Test-Path -LiteralPath $AntigravityGemini) -and (Get-Item -LiteralPath $AntigravityGemini).Length -gt 0) {
            Copy-PolicyFileIfChanged -Source $AntigravityGemini -Destination (Join-Path $policySnapshot 'GEMINI.md')
        }
        if (Test-Path -LiteralPath $AntigravityRules) {
            foreach ($rule in (Get-ChildItem -LiteralPath $AntigravityRules -Filter '*.md' -File)) {
                Copy-PolicyFileIfChanged -Source $rule.FullName -Destination (Join-Path $policySnapshot "rules/$($rule.Name)")
            }
        }
    } else {
        Copy-PolicyFileIfChanged -Source (Join-Path $policySnapshot 'AGENTS.md') -Destination $AntigravityPolicy
        Copy-PolicyFileIfChanged -Source (Join-Path $policySnapshot 'GEMINI.md') -Destination $AntigravityGemini
        $repoRules = Join-Path $policySnapshot 'rules'
        if (Test-Path -LiteralPath $repoRules) {
            foreach ($rule in (Get-ChildItem -LiteralPath $repoRules -Filter '*.md' -File)) {
                Copy-PolicyFileIfChanged -Source $rule.FullName -Destination (Join-Path $globalRules $rule.Name)
            }
        }
    }
}

function Test-PolicySnapshot {
    $drift = 0
    if ($PolicySource -eq 'Repository') {
        if (-not (Test-Path -LiteralPath (Join-Path $policySnapshot 'AGENTS.md'))) { throw 'Repository policy snapshot is missing AGENTS.md.' }
        $files = @(Get-ChildItem -LiteralPath $policySnapshot -Filter '*.md' -File -Recurse)
        foreach ($file in $files) {
            $relative = $file.FullName.Substring($policySnapshot.Length).TrimStart('\', '/')
            $target = if ($relative -eq 'AGENTS.md') { $AntigravityPolicy } elseif ($relative -eq 'GEMINI.md') { $AntigravityGemini } else { Join-Path $AntigravityRules $file.Name }
            if (-not (Test-Path -LiteralPath $target) -or
                (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash) {
                Write-Host "Policy snapshot differs: $target"
                $drift++
            }
        }
    } else {
        $files = @()
        if (Test-Path -LiteralPath $AntigravityPolicy) { $files += Get-Item -LiteralPath $AntigravityPolicy }
        if ((Test-Path -LiteralPath $AntigravityGemini) -and (Get-Item -LiteralPath $AntigravityGemini).Length -gt 0) { $files += Get-Item -LiteralPath $AntigravityGemini }
        if (Test-Path -LiteralPath $AntigravityRules) { $files += @(Get-ChildItem -LiteralPath $AntigravityRules -Filter '*.md' -File) }
        foreach ($file in $files) {
            $target = if ($file.FullName -eq $AntigravityPolicy) { Join-Path $policySnapshot 'AGENTS.md' } elseif ($file.FullName -eq $AntigravityGemini) { Join-Path $policySnapshot 'GEMINI.md' } else { Join-Path $policySnapshot "rules/$($file.Name)" }
            if (-not (Test-Path -LiteralPath $target) -or
                (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash) {
                Write-Host "Repository snapshot differs: $target"
                $drift++
            }
        }
    }
    return $drift
}

function Sync-Policies {
    param([switch]$DryRun)
    $sourcePolicy = if ($PolicySource -eq 'Repository') { Join-Path $policySnapshot 'AGENTS.md' } else { $AntigravityPolicy }
    $sourceGemini = if ($PolicySource -eq 'Repository') { Join-Path $policySnapshot 'GEMINI.md' } else { $AntigravityGemini }
    $sourceRules = if ($PolicySource -eq 'Repository') { Join-Path $policySnapshot 'rules' } else { $AntigravityRules }
    if (-not (Test-Path -LiteralPath $sourcePolicy)) { throw "Policy source missing: $sourcePolicy" }
    $parts = @([System.IO.File]::ReadAllText($sourcePolicy).Replace("`r`n", "`n").Trim())
    if (Test-Path -LiteralPath $sourceGemini) {
        $parts += [System.IO.File]::ReadAllText($sourceGemini).Replace("`r`n", "`n").Trim()
    }
    if (Test-Path -LiteralPath $sourceRules) {
        foreach ($rule in (Get-ChildItem -LiteralPath $sourceRules -Filter '*.md' -File | Sort-Object Name)) {
            $body = [System.IO.File]::ReadAllText($rule.FullName).Replace("`r`n", "`n").Trim()
            if ($body -match '(?s)^---\n(.*?)\n---\n(.*)$') {
                $frontmatter = $Matches[1]
                $ruleText = $Matches[2]
                if ($frontmatter -notmatch '(?m)^trigger:\s*always_on\s*$') { continue }
                $body = $ruleText.Trim()
            }
            if ($body) { $parts += $body }
        }
    }
    $source = ($parts | Where-Object { $_ }) -join "`n`n"
    if (-not $source) { throw 'Antigravity policy is empty; refusing to propagate it.' }
    $source = $source.Replace('# Antigravity Global Agent Rules', '# Shared Global Agent Rules')
    $managed = "$start`n$source`n$end"
    $drift = 0
    foreach ($pair in @(
        @{ Global = $CopilotPolicy; Repo = (Join-Path $RepoRoot 'copilot/policies/copilot-instructions.md') },
        @{ Global = $CodexPolicy; Repo = (Join-Path $RepoRoot 'codex/policies/AGENTS.md') },
        @{ Global = $ClaudePolicy; Repo = (Join-Path $RepoRoot 'claude/policies/CLAUDE.md') }
    )) {
      foreach ($target in @($pair.Global, $pair.Repo)) {
        $current = if (Test-Path -LiteralPath $target) { [System.IO.File]::ReadAllText($target).Replace("`r`n", "`n") } else { '' }
        $begin = $current.IndexOf($start, [StringComparison]::Ordinal)
        $finish = $current.IndexOf($end, [StringComparison]::Ordinal)
        if (($begin -ge 0) -ne ($finish -ge 0)) { throw "Incomplete shared policy markers in $target" }
        if ($begin -ge 0 -and $finish -lt $begin) { throw "Reversed shared policy markers in $target" }
        if ($target -eq $pair.Repo) {
            $next = $managed + "`n"
        } elseif ($begin -ge 0) {
            $finish += $end.Length
            $next = $current.Substring(0, $begin) + $managed + $current.Substring($finish)
        } elseif ($current.Trim()) {
            $next = $current.TrimEnd() + "`n`n" + $managed + "`n"
        } else {
            $next = $managed + "`n"
        }
        if ($next -ne $current) {
            $drift++
            Write-Host "Policy differs: $target"
            if (-not $DryRun) {
                New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
                [System.IO.File]::WriteAllText($target, $next, [System.Text.UTF8Encoding]::new($false))
            }
        }
      }
    }
    return $drift
}

function Invoke-PolicySync {
    param([switch]$DryRun)
    $count = Sync-Policies -DryRun:$DryRun
    Write-Output "Policy targets differing: $count"
    if ($DryRun -and $count -gt 0) { $script:hasDrift = $true }
}

function Assert-NoWorkspaceConflicts {
    foreach ($pair in @(
        @{ Global = (Join-Path $HOME '.gemini/config/skills'); Repo = (Join-Path $RepoRoot 'antigravity/skills') },
        @{ Global = (Join-Path $HOME '.agents/skills'); Repo = (Join-Path $RepoRoot 'copilot/skills') }
    )) {
        foreach ($file in (Get-ChildItem -LiteralPath $pair.Global -File -Recurse)) {
            $relative = $file.FullName.Substring($pair.Global.Length).TrimStart('\', '/')
            if ($relative -match '^sync-skills(-and-policies)?[\\/]' -or $relative -eq 'antigravity-sync-manifest.json') { continue }
            $repoFile = Join-Path $pair.Repo $relative
            if ((Test-Path -LiteralPath $repoFile) -and
                (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $repoFile -Algorithm SHA256).Hash) {
                throw "Global and repository versions differ: $relative. Reconcile them before -Sync, or use -PoliciesOnly -Sync."
            }
        }
    }
}

# Validate the commit target before changing any synchronized files.
if ($Sync) {
    foreach ($harness in @('antigravity', 'copilot', 'codex', 'claude')) {
        if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $harness) -PathType Container)) {
            throw "Not a shared skills repository: missing $harness in $RepoRoot"
        }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.gitignore'))) {
        throw 'A reviewed .gitignore is required before automatic commits.'
    }
    $staged = @(git -C $RepoRoot diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect the Git index.' }
    if ($staged.Count -gt 0) { throw 'Existing staged changes must be reconciled before synchronization.' }
}
$hasDrift = $false
if ($PoliciesOnly -or $Sync -or $Check) {
    if ($Sync) { Transfer-PolicySnapshot -ToRepository:($PolicySource -eq 'Antigravity') }
    elseif ((Test-PolicySnapshot) -gt 0) { $hasDrift = $true }
    Invoke-PolicySync -DryRun:(-not $Sync)
}
if (-not $PoliciesOnly) {
    if ($Sync) {
        Assert-NoWorkspaceConflicts
        & pwsh -NoProfile -File $legacy -SyncGlobal -RepoRoot $RepoRoot
        if ($LASTEXITCODE -ne 0) { throw 'Antigravity/Copilot sync failed.' }
        & pwsh -NoProfile -File $legacy -SyncWorkspace -RepoRoot $RepoRoot
        if ($LASTEXITCODE -ne 0) { throw 'Antigravity/Copilot mirror sync failed.' }
        & pwsh -NoProfile -File $mirrors -InstallGlobal -RepoRoot $RepoRoot
        if ($LASTEXITCODE -ne 0) { throw 'Codex/Claude sync failed.' }
    } else {
        try { Assert-NoWorkspaceConflicts } catch {
            Write-Warning $_.Exception.Message
            $hasDrift = $true
        }
        & pwsh -NoProfile -File $legacy -CheckOnly -ShowDiff -RepoRoot $RepoRoot
        if ($LASTEXITCODE -ne 0) { $hasDrift = $true }
        & pwsh -NoProfile -File $mirrors -Check -RepoRoot $RepoRoot
        if ($LASTEXITCODE -ne 0) { $hasDrift = $true }
    }
}
if ($hasDrift) { exit 1 }

# A successful -Sync includes verification and a local commit; -Check stays read-only.
if ($Sync) {
    $verification = @('-NoProfile', '-File', (Join-Path $PSScriptRoot 'sync.ps1'), '-Check', '-RepoRoot', $RepoRoot,
        '-PolicySource', $PolicySource, '-AntigravityPolicy', $AntigravityPolicy,
        '-AntigravityGemini', $AntigravityGemini, '-AntigravityRules', $AntigravityRules,
        '-CopilotPolicy', $CopilotPolicy, '-CodexPolicy', $CodexPolicy, '-ClaudePolicy', $ClaudePolicy)
    if ($PoliciesOnly) { $verification += '-PoliciesOnly' }
    & pwsh @verification
    if ($LASTEXITCODE -ne 0) { throw 'Synchronization verification failed; no commit was made.' }

    $commitPaths = @('antigravity/policies', 'copilot/policies', 'codex/policies', 'claude/policies')
    if (-not $PoliciesOnly) {
        $commitPaths += @('antigravity/skills', 'copilot/skills', 'codex/skills', 'claude/skills')
    }
    $commitPaths = @($commitPaths | Where-Object { Test-Path -LiteralPath (Join-Path $RepoRoot $_) })
    git -C $RepoRoot diff --check -- @commitPaths
    if ($LASTEXITCODE -ne 0) { throw 'Whitespace validation failed; no commit was made.' }
    # Respect .gitignore and limit staging to the synchronization scope.
    git -C $RepoRoot add -- @commitPaths
    if ($LASTEXITCODE -ne 0) { throw 'Could not stage synchronized files.' }
    git -C $RepoRoot diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw 'Staged validation failed; no commit was made.' }
    git -C $RepoRoot diff --cached --quiet
    $indexStatus = $LASTEXITCODE
    if ($indexStatus -eq 0) {
        Write-Output 'Synchronization complete; no changes to commit.'
    } elseif ($indexStatus -eq 1) {
        git -C $RepoRoot diff --cached --stat
        git -C $RepoRoot commit -m 'chore(sync): synchronize shared skills and policies'
        if ($LASTEXITCODE -ne 0) { throw 'Commit failed; synchronization is incomplete. Review the staged changes.' }
        git -C $RepoRoot log -1 --format='%h %s'
    } else {
        throw 'Cannot inspect staged changes.'
    }
    git -C $RepoRoot status --short
    if ($LASTEXITCODE -ne 0) { throw 'Post-commit status verification failed.' }
}
