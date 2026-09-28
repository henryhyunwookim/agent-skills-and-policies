[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$InstallGlobal,
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))),
    [string]$CodexGlobal = (Join-Path $HOME '.codex/skills'),
    [string]$ClaudeGlobal = (Join-Path $HOME '.claude/skills')
)

$ErrorActionPreference = 'Stop'
$source = Join-Path $RepoRoot 'copilot/skills'
$targets = @(
    @{ Name = 'Codex'; Repo = (Join-Path $RepoRoot 'codex/skills'); Global = $CodexGlobal },
    @{ Name = 'Claude'; Repo = (Join-Path $RepoRoot 'claude/skills'); Global = $ClaudeGlobal }
)
$skills = @(Get-ChildItem -LiteralPath $source -Directory | Select-Object -ExpandProperty Name)
$drift = 0

foreach ($target in $targets) {
    foreach ($skill in $skills) {
        $sourceDir = Join-Path $source $skill
        $files = Get-ChildItem -LiteralPath $sourceDir -File -Recurse
        foreach ($file in $files) {
            $relative = $file.FullName.Substring($sourceDir.Length).TrimStart('\', '/')
            $content = [System.IO.File]::ReadAllBytes($file.FullName)
            if ($file.Extension -eq '.md') {
                $body = [System.IO.File]::ReadAllText($file.FullName)
                $body = $body.Replace('run_in_terminal', 'the available terminal tool').Replace('read_file', 'the available file reader')
                $body = $body.Replace('copilot/skills/', "$(($target.Name).ToLowerInvariant())/skills/")
                $body = $body.Replace('copilot\skills\', "$(($target.Name).ToLowerInvariant())\skills\")
                $body = $body.Replace('.agents/skills/', ".$(($target.Name).ToLowerInvariant())/skills/")
                $body = $body.Replace('.agents\skills\', ".$(($target.Name).ToLowerInvariant())\skills\")
                $body = $body.Replace('C:/Users/hyunwookim/.agents/skills/', "~/. $(($target.Name).ToLowerInvariant())/skills/".Replace(' ', ''))
                $content = [System.Text.UTF8Encoding]::new($false).GetBytes($body)
            }
            foreach ($root in @($target.Repo) + $(if ($InstallGlobal) { @($target.Global) } else { @() })) {
                $destination = Join-Path (Join-Path $root $skill) $relative
                $same = (Test-Path -LiteralPath $destination) -and ([System.Linq.Enumerable]::SequenceEqual([byte[]]$content, [byte[]][System.IO.File]::ReadAllBytes($destination)))
                if (-not $same) {
                    $drift++
                    Write-Output "$($target.Name): $destination"
                    if (-not $Check) {
                        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
                        [System.IO.File]::WriteAllBytes($destination, $content)
                    }
                }
            }
        }
    }
}
if ($Check -and $drift -gt 0) { exit 1 }
Write-Output "Checked $($skills.Count) skills for Codex and Claude; $drift files differed."
