<#
.SYNOPSIS
    Omnidirectional 4-way synchronization of agent skills and global policies across
    Google Antigravity, GitHub Copilot, OpenAI Codex, and Claude Code.
.EXAMPLE
    pwsh -File copilot/skills/sync-skills-and-policies/scripts/sync.ps1 -Check
.EXAMPLE
    pwsh -File copilot/skills/sync-skills-and-policies/scripts/sync.ps1 -Sync
.EXAMPLE
    pwsh -File copilot/skills/sync-skills-and-policies/scripts/sync.ps1 -Sync -PoliciesOnly
.EXAMPLE
    pwsh -File copilot/skills/sync-skills-and-policies/scripts/sync.ps1 -Sync -PoliciesOnly -PolicySource Claude
#>
[CmdletBinding(DefaultParameterSetName='Check')]
param(
    [Parameter(ParameterSetName='Check')][switch]$Check,
    [Parameter(ParameterSetName='Sync')][switch]$Sync,
    [ValidateSet('Auto','Antigravity','Copilot','Codex','Claude','Repository')][string]$PolicySource = 'Auto',
    [ValidateSet('Auto','Antigravity','Copilot','Codex','Claude')][string]$SkillSource = 'Auto',
    [string]$TargetSkill,
    [switch]$PoliciesOnly,
    [switch]$Force,
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

$skillsScript = Join-Path $PSScriptRoot 'sync_skills.ps1'
$startTag = '<!-- shared-agent-policy:start -->'
$endTag = '<!-- shared-agent-policy:end -->'
$policySnapshot = Join-Path $RepoRoot 'antigravity/policies'

# ---------------------------------------------------------
# Helper: Conflict Resolver Prompt
# ---------------------------------------------------------
function Resolve-HarnessChoice {
    param(
        [string]$ItemType,
        [hashtable]$Candidates
    )
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host " [CONFLICT DETECTED] Divergent $ItemType detected across harnesses:" -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    $i = 1
    $indexMap = @{}
    foreach ($h in @('Antigravity', 'Copilot', 'Codex', 'Claude')) {
        if ($Candidates.ContainsKey($h)) {
            $info = $Candidates[$h]
            Write-Host "  [$i] $h (Modified: $($info.Time))`n      Path: $($info.Path)" -ForegroundColor Cyan
            $indexMap["$i"] = $h
            $i++
        }
    }
    Write-Host "  [S] Skip / Cancel" -ForegroundColor DarkGray

    $isInteractive = [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
    if (-not $isInteractive) {
        $latest = ($Candidates.GetEnumerator() | Sort-Object { $_.Value.Time } -Descending | Select-Object -First 1).Key
        Write-Warning "Non-interactive shell: resolving conflict by selecting latest modified harness ($latest)."
        return $latest
    }

    while ($true) {
        $selection = Read-Host "Select authoritative source [1-$($i-1)/S]"
        $selection = if ($selection) { $selection.Trim() } else { '' }
        if ($selection -eq 'S' -or $selection -eq 's') { return $null }
        if ($indexMap.ContainsKey($selection)) {
            return $indexMap[$selection]
        }
        Write-Host "Invalid selection. Please enter a number between 1 and $($i-1) or 'S' to skip." -ForegroundColor Red
    }
}

# ---------------------------------------------------------
# Helper: Compile Antigravity policy into single shared string
# ---------------------------------------------------------
function Compile-AntigravityPolicy {
    param([string]$AgentsFile, [string]$GeminiFile, [string]$RulesDir)
    if (-not (Test-Path -LiteralPath $AgentsFile)) { return '' }
    $parts = @([System.IO.File]::ReadAllText($AgentsFile).Replace("`r`n", "`n").Trim())
    if ((Test-Path -LiteralPath $GeminiFile) -and (Get-Item -LiteralPath $GeminiFile).Length -gt 0) {
        $parts += [System.IO.File]::ReadAllText($GeminiFile).Replace("`r`n", "`n").Trim()
    }
    if (Test-Path -LiteralPath $RulesDir) {
        foreach ($rule in (Get-ChildItem -LiteralPath $RulesDir -Filter '*.md' -File | Sort-Object Name)) {
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
    return $source.Replace('# Antigravity Global Agent Rules', '# Shared Global Agent Rules')
}

# ---------------------------------------------------------
# Helper: Extract shared block from monolithic instruction file
# ---------------------------------------------------------
function Extract-MonolithicSharedPolicy {
    param([string]$FilePath)
    if (-not (Test-Path -LiteralPath $FilePath)) { return '' }
    $raw = [System.IO.File]::ReadAllText($FilePath).Replace("`r`n", "`n")
    $b = $raw.IndexOf($startTag, [StringComparison]::Ordinal)
    $f = $raw.IndexOf($endTag, [StringComparison]::Ordinal)
    if ($b -lt 0 -or $f -lt 0 -or $f -le $b) { return '' }
    return $raw.Substring($b + $startTag.Length, $f - ($b + $startTag.Length)).Trim()
}

# ---------------------------------------------------------
# Helper: Decompose shared string into Antigravity AGENTS + rules
# ---------------------------------------------------------
function Decompose-SharedPolicyToAntigravity {
    param(
        [string]$SharedPolicyText,
        [string]$TargetAgentsPath,
        [string]$TargetRulesDir
    )
    $cleanText = $SharedPolicyText.Replace("`r`n", "`n").Trim()
    $sections = [System.Collections.Generic.List[string]]::new()
    $currentSection = [System.Text.StringBuilder]::new()

    foreach ($line in ($cleanText -split "`n")) {
        if ($line -match '^#\s+' -and $currentSection.Length -gt 0) {
            $sections.Add($currentSection.ToString().Trim())
            $currentSection.Clear() | Out-Null
        }
        $currentSection.AppendLine($line) | Out-Null
    }
    if ($currentSection.Length -gt 0) {
        $sections.Add($currentSection.ToString().Trim())
    }

    if ($sections.Count -gt 0) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $TargetAgentsPath) -Force | Out-Null
        $agentsBody = $sections[0].Replace('# Shared Global Agent Rules', '# Antigravity Global Agent Rules')
        [System.IO.File]::WriteAllText($TargetAgentsPath, $agentsBody + "`n", [System.Text.UTF8Encoding]::new($false))
    }

    if (-not (Test-Path -LiteralPath $TargetRulesDir)) {
        New-Item -ItemType Directory -Path $TargetRulesDir -Force | Out-Null
    }

    $knownRules = @{
        'Root Directory Cleanliness'    = 'clean_root_directory.md'
        'Never Store Testing'           = 'clean_test_artifacts.md'
        'Cloud Deployment'              = 'cloud_deployments.md'
        'GCP Resource & Cost Hygiene'   = 'gcp_resource_cost_hygiene.md'
        'Git Commit Policy'             = 'git_commit_policy.md'
        'Manual Edits Take Precedence'  = 'manual_edits.md'
        'GitHub Repository Creation'    = 'workspace_github_sync.md'
    }

    for ($i = 1; $i -lt $sections.Count; $i++) {
        $secText = $sections[$i]
        $firstLine = ($secText -split "`n")[0]
        $matchedFile = $null
        foreach ($pattern in $knownRules.Keys) {
            if ($firstLine -match [regex]::Escape($pattern)) {
                $matchedFile = $knownRules[$pattern]
                break
            }
        }
        if (-not $matchedFile) {
            $slug = ($firstLine -replace '^#\s*(Global Rule:\s*)?', '' -replace '[^a-zA-Z0-9]+', '_').Trim('_').ToLowerInvariant()
            $matchedFile = "$slug.md"
        }
        $rulePath = Join-Path $TargetRulesDir $matchedFile
        $ruleContent = "---`ntrigger: always_on`n---`n`n$secText`n"
        [System.IO.File]::WriteAllText($rulePath, $ruleContent, [System.Text.UTF8Encoding]::new($false))
    }
}

# ---------------------------------------------------------
# Helper: Inject managed block into monolithic target file
# ---------------------------------------------------------
function Inject-MonolithicPolicy {
    param([string]$FilePath, [string]$CompiledBlock)
    $current = if (Test-Path -LiteralPath $FilePath) { [System.IO.File]::ReadAllText($FilePath).Replace("`r`n", "`n") } else { '' }
    $b = $current.IndexOf($startTag, [StringComparison]::Ordinal)
    $f = $current.IndexOf($endTag, [StringComparison]::Ordinal)
    $managed = "$startTag`n$CompiledBlock`n$endTag"

    if ($b -ge 0 -and $f -ge 0 -and $f -gt $b) {
        $f += $endTag.Length
        $next = $current.Substring(0, $b) + $managed + $current.Substring($f)
    } elseif ($current.Trim()) {
        $next = $current.TrimEnd() + "`n`n" + $managed + "`n"
    } else {
        $next = $managed + "`n"
    }

    if ($next -ne $current) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $FilePath) -Force | Out-Null
        [System.IO.File]::WriteAllText($FilePath, $next, [System.Text.UTF8Encoding]::new($false))
        return $true
    }
    return $false
}

# ---------------------------------------------------------
# Main Policy Sync Function (4-Way Peer)
# ---------------------------------------------------------
function Invoke-OmniPolicySync {
    param([switch]$DryRun)

    # 1. Harvest shared policy text from all sources
    $repoBaseline = Compile-AntigravityPolicy -AgentsFile (Join-Path $policySnapshot 'AGENTS.md') `
                                            -GeminiFile (Join-Path $policySnapshot 'GEMINI.md') `
                                            -RulesDir (Join-Path $policySnapshot 'rules')

    $agyContent = Compile-AntigravityPolicy -AgentsFile $AntigravityPolicy -GeminiFile $AntigravityGemini -RulesDir $AntigravityRules
    $copContent = Extract-MonolithicSharedPolicy -FilePath $CopilotPolicy
    $cdxContent = Extract-MonolithicSharedPolicy -FilePath $CodexPolicy
    $cldContent = Extract-MonolithicSharedPolicy -FilePath $ClaudePolicy

    $harvested = @{
        'Antigravity' = @{ Content = $agyContent; Path = $AntigravityPolicy; Time = $(if (Test-Path $AntigravityPolicy) { (Get-Item $AntigravityPolicy).LastWriteTime } else { [DateTime]::MinValue }) }
        'Copilot'     = @{ Content = $copContent; Path = $CopilotPolicy;     Time = $(if (Test-Path $CopilotPolicy) { (Get-Item $CopilotPolicy).LastWriteTime } else { [DateTime]::MinValue }) }
        'Codex'       = @{ Content = $cdxContent; Path = $CodexPolicy;       Time = $(if (Test-Path $CodexPolicy) { (Get-Item $CodexPolicy).LastWriteTime } else { [DateTime]::MinValue }) }
        'Claude'      = @{ Content = $cldContent; Path = $ClaudePolicy;      Time = $(if (Test-Path $ClaudePolicy) { (Get-Item $ClaudePolicy).LastWriteTime } else { [DateTime]::MinValue }) }
    }

    $repoFiles = @(
        @{ Harness = 'Copilot'; Path = (Join-Path $RepoRoot 'copilot/policies/copilot-instructions.md') },
        @{ Harness = 'Codex';   Path = (Join-Path $RepoRoot 'codex/policies/AGENTS.md') },
        @{ Harness = 'Claude';  Path = (Join-Path $RepoRoot 'claude/policies/CLAUDE.md') }
    )

    $differing = @{}
    foreach ($h in $harvested.Keys) {
        $c = $harvested[$h].Content
        if ($c -and ($c.Trim() -ne $repoBaseline.Trim())) {
            $differing[$h] = $harvested[$h]
        }
    }

    $repoDrifts = 0
    foreach ($rf in $repoFiles) {
        $c = Extract-MonolithicSharedPolicy -FilePath $rf.Path
        if ($c.Trim() -ne $repoBaseline.Trim()) {
            $repoDrifts++
            Write-Host "Repo policy differs: $($rf.Path)"
        }
    }

    $globalDrifts = 0
    foreach ($h in $harvested.Keys) {
        if ($harvested[$h].Content.Trim() -ne $repoBaseline.Trim()) {
            $globalDrifts++
            Write-Host "Global policy differs: $($harvested[$h].Path)"
        }
    }

    $totalDrift = $globalDrifts + $repoDrifts
    Write-Host "Policy targets differing: $totalDrift"

    if ($DryRun) {
        if ($totalDrift -gt 0) { $script:hasDrift = $true }
        return $totalDrift
    }

    if ($totalDrift -eq 0) { return 0 }

    # 2. Determine authoritative source
    $selectedSource = $PolicySource
    if ($selectedSource -eq 'Auto') {
        if ($differing.Count -eq 0) {
            $selectedSource = 'Repository'
        } elseif ($differing.Count -eq 1) {
            $selectedSource = ($differing.Keys | Select-Object -First 1)
            Write-Host "Auto-detected upstream policy author: $selectedSource" -ForegroundColor Green
        } else {
            $uniqueContents = @($differing.Values | ForEach-Object { $_.Content.Trim() } | Select-Object -Unique)
            if ($uniqueContents.Count -eq 1) {
                $selectedSource = ($differing.Keys | Select-Object -First 1)
                Write-Host "Consensus policy change detected across: $($differing.Keys -join ', ')" -ForegroundColor Green
            } else {
                $selectedSource = Resolve-HarnessChoice -ItemType 'Policy' -Candidates $differing
                if (-not $selectedSource) {
                    throw 'Policy synchronization cancelled due to unresolved conflict.'
                }
            }
        }
    }

    Write-Host "Applying authoritative policy from: $selectedSource" -ForegroundColor Green

    # 3. Obtain authoritative shared policy content
    $authoritativeBlock = ''
    if ($selectedSource -eq 'Repository') {
        $authoritativeBlock = $repoBaseline
    } elseif ($selectedSource -eq 'Antigravity') {
        $authoritativeBlock = $agyContent
        Copy-Item -LiteralPath $AntigravityPolicy -Destination (Join-Path $policySnapshot 'AGENTS.md') -Force
        if ((Test-Path -LiteralPath $AntigravityGemini) -and (Get-Item -LiteralPath $AntigravityGemini).Length -gt 0) {
            Copy-Item -LiteralPath $AntigravityGemini -Destination (Join-Path $policySnapshot 'GEMINI.md') -Force
        }
        if (Test-Path -LiteralPath $AntigravityRules) {
            foreach ($r in (Get-ChildItem -LiteralPath $AntigravityRules -Filter '*.md' -File)) {
                Copy-Item -LiteralPath $r.FullName -Destination (Join-Path $policySnapshot "rules/$($r.Name)") -Force
            }
        }
    } else {
        $authoritativeBlock = $harvested[$selectedSource].Content
        Decompose-SharedPolicyToAntigravity -SharedPolicyText $authoritativeBlock `
                                            -TargetAgentsPath (Join-Path $policySnapshot 'AGENTS.md') `
                                            -TargetRulesDir (Join-Path $policySnapshot 'rules')
        Decompose-SharedPolicyToAntigravity -SharedPolicyText $authoritativeBlock `
                                            -TargetAgentsPath $AntigravityPolicy `
                                            -TargetRulesDir $AntigravityRules
    }

    # 4. Propagate authoritative compiled block to all harnesses
    Inject-MonolithicPolicy -FilePath $CopilotPolicy -CompiledBlock $authoritativeBlock | Out-Null
    Inject-MonolithicPolicy -FilePath (Join-Path $RepoRoot 'copilot/policies/copilot-instructions.md') -CompiledBlock $authoritativeBlock | Out-Null

    Inject-MonolithicPolicy -FilePath $CodexPolicy -CompiledBlock $authoritativeBlock | Out-Null
    Inject-MonolithicPolicy -FilePath (Join-Path $RepoRoot 'codex/policies/AGENTS.md') -CompiledBlock $authoritativeBlock | Out-Null

    Inject-MonolithicPolicy -FilePath $ClaudePolicy -CompiledBlock $authoritativeBlock | Out-Null
    Inject-MonolithicPolicy -FilePath (Join-Path $RepoRoot 'claude/policies/CLAUDE.md') -CompiledBlock $authoritativeBlock | Out-Null

    if ($selectedSource -eq 'Repository') {
        Copy-Item -LiteralPath (Join-Path $policySnapshot 'AGENTS.md') -Destination $AntigravityPolicy -Force
        if (Test-Path (Join-Path $policySnapshot 'GEMINI.md')) {
            Copy-Item -LiteralPath (Join-Path $policySnapshot 'GEMINI.md') -Destination $AntigravityGemini -Force
        }
        if (Test-Path (Join-Path $policySnapshot 'rules')) {
            foreach ($r in (Get-ChildItem -LiteralPath (Join-Path $policySnapshot 'rules') -Filter '*.md' -File)) {
                Copy-Item -LiteralPath $r.FullName -Destination (Join-Path $AntigravityRules $r.Name) -Force
            }
        }
    }

    return 0
}

# --- Execution Gate ---
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

# Policy Sync Phase
if ($PoliciesOnly -or $Sync -or $Check) {
    $script:policyDrift = Invoke-OmniPolicySync -DryRun:(-not $Sync)
}

# Skill Sync Phase (4-Way Peer)
if (-not $PoliciesOnly) {
    $skillsArgs = @('-RepoRoot', $RepoRoot, '-SourceHarness', $SkillSource)
    if ($TargetSkill) { $skillsArgs += @('-TargetSkill', $TargetSkill) }
    if ($Sync) {
        $skillsArgs += @('-SyncGlobal', '-SyncWorkspace')
        if ($Force) { $skillsArgs += '-Force' }
        & pwsh -NoProfile -File $skillsScript @skillsArgs
        if ($LASTEXITCODE -ne 0) { throw '4-way skill synchronization failed.' }
    } else {
        $skillsArgs += @('-CheckOnly', '-ShowDiff')
        & pwsh -NoProfile -File $skillsScript @skillsArgs
        if ($LASTEXITCODE -ne 0) { $hasDrift = $true }
    }
}

if ($hasDrift) { exit 1 }

# Post-Sync Verification & Conventional Commit (when -Sync invoked)
if ($Sync) {
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host " [Step 3] Post-Synchronization Verification" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan

    $verification = @('-NoProfile', '-File', (Join-Path $PSScriptRoot 'sync.ps1'), '-Check', '-RepoRoot', $RepoRoot,
        '-PolicySource', 'Repository', '-AntigravityPolicy', $AntigravityPolicy,
        '-AntigravityGemini', $AntigravityGemini, '-AntigravityRules', $AntigravityRules,
        '-CopilotPolicy', $CopilotPolicy, '-CodexPolicy', $CodexPolicy, '-ClaudePolicy', $ClaudePolicy)
    if ($PoliciesOnly) { $verification += '-PoliciesOnly' }
    if ($TargetSkill) { $verification += @('-TargetSkill', $TargetSkill) }
    & pwsh @verification
    if ($LASTEXITCODE -ne 0) { throw 'Synchronization verification failed; no commit was made.' }

    $commitPaths = @('antigravity/policies', 'copilot/policies', 'codex/policies', 'claude/policies')
    if (-not $PoliciesOnly) {
        $commitPaths += @('antigravity/skills', 'copilot/skills', 'codex/skills', 'claude/skills')
    }
    $commitPaths = @($commitPaths | Where-Object { Test-Path -LiteralPath (Join-Path $RepoRoot $_) })
    git -C $RepoRoot diff --check -- @commitPaths
    if ($LASTEXITCODE -ne 0) { throw 'Whitespace validation failed; no commit was made.' }

    git -C $RepoRoot add -- @commitPaths
    if ($LASTEXITCODE -ne 0) { throw 'Could not stage synchronized files.' }

    git -C $RepoRoot diff --cached --quiet
    $indexStatus = $LASTEXITCODE
    if ($indexStatus -eq 0) {
        Write-Output 'Synchronization complete; no changes to commit.'
    } elseif ($indexStatus -eq 1) {
        git -C $RepoRoot diff --cached --stat
        git -C $RepoRoot commit -m 'chore(sync): synchronize shared skills and policies across 4 harnesses'
        if ($LASTEXITCODE -ne 0) { throw 'Commit failed; synchronization is incomplete. Review the staged changes.' }
        git -C $RepoRoot log -1 --format='%h %s'
    } else {
        throw 'Cannot inspect staged changes.'
    }
    git -C $RepoRoot status --short
    if ($LASTEXITCODE -ne 0) { throw 'Post-commit status verification failed.' }
}
