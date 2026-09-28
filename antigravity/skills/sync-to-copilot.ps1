[CmdletBinding()]
param(
    [string]$SourceRoot = $PSScriptRoot,
    [string]$TargetRoot = (Join-Path $HOME ".agents\skills"),
    [switch]$Check
)

$ErrorActionPreference = "Stop"
$manifestPath = Join-Path $TargetRoot "antigravity-sync-manifest.json"
$excludedNames = @(".git", "sync-to-copilot.ps1", "antigravity-sync-manifest.json")
$sourceFiles = Get-ChildItem -LiteralPath $SourceRoot -File -Recurse | Where-Object {
    $relativePath = $_.FullName.Substring($SourceRoot.Length).TrimStart("\", "/")
    $_.Name -ne "README.md" -and
        $excludedNames -notcontains $_.Name -and
        $relativePath -notmatch "^\.git[\\/]"
}

if ($Check) {
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        Write-Error "Sync manifest not found: $manifestPath"
        exit 1
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $staleFiles = foreach ($sourceFile in $sourceFiles) {
        $relativePath = $sourceFile.FullName.Substring($SourceRoot.Length).TrimStart("\", "/").Replace("\", "/")
        $entry = $manifest.files | Where-Object path -eq $relativePath
        $targetPath = Join-Path $TargetRoot $relativePath
        $currentHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($null -eq $entry -or $entry.source_sha256 -ne $currentHash -or -not (Test-Path -LiteralPath $targetPath)) {
            $relativePath
        }
    }

    if ($staleFiles.Count -gt 0 -or $manifest.files.Count -ne $sourceFiles.Count) {
        Write-Output "Copilot mirror is stale. Files needing sync: $($staleFiles -join ', ')"
        exit 1
    }

    Write-Output "Copilot mirror is up to date ($($sourceFiles.Count) files; synced $($manifest.synced_at_utc))."
    exit 0
}

foreach ($sourceFile in $sourceFiles) {
    $relativePath = $sourceFile.FullName.Substring($SourceRoot.Length).TrimStart("\", "/")
    $destination = Join-Path $TargetRoot $relativePath
    $destinationDirectory = Split-Path -Parent $destination
    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null

    if ($sourceFile.Extension -eq ".md") {
        $content = Get-Content -LiteralPath $sourceFile.FullName -Raw
        $content = $content.Replace("run_command", "run_in_terminal")
        $content = $content.Replace("view_file", "read_file")
        $content = $content.Replace(
            "C:/Users/hyunwookim/.gemini/config/skills/sequential-image-extractor/scripts/sort_images.py",
            (Join-Path $TargetRoot "sequential-image-extractor/scripts/sort_images.py").Replace("\", "/")
        )
        Set-Content -LiteralPath $destination -Value $content -Encoding utf8NoBOM
    }
    else {
        Copy-Item -LiteralPath $sourceFile.FullName -Destination $destination -Force
    }
}

$entries = foreach ($sourceFile in $sourceFiles) {
    $relativePath = $sourceFile.FullName.Substring($SourceRoot.Length).TrimStart("\", "/").Replace("\", "/")
    [ordered]@{
        path = $relativePath
        source_sha256 = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        copilot_path = $relativePath
    }
}

$manifest = [ordered]@{
    format = 1
    source = (Resolve-Path $SourceRoot).Path
    target = (Resolve-Path $TargetRoot).Path
    synced_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    compatibility = @{
        "run_command" = "run_in_terminal"
        "view_file" = "read_file"
    }
    files = @($entries)
}

$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
Write-Output "Synced $($sourceFiles.Count) files to $TargetRoot"
Write-Output "Manifest: $manifestPath"