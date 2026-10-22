<#
.SYNOPSIS
    Automated pre-flight check, local git init, GitHub repository creation, and initial push.
.DESCRIPTION
    Validates .gitignore against standard blacklist patterns, initializes Git repository on branch main,
    discovers GitHub credentials non-interactively via Git Credential Manager or gh CLI,
    creates the remote repository (default private), configures origin, and pushes upstream.
.PARAMETER WorkspacePath
    Target workspace or directory. Defaults to current working directory.
.PARAMETER RepoName
    GitHub repository name. Defaults to the leaf folder name of WorkspacePath.
.PARAMETER Description
    Repository description on GitHub.
.PARAMETER Visibility
    'private' (default) or 'public'.
.PARAMETER InitialCommitMessage
    Commit message for initial commit if uncommitted. Defaults to 'Initial commit'.
.PARAMETER DryRun
    Audits prerequisites without creating remote repository or pushing.
#>
[CmdletBinding()]
param(
    [string]$WorkspacePath = (Get-Location).Path,
    [string]$RepoName,
    [string]$Description = "",
    [ValidateSet("private", "public")]
    [string]$Visibility = "private",
    [string]$InitialCommitMessage = "Initial commit",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# 1. Resolve and Validate Workspace Path
$resolvedPath = (Resolve-Path -LiteralPath $WorkspacePath).Path
if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
    throw "Target workspace path does not exist or is not a directory: $WorkspacePath"
}

if (-not $RepoName) {
    $RepoName = Split-Path -Leaf $resolvedPath
}
# Sanitize repository name (alphanumeric, dashes, underscores, periods)
$RepoName = ($RepoName -replace '[^a-zA-Z0-9._-]', '-').Trim('-')
if (-not $RepoName) {
    throw "Invalid or empty repository name."
}

Write-Host "Target Workspace : $resolvedPath" -ForegroundColor Cyan
Write-Host "Repository Name  : $RepoName" -ForegroundColor Cyan
Write-Host "Visibility       : $Visibility" -ForegroundColor Cyan

# 2. Check and Enforce .gitignore Hygiene
$gitignorePath = Join-Path $resolvedPath ".gitignore"
$requiredPatterns = @(
    "# Secrets & Credentials",
    ".env",
    ".env.*",
    "*.key",
    "*.pem",
    "*.token",
    "credentials.json",
    "",
    "# Dependencies & Virtual Environments",
    "node_modules/",
    "__pycache__/",
    "*.py[cod]",
    ".venv/",
    "venv/",
    "vendor/",
    "target/",
    "",
    "# Build Outputs & Caches",
    "dist/",
    "build/",
    "out/",
    ".turbo/",
    ".next/",
    "*.egg-info/",
    ".pytest_cache/",
    ".mypy_cache/",
    "",
    "# OS & Editor settings",
    ".DS_Store",
    "Thumbs.db",
    "desktop.ini",
    ".idea/",
    ".vscode/",
    "",
    "# Scratch & Temporary",
    "scratch/",
    "*.log"
)

if (-not (Test-Path -LiteralPath $gitignorePath)) {
    Write-Host "Creating missing .gitignore with standard security & hygiene rules..." -ForegroundColor Yellow
    [System.IO.File]::WriteAllLines($gitignorePath, $requiredPatterns, [System.Text.UTF8Encoding]::new($false))
} else {
    $existing = [System.IO.File]::ReadAllText($gitignorePath)
    $toAppend = @()
    foreach ($pattern in @('.env', 'node_modules/', '__pycache__/', '.venv/', 'dist/', '.DS_Store', 'Thumbs.db')) {
        if ($existing -notmatch [regex]::Escape($pattern)) {
            $toAppend += $pattern
        }
    }
    if ($toAppend.Count -gt 0) {
        Write-Host "Appending missing hygiene rules to existing .gitignore ($($toAppend -join ', '))..." -ForegroundColor Yellow
        $appendBlock = "`n# Added by create-github-repo hygiene check`n" + ($toAppend -join "`n") + "`n"
        [System.IO.File]::AppendAllText($gitignorePath, $appendBlock, [System.Text.UTF8Encoding]::new($false))
    }
}

# 3. Discover GitHub Credentials Non-Interactively
$token = $null
$owner = $null

# Option A: Check GitHub CLI (gh)
$ghPath = Get-Command "gh" -ErrorAction SilentlyContinue
if ($ghPath) {
    try {
        $ghStatus = & gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            $token = (& gh auth token 2>&1).Trim()
            $owner = (& gh api user --jq .login 2>&1).Trim()
            Write-Host "Discovered credentials via GitHub CLI: $owner" -ForegroundColor Green
        }
    } catch {
        # Fallback to Git Credential Manager
    }
}

# Option B: Fallback to Git Credential Manager
if (-not $token) {
    $tempInput = [System.IO.Path]::GetTempFileName()
    $tempOutput = [System.IO.Path]::GetTempFileName()
    $tempError = [System.IO.Path]::GetTempFileName()

    try {
        [System.IO.File]::WriteAllText($tempInput, "protocol=https`nhost=github.com`n`n", [System.Text.UTF8Encoding]::new($false))
        $proc = Start-Process -FilePath "git" -ArgumentList "credential", "fill" -NoNewWindow -PassThru `
            -RedirectStandardInput $tempInput -RedirectStandardOutput $tempOutput -RedirectStandardError $tempError
        $proc.WaitForExit(10000)

        if ($proc.ExitCode -eq 0 -and (Test-Path $tempOutput)) {
            $credLines = Get-Content -LiteralPath $tempOutput
            $token = ($credLines | Where-Object { $_ -match '^password=' }) -replace '^password=', ''
            $owner = ($credLines | Where-Object { $_ -match '^username=' }) -replace '^username=', ''
            if ($token) {
                Write-Host "Discovered credentials via Git Credential Manager: $owner" -ForegroundColor Green
            }
        }
    } finally {
        Remove-Item -LiteralPath $tempInput, $tempOutput, $tempError -Force -ErrorAction SilentlyContinue
    }
}

if (-not $token) {
    throw "Could not discover GitHub authentication token. Please ensure Git Credential Manager or GitHub CLI (gh) is authenticated."
}

# Verify / Fetch owner login via GitHub API if missing or needed
$headers = @{
    "Authorization" = "Bearer $token"
    "Accept"        = "application/vnd.github+json"
    "User-Agent"    = "Antigravity"
}

if (-not $owner) {
    $userResp = Invoke-RestMethod -Uri "https://api.github.com/user" -Method Get -Headers $headers
    $owner = $userResp.login
}

Write-Host "GitHub Account   : $owner" -ForegroundColor Green

if ($DryRun) {
    Write-Host "`n[DryRun Mode] Pre-flight checks passed successfully." -ForegroundColor Yellow
    Write-Host "Would create repository '$owner/$RepoName' ($Visibility) and push branch 'main'."
    return
}

# 4. Initialize Local Git Repository if needed
$gitDir = Join-Path $resolvedPath ".git"
if (-not (Test-Path -LiteralPath $gitDir)) {
    Write-Host "Initializing Git repository with default branch 'main'..." -ForegroundColor Cyan
    git -C $resolvedPath init -b main
    if ($LASTEXITCODE -ne 0) { throw "git init failed." }
}

# Check uncommitted files and commit
git -C $resolvedPath add .
$staged = @(git -C $resolvedPath diff --cached --name-only)
if ($staged.Count -gt 0) {
    Write-Host "Committing initial project files ($($staged.Count) files)..." -ForegroundColor Cyan
    git -C $resolvedPath commit -m $InitialCommitMessage
    if ($LASTEXITCODE -ne 0) { throw "git commit failed." }
} else {
    Write-Host "Working tree already committed." -ForegroundColor Gray
}

# Ensure branch is main
$currentBranch = (git -C $resolvedPath rev-parse --abbrev-ref HEAD).Trim()
if ($currentBranch -ne "main") {
    Write-Host "Renaming current branch '$currentBranch' to 'main'..." -ForegroundColor Gray
    git -C $resolvedPath branch -M main
}

# 5. Create Remote GitHub Repository via REST API
$createBody = @{
    name        = $RepoName
    private     = ($Visibility -eq "private")
    description = $Description
} | ConvertTo-Json

$remoteRepoUrl = "https://github.com/$owner/$RepoName"
$remoteGitUrl  = "https://github.com/$owner/$RepoName.git"

Write-Host "Creating remote repository $RepoName ($Visibility) via GitHub API..." -ForegroundColor Cyan
try {
    $createResp = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Method Post -Headers $headers -Body $createBody -ContentType "application/json"
    Write-Host "Repository successfully created: $($createResp.html_url)" -ForegroundColor Green
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 422) {
        Write-Warning "Repository '$RepoName' already exists on GitHub for $owner. Continuing with existing repository."
    } else {
        throw "Failed to create remote repository: $_"
    }
}

# 6. Configure Remote Origin & Push
$existingOrigin = (git -C $resolvedPath remote get-url origin 2>$null)
if (-not $existingOrigin) {
    Write-Host "Setting remote origin to $remoteGitUrl..." -ForegroundColor Cyan
    git -C $resolvedPath remote add origin $remoteGitUrl
} elseif ($existingOrigin -ne $remoteGitUrl) {
    Write-Host "Updating remote origin to $remoteGitUrl..." -ForegroundColor Cyan
    git -C $resolvedPath remote set-url origin $remoteGitUrl
}

Write-Host "Pushing main to origin with upstream tracking..." -ForegroundColor Cyan
git -C $resolvedPath push -u origin main
if ($LASTEXITCODE -ne 0) {
    throw "Failed to push to remote repository."
}

# 7. Verification & Summary Output
$latestCommit = (git -C $resolvedPath rev-parse --short HEAD).Trim()
Write-Host "`n========================================================" -ForegroundColor Green
Write-Host " Repository Successfully Published to GitHub!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host " URL        : $remoteRepoUrl" -ForegroundColor Cyan
Write-Host " Remote     : $remoteGitUrl" -ForegroundColor Cyan
Write-Host " Visibility : $Visibility" -ForegroundColor Cyan
Write-Host " Branch     : main ($latestCommit)" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Green

[ordered]@{
    status     = "success"
    owner      = $owner
    name       = $RepoName
    url        = $remoteRepoUrl
    git_url    = $remoteGitUrl
    visibility = $Visibility
    branch     = "main"
    commit     = $latestCommit
}
