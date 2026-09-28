<#
.SYNOPSIS
    Synchronizes agent skills between Google Antigravity and GitHub Copilot global registries,
    detects and reports differences before merging, and syncs workspace mirrors with actual global directories.

.DESCRIPTION
    Provides automated audit, diffing, transformation, and synchronization across:
    1. Machine-global Antigravity skills (~/.gemini/config/skills)
    2. Machine-global GitHub Copilot skills (~/.agents/skills)
    3. Workspace repository mirrors (antigravity/skills and copilot/skills)

    Ensures tool compatibility transformation (run_command <-> run_in_terminal, view_file <-> read_file),
    normalizes paths, computes SHA-256 verification manifests, and generates clear unified diffs
    whenever shared skills diverge between environments.

.PARAMETER CheckOnly
    Audits directories and outputs status without making any file modifications.

.PARAMETER ShowDiff
    Displays unified diffs for any shared skills that have diverged between Antigravity and Copilot.

.PARAMETER SyncGlobal
    Synchronizes global skills between Antigravity and Copilot roots.
    If a shared skill has conflicting edits, it is skipped unless -Force is specified.

.PARAMETER SyncWorkspace
    Synchronizes this repository's antigravity/skills and copilot/skills folders
    with the actual global directories on the local machine.

.PARAMETER Direction
    Direction for global sync: 'Both' (default), 'AgyToCop', or 'CopToAgy'.

.PARAMETER TargetSkill
    Limits audit or synchronization to a specific skill folder name.

.PARAMETER Force
    Allows overwriting divergent files during global sync without interactive prompt.

.EXAMPLE
    .\sync_skills.ps1 -CheckOnly -ShowDiff
    Audits both global and workspace trees and displays diffs for any conflicting skills.

.EXAMPLE
    .\sync_skills.ps1 -SyncGlobal
    Synchronizes additions between Antigravity and Copilot global registries.

.EXAMPLE
    .\sync_skills.ps1 -SyncWorkspace
    Mirrors actual global skills into the workspace repository.
#>

[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [switch]$ShowDiff,
    [switch]$SyncGlobal,
    [switch]$SyncWorkspace,
    [ValidateSet("Both", "AgyToCop", "CopToAgy")]
    [string]$Direction = "Both",
    [string]$TargetSkill,
    [switch]$Force,
    [switch]$InstallToGlobal,
    [string]$AgyGlobal = (Join-Path $HOME ".gemini\config\skills"),
    [string]$CopGlobal = (Join-Path $HOME ".agents\skills"),
    [string]$RepoRoot = $null
)

$ErrorActionPreference = "Stop"
$PreservedWorkspaceSkills = @("sync-skills-and-policies")

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

$AgyRepo = Join-Path $RepoRoot "antigravity\skills"
$CopRepo = Join-Path $RepoRoot "copilot\skills"
$ExcludedNames = @(".git", ".gitignore", "antigravity-sync-manifest.json", "sync-to-copilot.ps1")

# ---------------------------------------------------------
# Helper: Normalize markdown text for semantic comparison
# ---------------------------------------------------------
function Normalize-MarkdownForComparison {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Agy", "Cop")]
        [string]$SourceType
    )
    $text = $Content.Replace("`r`n", "`n").Trim()
    if ($SourceType -eq "Cop") {
        # Translate Copilot tools & specific script paths to Antigravity conventions for comparison
        $text = $text.Replace("run_in_terminal", "run_command")
        $text = $text.Replace("read_file", "view_file")
        $text = $text.Replace(".agents\skills\sync-skills\scripts\sync_skills.ps1", ".gemini\config\skills\sync-skills\scripts\sync_skills.ps1")
        $text = $text.Replace(".agents/skills/sync-skills/scripts/sync_skills.ps1", ".gemini/config/skills/sync-skills/scripts/sync_skills.ps1")
        $text = $text.Replace(".agents\skills\sequential-image-extractor\scripts\sort_images.py", ".gemini\config\skills\sequential-image-extractor\scripts\sort_images.py")
        $text = $text.Replace(".agents/skills/sequential-image-extractor/scripts/sort_images.py", ".gemini/config/skills/sequential-image-extractor/scripts/sort_images.py")
    }
    return $text
}

# ---------------------------------------------------------
# Helper: Transform content between environments
# ---------------------------------------------------------
function Transform-SkillFileContent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [ValidateSet("AgyToCop", "CopToAgy")]
        [string]$Mode
    )
    $result = $Content
    if ($Mode -eq "AgyToCop") {
        $result = $result.Replace("run_command", "run_in_terminal")
        $result = $result.Replace("view_file", "read_file")
        $result = $result.Replace(".gemini\config\skills\sync-skills\scripts\sync_skills.ps1", ".agents\skills\sync-skills\scripts\sync_skills.ps1")
        $result = $result.Replace(".gemini/config/skills/sync-skills/scripts/sync_skills.ps1", ".agents/skills/sync-skills/scripts/sync_skills.ps1")
        $result = $result.Replace(".gemini\config\skills\sequential-image-extractor\scripts\sort_images.py", ".agents\skills\sequential-image-extractor\scripts\sort_images.py")
        $result = $result.Replace(".gemini/config/skills/sequential-image-extractor/scripts/sort_images.py", ".agents/skills/sequential-image-extractor/scripts/sort_images.py")
    } elseif ($Mode -eq "CopToAgy") {
        $result = $result.Replace("run_in_terminal", "run_command")
        $result = $result.Replace("read_file", "view_file")
        $result = $result.Replace(".agents\skills\sync-skills\scripts\sync_skills.ps1", ".gemini\config\skills\sync-skills\scripts\sync_skills.ps1")
        $result = $result.Replace(".agents/skills/sync-skills/scripts/sync_skills.ps1", ".gemini/config/skills/sync-skills/scripts/sync_skills.ps1")
        $result = $result.Replace(".agents\skills\sequential-image-extractor\scripts\sort_images.py", ".gemini\config\skills\sequential-image-extractor\scripts\sort_images.py")
        $result = $result.Replace(".agents/skills/sequential-image-extractor/scripts/sort_images.py", ".gemini/config/skills/sequential-image-extractor/scripts/sort_images.py")
    }
    return $result
}

# ---------------------------------------------------------
# Task 1: Audit & Compare Global Skills
# ---------------------------------------------------------
function Audit-GlobalSkills {
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host " [Step 1] Auditing Global Skills (Antigravity <-> Copilot)" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "Antigravity Global Root : $AgyGlobal"
    Write-Host "Copilot Global Root     : $CopGlobal"

    if (-not (Test-Path $AgyGlobal)) {
        Write-Error "Antigravity global directory not found: $AgyGlobal"
        return $null
    }
    if (-not (Test-Path $CopGlobal)) {
        Write-Error "Copilot global directory not found: $CopGlobal"
        return $null
    }

    $agySkills = @(Get-ChildItem -LiteralPath $AgyGlobal -Directory | Select-Object -ExpandProperty Name)
    $copSkills = @(Get-ChildItem -LiteralPath $CopGlobal -Directory | Select-Object -ExpandProperty Name)

    if ($TargetSkill) {
        $agySkills = @($agySkills | Where-Object { $_ -eq $TargetSkill })
        $copSkills = @($copSkills | Where-Object { $_ -eq $TargetSkill })
    }

    $allSkills = @($agySkills + $copSkills) | Select-Object -Unique | Sort-Object

    $shared = @()
    $onlyAgy = @()
    $onlyCop = @()

    foreach ($s in $allSkills) {
        $inAgy = $agySkills -contains $s
        $inCop = $copSkills -contains $s
        if ($inAgy -and $inCop) {
            $shared += $s
        } elseif ($inAgy) {
            $onlyAgy += $s
        } else {
            $onlyCop += $s
        }
    }

    Write-Host "`nSummary of Global Skills:" -ForegroundColor Gray
    Write-Host "  Shared Skills       ($($shared.Count)) : $($shared -join ', ')" -ForegroundColor Green
    Write-Host "  Only in Antigravity ($($onlyAgy.Count)) : $($onlyAgy -join ', ')" -ForegroundColor Yellow
    Write-Host "  Only in Copilot     ($($onlyCop.Count)) : $($onlyCop -join ', ')" -ForegroundColor Yellow

    $divergent = @{}

    foreach ($s in $shared) {
        $sAgyDir = Join-Path $AgyGlobal $s
        $sCopDir = Join-Path $CopGlobal $s

        $aFiles = Get-ChildItem -LiteralPath $sAgyDir -Recurse -File | Where-Object {
            $ExcludedNames -notcontains $_.Name
        }
        $cFiles = Get-ChildItem -LiteralPath $sCopDir -Recurse -File | Where-Object {
            $ExcludedNames -notcontains $_.Name
        }

        $skillDiffs = @()

        foreach ($af in $aFiles) {
            $rel = $af.FullName.Substring($sAgyDir.Length).TrimStart("\", "/")
            $cfPath = Join-Path $sCopDir $rel

            if (-not (Test-Path -LiteralPath $cfPath)) {
                $skillDiffs += [PSCustomObject]@{
                    Skill = $s
                    RelativePath = $rel
                    Status = "MissingInCopilot"
                    AgyPath = $af.FullName
                    CopPath = $cfPath
                }
            } else {
                if ($af.Extension -eq ".md") {
                    $aContent = Get-Content -LiteralPath $af.FullName -Raw
                    $cContent = Get-Content -LiteralPath $cfPath -Raw
                    $aNorm = Normalize-MarkdownForComparison -Content $aContent -SourceType "Agy"
                    $cNorm = Normalize-MarkdownForComparison -Content $cContent -SourceType "Cop"
                    if ($aNorm -ne $cNorm) {
                        $skillDiffs += [PSCustomObject]@{
                            Skill = $s
                            RelativePath = $rel
                            Status = "ContentDivergence"
                            AgyPath = $af.FullName
                            CopPath = $cfPath
                        }
                    }
                } else {
                    $aHash = (Get-FileHash -LiteralPath $af.FullName -Algorithm SHA256).Hash
                    $cHash = (Get-FileHash -LiteralPath $cfPath -Algorithm SHA256).Hash
                    if ($aHash -ne $cHash) {
                        $skillDiffs += [PSCustomObject]@{
                            Skill = $s
                            RelativePath = $rel
                            Status = "BinaryMismatch"
                            AgyPath = $af.FullName
                            CopPath = $cfPath
                        }
                    }
                }
            }
        }

        foreach ($cf in $cFiles) {
            $rel = $cf.FullName.Substring($sCopDir.Length).TrimStart("\", "/")
            $afPath = Join-Path $sAgyDir $rel
            if (-not (Test-Path -LiteralPath $afPath)) {
                $skillDiffs += [PSCustomObject]@{
                    Skill = $s
                    RelativePath = $rel
                    Status = "MissingInAntigravity"
                    AgyPath = $afPath
                    CopPath = $cf.FullName
                }
            }
        }

        if ($skillDiffs.Count -gt 0) {
            $divergent[$s] = $skillDiffs
            Write-Host "`n  [DIFF DETECTED] Skill '$s' has differences between Antigravity and Copilot:" -ForegroundColor Yellow
            foreach ($d in $skillDiffs) {
                Write-Host "    - $($d.RelativePath) [$($d.Status)]" -ForegroundColor Red
            }

            if ($ShowDiff) {
                foreach ($d in $skillDiffs) {
                    if ($d.Status -eq "ContentDivergence") {
                        Write-Host "`n    --- Diff for $($d.Skill)/$($d.RelativePath) ---" -ForegroundColor Cyan
                        $tmpA = [System.IO.Path]::GetTempFileName()
                        $tmpC = [System.IO.Path]::GetTempFileName()
                        try {
                            $aContent = Get-Content -LiteralPath $d.AgyPath -Raw
                            $cContent = Get-Content -LiteralPath $d.CopPath -Raw
                            Normalize-MarkdownForComparison -Content $aContent -SourceType "Agy" | Set-Content -LiteralPath $tmpA -Encoding utf8NoBOM
                            Normalize-MarkdownForComparison -Content $cContent -SourceType "Cop" | Set-Content -LiteralPath $tmpC -Encoding utf8NoBOM
                            git diff --no-index --color=always "$tmpA" "$tmpC"
                        } finally {
                            Remove-Item -LiteralPath $tmpA, $tmpC -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
            }
        } else {
            Write-Host "  [OK] Skill '$s' is in sync" -ForegroundColor Green
        }
    }

    return @{
        Shared = $shared
        OnlyAgy = $onlyAgy
        OnlyCop = $onlyCop
        Divergent = $divergent
    }
}

# ---------------------------------------------------------
# Helper: Sync an individual skill from Source to Target
# ---------------------------------------------------------
function Copy-SkillTree {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourceDir,
        [Parameter(Mandatory=$true)]
        [string]$TargetDir,
        [Parameter(Mandatory=$true)]
        [ValidateSet("AgyToCop", "CopToAgy", "Direct")]
        [string]$Mode
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

        if ($Mode -eq "Direct") {
            Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
        } elseif ($f.Extension -eq ".md") {
            $raw = Get-Content -LiteralPath $f.FullName -Raw
            $transformed = Transform-SkillFileContent -Content $raw -Mode $Mode
            Set-Content -LiteralPath $dest -Value $transformed -Encoding utf8NoBOM
        } else {
            Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
        }
    }
}

# ---------------------------------------------------------
# Task 1 Execution: Sync Global Skills
# ---------------------------------------------------------
function Sync-GlobalSkills {
    param($AuditResult)

    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host " [Step 1 Execution] Syncing Global Skills" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan

    # Check for divergence
    if ($AuditResult.Divergent.Count -gt 0 -and -not $Force) {
        Write-Warning "Divergence detected in $($AuditResult.Divergent.Count) shared skill(s). Skipping merge for conflicting skills until user reviews diffs."
        Write-Host "Use -ShowDiff to review changes or -Force to overwrite." -ForegroundColor Yellow
    }

    # 1. Antigravity -> Copilot additions
    if ($Direction -in @("Both", "AgyToCop")) {
        foreach ($s in $AuditResult.OnlyAgy) {
            Write-Host "Syncing Antigravity skill '$s' -> Copilot..." -ForegroundColor Green
            $src = Join-Path $AgyGlobal $s
            $tgt = Join-Path $CopGlobal $s
            Copy-SkillTree -SourceDir $src -TargetDir $tgt -Mode "AgyToCop"
        }
    }

    # 2. Copilot -> Antigravity additions
    if ($Direction -in @("Both", "CopToAgy")) {
        foreach ($s in $AuditResult.OnlyCop) {
            Write-Host "Syncing Copilot skill '$s' -> Antigravity..." -ForegroundColor Green
            $src = Join-Path $CopGlobal $s
            $tgt = Join-Path $AgyGlobal $s
            Copy-SkillTree -SourceDir $src -TargetDir $tgt -Mode "CopToAgy"
        }
    }

    # 3. If Force is specified, overwrite divergent skills according to Direction
    if ($Force -and $AuditResult.Divergent.Count -gt 0) {
        foreach ($s in $AuditResult.Divergent.Keys) {
            Write-Host "Forcing overwrite for divergent skill '$s' (Direction: $Direction)..." -ForegroundColor Magenta
            if ($Direction -eq "AgyToCop") {
                Copy-SkillTree -SourceDir (Join-Path $AgyGlobal $s) -TargetDir (Join-Path $CopGlobal $s) -Mode "AgyToCop"
            } elseif ($Direction -eq "CopToAgy") {
                Copy-SkillTree -SourceDir (Join-Path $CopGlobal $s) -TargetDir (Join-Path $AgyGlobal $s) -Mode "CopToAgy"
            } else {
                Write-Warning "Cannot force bidirectional sync on divergent skill '$s'. Specify -Direction AgyToCop or CopToAgy."
            }
        }
    }

    # 4. Update manifest in Copilot global
    Update-SyncManifest -SourceRoot $AgyGlobal -TargetRoot $CopGlobal
}

# ---------------------------------------------------------
# Helper: Update antigravity-sync-manifest.json
# ---------------------------------------------------------
function Update-SyncManifest {
    param(
        [string]$SourceRoot,
        [string]$TargetRoot
    )
    $manifestPath = Join-Path $TargetRoot "antigravity-sync-manifest.json"
    $sourceFiles = Get-ChildItem -LiteralPath $SourceRoot -File -Recurse | Where-Object {
        $rel = $_.FullName.Substring($SourceRoot.Length).TrimStart("\", "/")
        $_.Name -ne "README.md" -and
            $ExcludedNames -notcontains $_.Name -and
            $rel -notmatch "^\.git[\\/]"
    }

    $entries = foreach ($sf in $sourceFiles) {
        $rel = $sf.FullName.Substring($SourceRoot.Length).TrimStart("\", "/").Replace("\", "/")
        [ordered]@{
            path = $rel
            source_sha256 = (Get-FileHash -LiteralPath $sf.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            copilot_path = $rel
        }
    }

    $manifest = [ordered]@{
        format = 1
        source = (Resolve-Path $SourceRoot).Path
        target = (Resolve-Path $TargetRoot).Path
        synced_at_utc = (Get-Date).ToUniversalTime().ToString("o")
        compatibility = @{
            "view_file" = "read_file"
            "run_command" = "run_in_terminal"
        }
        files = @($entries)
    }

    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
    Write-Host "Updated sync manifest: $manifestPath" -ForegroundColor Green
}

# ---------------------------------------------------------
# Task 2: Audit Workspace vs Actual Global Folders
# ---------------------------------------------------------
function Audit-WorkspaceMirrors {
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host " [Step 2 Audit] Comparing Workspace Mirrors vs Global Folders" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan

    function Compare-DirPair {
        param([string]$GlobalDir, [string]$RepoDir, [string]$Title)
        Write-Host "`n--- $Title ---" -ForegroundColor Gray
        if (-not (Test-Path $RepoDir)) {
            Write-Host "  Repo folder does not exist: $RepoDir" -ForegroundColor Red
            return
        }

        $gFiles = Get-ChildItem -LiteralPath $GlobalDir -Recurse -File | Where-Object {
            $rel = $_.FullName.Substring($GlobalDir.Length).TrimStart("\", "/")
            $rel -notmatch "^\.git[\\/]" -and $_.Name -ne 'antigravity-sync-manifest.json'
        }
        $rFiles = Get-ChildItem -LiteralPath $RepoDir -Recurse -File | Where-Object {
            $rel = $_.FullName.Substring($RepoDir.Length).TrimStart("\", "/")
            $rel -notmatch "^\.git[\\/]" -and $_.Name -ne 'antigravity-sync-manifest.json'
        }

        $gRel = $gFiles | ForEach-Object { $_.FullName.Substring($GlobalDir.Length).TrimStart("\", "/").Replace("\", "/") }
        $rRel = $rFiles | ForEach-Object { $_.FullName.Substring($RepoDir.Length).TrimStart("\", "/").Replace("\", "/") }

        $missingInRepo = $gRel | Where-Object { $rRel -notcontains $_ }
        $extraInRepo = $rRel | Where-Object {
            $r = $_
            $skillName = ($r -split "[\\/]")[0]
            $gRel -notcontains $r -and $PreservedWorkspaceSkills -notcontains $skillName
        }
        $common = $gRel | Where-Object { $rRel -contains $_ }

        $modified = @()
        foreach ($f in $common) {
            $gPath = Join-Path $GlobalDir $f
            $rPath = Join-Path $RepoDir $f
            $gHash = (Get-FileHash -LiteralPath $gPath -Algorithm SHA256).Hash
            $rHash = (Get-FileHash -LiteralPath $rPath -Algorithm SHA256).Hash
            if ($gHash -ne $rHash) {
                $modified += $f
            }
        }

        if ($missingInRepo) {
            Write-Host "  [+] Missing in Workspace Repo ($($missingInRepo.Count)): $($missingInRepo -join ', ')" -ForegroundColor Yellow
        }
        if ($extraInRepo) {
            Write-Host "  [-] Extra in Workspace Repo ($($extraInRepo.Count)): $($extraInRepo -join ', ')" -ForegroundColor Magenta
        }
        if ($modified) {
            Write-Host "  [~] Modified in Global vs Workspace ($($modified.Count)): $($modified -join ', ')" -ForegroundColor Cyan
        }
        if (-not $missingInRepo -and -not $extraInRepo -and -not $modified) {
            Write-Host "  [OK] Workspace mirror is perfectly in sync ($($common.Count) files)" -ForegroundColor Green
        }
    }

    Compare-DirPair -GlobalDir $AgyGlobal -RepoDir $AgyRepo -Title "Antigravity Global vs Repo antigravity/skills"
    Compare-DirPair -GlobalDir $CopGlobal -RepoDir $CopRepo -Title "Copilot Global vs Repo copilot/skills"
}

# ---------------------------------------------------------
# Task 2: Sync Workspace Mirrors with Actual Global Folders
# ---------------------------------------------------------
function Sync-WorkspaceMirrors {
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host " [Step 2 Execution] Syncing Workspace Folders with Actual Global Skills" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "Workspace Root           : $RepoRoot"
    Write-Host "Repo .gemini/config/skills: $AgyRepo"
    Write-Host "Repo .agents/skills       : $CopRepo"

    if (-not (Test-Path $RepoRoot)) {
        Write-Error "Workspace repository root not found: $RepoRoot"
        return
    }

    # Optional: Install workspace skills to global first if requested
    if ($InstallToGlobal) {
        Write-Host "`nInstalling workspace skills to global registries..." -ForegroundColor Green
        Copy-SkillTree -SourceDir (Join-Path $AgyRepo "sync-skills-and-policies") -TargetDir (Join-Path $AgyGlobal "sync-skills-and-policies") -Mode "Direct"
        Copy-SkillTree -SourceDir (Join-Path $CopRepo "sync-skills-and-policies") -TargetDir (Join-Path $CopGlobal "sync-skills-and-policies") -Mode "Direct"
        Write-Host "sync-skills installed to global registries." -ForegroundColor Green
    }

    # 1. Sync Antigravity Global -> Workspace .gemini/config/skills
    Write-Host "`nSyncing Antigravity Global -> Workspace .gemini/config/skills..." -ForegroundColor Cyan
    $agyGlobalFiles = Get-ChildItem -LiteralPath $AgyGlobal -Recurse -File | Where-Object {
        $rel = $_.FullName.Substring($AgyGlobal.Length).TrimStart("\", "/")
        $rel -notmatch "^\.git[\\/]"
    }

    foreach ($f in $agyGlobalFiles) {
        $rel = $f.FullName.Substring($AgyGlobal.Length).TrimStart("\", "/")
        $dest = Join-Path $AgyRepo $rel
        $destDir = Split-Path -Parent $dest
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
    }

    # Clean up stale files in workspace .gemini/config/skills
    $agyRepoFiles = Get-ChildItem -LiteralPath $AgyRepo -Recurse -File | Where-Object {
        $rel = $_.FullName.Substring($AgyRepo.Length).TrimStart("\", "/")
        $rel -notmatch "^\.git[\\/]" -and $_.Name -ne ".gitignore"
    }
    foreach ($rf in $agyRepoFiles) {
        $rel = $rf.FullName.Substring($AgyRepo.Length).TrimStart("\", "/")
        $skillName = ($rel -split "[\\/]")[0]
        if ($PreservedWorkspaceSkills -contains $skillName) {
            continue
        }
        $orig = Join-Path $AgyGlobal $rel
        if (-not (Test-Path -LiteralPath $orig)) {
            Write-Host "Removing stale workspace file: $rel" -ForegroundColor Magenta
            Remove-Item -LiteralPath $rf.FullName -Force
        }
    }

    # 2. Sync Copilot Global -> Workspace .agents/skills
    Write-Host "`nSyncing Copilot Global -> Workspace .agents/skills..." -ForegroundColor Cyan
    $copGlobalFiles = Get-ChildItem -LiteralPath $CopGlobal -Recurse -File | Where-Object {
        $rel = $_.FullName.Substring($CopGlobal.Length).TrimStart("\", "/")
        $rel -notmatch "^\.git[\\/]" -and $_.Name -ne 'antigravity-sync-manifest.json'
    }

    foreach ($f in $copGlobalFiles) {
        $rel = $f.FullName.Substring($CopGlobal.Length).TrimStart("\", "/")
        $dest = Join-Path $CopRepo $rel
        $destDir = Split-Path -Parent $dest
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
    }

    # Clean up stale files in workspace .agents/skills
    $copRepoFiles = Get-ChildItem -LiteralPath $CopRepo -Recurse -File | Where-Object {
        $rel = $_.FullName.Substring($CopRepo.Length).TrimStart("\", "/")
        $rel -notmatch "^\.git[\\/]" -and $_.Name -ne ".gitignore"
    }
    foreach ($rf in $copRepoFiles) {
        $rel = $rf.FullName.Substring($CopRepo.Length).TrimStart("\", "/")
        $skillName = ($rel -split "[\\/]")[0]
        if ($PreservedWorkspaceSkills -contains $skillName) {
            continue
        }
        $orig = Join-Path $CopGlobal $rel
        if (-not (Test-Path -LiteralPath $orig)) {
            Write-Host "Removing stale workspace file: $rel" -ForegroundColor Magenta
            Remove-Item -LiteralPath $rf.FullName -Force
        }
    }

    Write-Host "`nWorkspace mirror synchronization complete!" -ForegroundColor Green
    Write-Host "Git status summary:" -ForegroundColor Gray
    git -C $RepoRoot status --short
}

# ---------------------------------------------------------
# Main Controller Flow
# ---------------------------------------------------------
$audit = Audit-GlobalSkills

if ($CheckOnly) {
    Audit-WorkspaceMirrors
    Write-Host "`n[CheckOnly Mode] Audit completed. No file modifications made." -ForegroundColor Cyan
    exit 0
}

if ($SyncGlobal -or (-not $SyncWorkspace -and -not $CheckOnly)) {
    Sync-GlobalSkills -AuditResult $audit
}

if ($SyncWorkspace -or (-not $SyncGlobal -and -not $CheckOnly)) {
    Sync-WorkspaceMirrors
}
