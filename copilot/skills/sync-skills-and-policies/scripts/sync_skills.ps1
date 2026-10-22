<#
.SYNOPSIS
    Omnidirectional 4-way synchronization of agent skills across Google Antigravity,
    GitHub Copilot, OpenAI Codex, and Claude Code (Global registries & Repository mirrors).
#>

[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [switch]$ShowDiff,
    [switch]$SyncGlobal,
    [switch]$SyncWorkspace,
    [ValidateSet("Auto", "Antigravity", "Copilot", "Codex", "Claude")]
    [string]$SourceHarness = "Auto",
    [string]$TargetSkill,
    [switch]$Force,
    [switch]$InstallToGlobal,
    [string]$AgyGlobal = (Join-Path $HOME ".gemini\config\skills"),
    [string]$CopGlobal = (Join-Path $HOME ".agents\skills"),
    [string]$CdxGlobal = (Join-Path $HOME ".codex\skills"),
    [string]$CldGlobal = (Join-Path $HOME ".claude\skills"),
    [string]$RepoRoot = $null
)

$ErrorActionPreference = "Stop"
$PreservedWorkspaceSkills = @("sync-skills-and-policies")
$ExcludedNames = @(".git", ".gitignore", "antigravity-sync-manifest.json", "sync-to-copilot.ps1")

# Auto-detect repository root if not provided
if (-not $RepoRoot) {
    $candidate = $PSScriptRoot
    while ($candidate -and -not (Test-Path (Join-Path $candidate ".git"))) {
        $parent = Split-Path -Parent $candidate
        if ($parent -eq $candidate) { break }
        $candidate = $parent
    }
    if ($candidate -and (Test-Path (Join-Path $candidate ".git"))) {
        $RepoRoot = $candidate
    } else {
        $RepoRoot = "c:\Users\hyunwookim\skills"
    }
}

$Harnesses = @(
    @{ Name = "Antigravity"; Global = $AgyGlobal; Repo = (Join-Path $RepoRoot "antigravity\skills"); Style = "Antigravity" },
    @{ Name = "Copilot";     Global = $CopGlobal; Repo = (Join-Path $RepoRoot "copilot\skills");     Style = "Copilot" },
    @{ Name = "Codex";       Global = $CdxGlobal; Repo = (Join-Path $RepoRoot "codex\skills");       Style = "NeutralCodex" },
    @{ Name = "Claude";      Global = $CldGlobal; Repo = (Join-Path $RepoRoot "claude\skills");      Style = "NeutralClaude" }
)

# ---------------------------------------------------------
# Helper: Interactive / Non-Interactive Conflict Resolver
# ---------------------------------------------------------
function Resolve-HarnessConflict {
    param(
        [string]$ItemType,
        [string]$ItemName,
        [hashtable]$Candidates
    )
    Write-Host "`n========================================================" -ForegroundColor Yellow
    Write-Host " [CONFLICT DETECTED] $ItemType '$ItemName' has divergent edits across harnesses:" -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    $i = 1
    $indexMap = @{}
    foreach ($h in @("Antigravity", "Copilot", "Codex", "Claude")) {
        if ($Candidates.ContainsKey($h)) {
            $info = $Candidates[$h]
            Write-Host "  [$i] $h (Modified: $($info.Time))`n      Path: $($info.Path)" -ForegroundColor Cyan
            $indexMap["$i"] = $h
            $i++
        }
    }
    Write-Host "  [S] Skip this $ItemType" -ForegroundColor DarkGray

    $isInteractive = [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
    if (-not $isInteractive) {
        $latest = ($Candidates.GetEnumerator() | Sort-Object { $_.Value.Time } -Descending | Select-Object -First 1).Key
        Write-Warning "Non-interactive shell: resolving conflict by selecting latest modified harness ($latest)."
        return $latest
    }

    while ($true) {
        $selection = Read-Host "Choose authoritative source [1-$($i-1)/S]"
        $selection = if ($selection) { $selection.Trim() } else { "" }
        if ($selection -eq "S" -or $selection -eq "s") { return $null }
        if ($indexMap.ContainsKey($selection)) {
            return $indexMap[$selection]
        }
        Write-Host "Invalid selection. Please enter a number between 1 and $($i-1) or 'S' to skip." -ForegroundColor Red
    }
}

# ---------------------------------------------------------
# Helper: Normalize content to canonical tokens for comparison
# ---------------------------------------------------------
function Normalize-SkillContentForComparison {
    param([string]$Content)
    $text = $Content.Replace("`r`n", "`n").Trim()

    # Normalize tools
    $text = $text.Replace("run_in_terminal", "__CMD_TOOL__")
    $text = $text.Replace("the available terminal tool", "__CMD_TOOL__")
    $text = $text.Replace("run_command", "__CMD_TOOL__")

    $text = $text.Replace("read_file", "__VIEW_TOOL__")
    $text = $text.Replace("the available file reader", "__VIEW_TOOL__")
    $text = $text.Replace("view_file", "__VIEW_TOOL__")

    # Normalize paths
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, '(?i)\.(gemini[\\/]config|agents|codex|claude)[\\/]skills', '__SKILLS_DIR__')
    $text = [System.Text.RegularExpressions.Regex]::Replace($text, '(?i)(antigravity|copilot|codex|claude)[\\/]skills', '__REPO_SKILLS_DIR__')

    return $text
}

# ---------------------------------------------------------
# Helper: Transform content between harness styles
# ---------------------------------------------------------
function Transform-SkillContent {
    param(
        [string]$Content,
        [string]$TargetStyle
    )
    $text = Normalize-SkillContentForComparison -Content $Content

    switch ($TargetStyle) {
        "Antigravity" {
            $text = $text.Replace("__CMD_TOOL__", "run_command")
            $text = $text.Replace("__VIEW_TOOL__", "view_file")
            $text = $text.Replace("__SKILLS_DIR__", ".gemini/config/skills")
            $text = $text.Replace("__REPO_SKILLS_DIR__", "antigravity/skills")
        }
        "Copilot" {
            $text = $text.Replace("__CMD_TOOL__", "run_in_terminal")
            $text = $text.Replace("__VIEW_TOOL__", "read_file")
            $text = $text.Replace("__SKILLS_DIR__", ".agents/skills")
            $text = $text.Replace("__REPO_SKILLS_DIR__", "copilot/skills")
        }
        "NeutralCodex" {
            $text = $text.Replace("__CMD_TOOL__", "the available terminal tool")
            $text = $text.Replace("__VIEW_TOOL__", "the available file reader")
            $text = $text.Replace("__SKILLS_DIR__", ".codex/skills")
            $text = $text.Replace("__REPO_SKILLS_DIR__", "codex/skills")
        }
        "NeutralClaude" {
            $text = $text.Replace("__CMD_TOOL__", "the available terminal tool")
            $text = $text.Replace("__VIEW_TOOL__", "the available file reader")
            $text = $text.Replace("__SKILLS_DIR__", ".claude/skills")
            $text = $text.Replace("__REPO_SKILLS_DIR__", "claude/skills")
        }
    }
    return $text.Trim() + "`n"
}

# ---------------------------------------------------------
# Helper: Copy skill folder with transformation
# ---------------------------------------------------------
function Copy-SkillTreeOmni {
    param(
        [string]$SourceDir,
        [string]$TargetDir,
        [string]$TargetStyle
    )
    if (-not (Test-Path -LiteralPath $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    $files = Get-ChildItem -LiteralPath $SourceDir -Recurse -File | Where-Object {
        $ExcludedNames -notcontains $_.Name
    }

    foreach ($f in $files) {
        $rel = $f.FullName.Substring($SourceDir.Length).TrimStart("\", "/")
        $dest = Join-Path $TargetDir $rel
        $destDir = Split-Path -Parent $dest
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        if ($f.Extension -eq ".md") {
            $raw = [System.IO.File]::ReadAllText($f.FullName)
            $transformed = Transform-SkillContent -Content $raw -TargetStyle $TargetStyle
            [System.IO.File]::WriteAllText($dest, $transformed, [System.Text.UTF8Encoding]::new($false))
        } else {
            Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
        }
    }
}

# ---------------------------------------------------------
# Task 1: Audit Global Skills Across All 4 Harnesses
# ---------------------------------------------------------
function Audit-GlobalSkillsOmni {
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host " [Step 1] Auditing Global Skills (4-Way Peer Mesh)" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan

    $allSkills = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($h in $Harnesses) {
        if (Test-Path -LiteralPath $h.Global) {
            foreach ($dir in (Get-ChildItem -LiteralPath $h.Global -Directory)) {
                if ($dir.Name -notmatch '^\.') {
                    $allSkills.Add($dir.Name) | Out-Null
                }
            }
        }
    }

    $skillList = @($allSkills) | Sort-Object
    if ($TargetSkill) { $skillList = @($skillList | Where-Object { $_ -eq $TargetSkill }) }

    Write-Host "Total unique shared skills discovered: $($skillList.Count)" -ForegroundColor Gray

    $divergent = @{}
    $missingMap = @{}
    $inSync = @()

    foreach ($s in $skillList) {
        $presentIn = @()
        $missingIn = @()
        foreach ($h in $Harnesses) {
            $skillPath = Join-Path $h.Global $s
            if (Test-Path -LiteralPath $skillPath) {
                $presentIn += $h
            } else {
                $missingIn += $h
            }
        }

        if ($missingIn.Count -gt 0) {
            $missingMap[$s] = @{ Present = $presentIn; Missing = $missingIn }
        }

        # Check content equality across present harnesses
        if ($presentIn.Count -gt 1) {
            $baseHarness = $presentIn[0]
            $baseDir = Join-Path $baseHarness.Global $s
            $baseFiles = Get-ChildItem -LiteralPath $baseDir -Recurse -File | Where-Object { $ExcludedNames -notcontains $_.Name }

            $isSkillDivergent = $false

            foreach ($otherHarness in $presentIn[1..($presentIn.Count - 1)]) {
                $otherDir = Join-Path $otherHarness.Global $s
                $otherFiles = Get-ChildItem -LiteralPath $otherDir -Recurse -File | Where-Object { $ExcludedNames -notcontains $_.Name }

                if ($baseFiles.Count -ne $otherFiles.Count) {
                    $isSkillDivergent = $true
                } else {
                    foreach ($bf in $baseFiles) {
                        $rel = $bf.FullName.Substring($baseDir.Length).TrimStart("\", "/")
                        $ofPath = Join-Path $otherDir $rel
                        if (-not (Test-Path -LiteralPath $ofPath)) {
                            $isSkillDivergent = $true
                            break
                        }
                        if ($bf.Extension -eq ".md") {
                            $bNorm = Normalize-SkillContentForComparison -Content ([System.IO.File]::ReadAllText($bf.FullName))
                            $oNorm = Normalize-SkillContentForComparison -Content ([System.IO.File]::ReadAllText($ofPath))
                            if ($bNorm -ne $oNorm) {
                                $isSkillDivergent = $true
                                break
                            }
                        } else {
                            $bHash = (Get-FileHash -LiteralPath $bf.FullName -Algorithm SHA256).Hash
                            $oHash = (Get-FileHash -LiteralPath $ofPath -Algorithm SHA256).Hash
                            if ($bHash -ne $oHash) {
                                $isSkillDivergent = $true
                                break
                            }
                        }
                    }
                }
                if ($isSkillDivergent) { break }
            }

            if ($isSkillDivergent) {
                $cand = @{}
                foreach ($h in $presentIn) {
                    $hDir = Join-Path $h.Global $s
                    $maxTime = (Get-ChildItem -LiteralPath $hDir -Recurse -File | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1).LastWriteTime
                    $cand[$h.Name] = @{ Time = $maxTime; Path = $hDir; Harness = $h }
                }
                $divergent[$s] = $cand
                Write-Host "  [DIFF DETECTED] Skill '$s' diverges across: $($presentIn.Name -join ', ')" -ForegroundColor Yellow
            } else {
                if ($missingIn.Count -eq 0) {
                    Write-Host "  [OK] Skill '$s' is in sync across all 4 harnesses" -ForegroundColor Green
                    $inSync += $s
                } else {
                    Write-Host "  [PARTIAL] Skill '$s' is in sync across ($($presentIn.Name -join ', ')), but missing in: $($missingIn.Name -join ', ')" -ForegroundColor Yellow
                }
            }
        } elseif ($presentIn.Count -eq 1) {
            Write-Host "  [NEW] Skill '$s' only exists in $($presentIn[0].Name)" -ForegroundColor Magenta
        }
    }

    return @{
        Skills = $skillList
        Divergent = $divergent
        Missing = $missingMap
        InSync = $inSync
    }
}

# ---------------------------------------------------------
# Task 1 Execution: 4-Way Sync Global Skills
# ---------------------------------------------------------
function Sync-GlobalSkillsOmni {
    param($AuditResult)

    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host " [Step 1 Execution] Syncing Global Skills Across 4 Peers" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan

    # 1. Resolve Divergent Skills
    foreach ($s in $AuditResult.Divergent.Keys) {
        $cand = $AuditResult.Divergent[$s]
        $selectedSource = if ($SourceHarness -ne "Auto" -and $cand.ContainsKey($SourceHarness)) {
            $SourceHarness
        } else {
            Resolve-HarnessConflict -ItemType "Skill" -ItemName $s -Candidates $cand
        }

        if (-not $selectedSource) {
            Write-Warning "Skipped divergent skill '$s'."
            continue
        }

        $sourceInfo = $cand[$selectedSource]
        Write-Host "Propagating authoritative skill '$s' from $selectedSource to all other harnesses..." -ForegroundColor Green

        foreach ($h in $Harnesses) {
            if ($h.Name -ne $selectedSource) {
                $targetDir = Join-Path $h.Global $s
                Copy-SkillTreeOmni -SourceDir $sourceInfo.Path -TargetDir $targetDir -TargetStyle $h.Style
            }
        }
    }

    # 2. Propagate Missing Skills
    foreach ($s in $AuditResult.Missing.Keys) {
        if ($AuditResult.Divergent.ContainsKey($s)) { continue }
        $info = $AuditResult.Missing[$s]
        $sourceHarness = $info.Present[0]
        $sourceDir = Join-Path $sourceHarness.Global $s

        Write-Host "Deploying skill '$s' from $($sourceHarness.Name) to: $($info.Missing.Name -join ', ')..." -ForegroundColor Green
        foreach ($targetHarness in $info.Missing) {
            $targetDir = Join-Path $targetHarness.Global $s
            Copy-SkillTreeOmni -SourceDir $sourceDir -TargetDir $targetDir -TargetStyle $targetHarness.Style
        }
    }
}

# ---------------------------------------------------------
# Task 2: Audit Workspace vs Global Across 4 Harnesses
# ---------------------------------------------------------
function Audit-WorkspaceMirrorsOmni {
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host " [Step 2 Audit] Comparing Workspace Mirrors vs Global Roots (4 Harnesses)" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan

    $totalDiffs = 0
    foreach ($h in $Harnesses) {
        Write-Host "`n--- $($h.Name) Global vs Repo ($($h.Repo)) ---" -ForegroundColor Gray
        if (-not (Test-Path $h.Repo)) {
            Write-Host "  Repo folder does not exist: $($h.Repo)" -ForegroundColor Red
            $totalDiffs++
            continue
        }
        if (-not (Test-Path $h.Global)) {
            Write-Host "  Global folder does not exist: $($h.Global)" -ForegroundColor Red
            $totalDiffs++
            continue
        }

        $gFiles = Get-ChildItem -LiteralPath $h.Global -Recurse -File | Where-Object {
            $rel = $_.FullName.Substring($h.Global.Length).TrimStart("\", "/")
            $rel -notmatch "^\.git[\\/]" -and $rel -notmatch "^\.system[\\/]" -and $_.Name -ne 'antigravity-sync-manifest.json' -and
            (-not $TargetSkill -or ($rel -split "[\\/]")[0] -eq $TargetSkill)
        }
        $rFiles = Get-ChildItem -LiteralPath $h.Repo -Recurse -File | Where-Object {
            $rel = $_.FullName.Substring($h.Repo.Length).TrimStart("\", "/")
            $rel -notmatch "^\.git[\\/]" -and $rel -notmatch "^\.system[\\/]" -and $_.Name -ne 'antigravity-sync-manifest.json' -and
            (-not $TargetSkill -or ($rel -split "[\\/]")[0] -eq $TargetSkill)
        }

        $gRel = @($gFiles | ForEach-Object { $_.FullName.Substring($h.Global.Length).TrimStart("\", "/").Replace("\", "/") })
        $rRel = @($rFiles | ForEach-Object { $_.FullName.Substring($h.Repo.Length).TrimStart("\", "/").Replace("\", "/") })

        $missingInRepo = @($gRel | Where-Object { $rRel -notcontains $_ })
        $extraInRepo = @($rRel | Where-Object {
            $r = $_
            $skillName = ($r -split "[\\/]")[0]
            $gRel -notcontains $r -and $PreservedWorkspaceSkills -notcontains $skillName
        })
        $common = @($gRel | Where-Object { $rRel -contains $_ })

        $modified = @()
        foreach ($f in $common) {
            $gPath = Join-Path $h.Global $f
            $rPath = Join-Path $h.Repo $f
            if ((Get-FileHash -LiteralPath $gPath -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $rPath -Algorithm SHA256).Hash) {
                $modified += $f
            }
        }

        if ($missingInRepo.Count -gt 0) {
            Write-Host "  [+] Missing in Repo ($($missingInRepo.Count)): $($missingInRepo -join ', ')" -ForegroundColor Yellow
            $totalDiffs += $missingInRepo.Count
        }
        if ($extraInRepo.Count -gt 0) {
            Write-Host "  [-] Extra in Repo ($($extraInRepo.Count)): $($extraInRepo -join ', ')" -ForegroundColor Magenta
            $totalDiffs += $extraInRepo.Count
        }
        if ($modified.Count -gt 0) {
            Write-Host "  [~] Modified ($($modified.Count)): $($modified -join ', ')" -ForegroundColor Cyan
            $totalDiffs += $modified.Count
        }
        if ($missingInRepo.Count -eq 0 -and $extraInRepo.Count -eq 0 -and $modified.Count -eq 0) {
            Write-Host "  [OK] Workspace mirror is perfectly in sync ($($common.Count) files)" -ForegroundColor Green
        }
    }
    return $totalDiffs
}

# ---------------------------------------------------------
# Task 2 Execution: Sync Workspace Mirrors
# ---------------------------------------------------------
function Sync-WorkspaceMirrorsOmni {
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host " [Step 2 Execution] Syncing Workspace Folders with Actual Global Skills" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan

    foreach ($h in $Harnesses) {
        if (-not (Test-Path -LiteralPath $h.Global)) { continue }
        if (-not (Test-Path -LiteralPath $h.Repo)) {
            New-Item -ItemType Directory -Path $h.Repo -Force | Out-Null
        }

        $gSkills = Get-ChildItem -LiteralPath $h.Global -Directory | Where-Object { $_.Name -notmatch '^\.' }
        if ($TargetSkill) {
            $gSkills = @($gSkills | Where-Object { $_.Name -eq $TargetSkill })
        }
        foreach ($s in $gSkills) {
            $srcDir = $s.FullName
            $tgtDir = Join-Path $h.Repo $s.Name
            Copy-SkillTreeOmni -SourceDir $srcDir -TargetDir $tgtDir -TargetStyle $h.Style
        }
    }
    Write-Host "All 4 workspace repository mirrors updated from global skills." -ForegroundColor Green
}

# --- Main Entry Point ---
$audit = Audit-GlobalSkillsOmni

if ($SyncGlobal) {
    Sync-GlobalSkillsOmni -AuditResult $audit
}

if ($SyncWorkspace) {
    Sync-WorkspaceMirrorsOmni
}

$mirrorDiffs = Audit-WorkspaceMirrorsOmni

if ($CheckOnly) {
    $driftCount = $audit.Divergent.Count + $audit.Missing.Count + $mirrorDiffs
    if ($driftCount -gt 0) {
        Write-Warning "Total skill drift items detected: $driftCount"
        exit 1
    } else {
        Write-Host "`n[CheckOnly Mode] All 4 harnesses are 100% in sync." -ForegroundColor Green
    }
}
