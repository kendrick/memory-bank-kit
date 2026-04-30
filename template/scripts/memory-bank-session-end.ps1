# Reminds the developer to update the memory bank if significant work was done.

$ErrorActionPreference = 'Stop'

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

if (-not (Test-Path (Join-Path $repoRoot 'memory-bank'))) { exit 0 }

$changed = git -C $repoRoot diff --name-only HEAD 2>$null
$changedFiles = if ($changed) { ($changed | Measure-Object -Line).Lines } else { 0 }

if ($changedFiles -gt 5) {
    Write-Output "{`"systemMessage`":`"You changed $changedFiles files this session. Consider running /update-memory-bank or @memory-bank-synchronizer to keep the memory bank current.`"}"
}
