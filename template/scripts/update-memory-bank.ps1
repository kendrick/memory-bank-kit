# Manual memory bank sync trigger.
# Works from any terminal — not tied to a specific AI tool.
# Prints a summary of memory bank staleness for the developer to act on.

$ErrorActionPreference = 'Stop'

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

$bankDir = Join-Path $repoRoot 'memory-bank'

Write-Host "=== Memory Bank Status ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $bankDir)) {
    Write-Host "No memory-bank/ directory found at $repoRoot." -ForegroundColor Yellow
    Write-Host "Run the memory-bank-kit installer to scaffold one."
    exit 1
}

# activeContext.md status
$activeContext = Join-Path $bankDir 'activeContext.md'
if (Test-Path $activeContext) {
    $lines = (Get-Content $activeContext | Where-Object { $_.Trim() -ne '' }).Count
    Write-Host "activeContext.md: $lines non-empty lines (limit: 20)"
} else {
    Write-Host "activeContext.md: MISSING — run: Copy-Item memory-bank\activeContext.example.md memory-bank\activeContext.md" -ForegroundColor Yellow
}

# Last modified times
Write-Host ""
Write-Host "Last modified:"
Get-ChildItem (Join-Path $bankDir '*.md') | ForEach-Object {
    $mod = $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
    Write-Host "  $($_.Name): $mod"
}

# Recent change context
Write-Host ""
Write-Host "Recent changes (last 5 commits):"
$diffOutput = git -C $repoRoot diff --stat HEAD~5 2>$null
if ($LASTEXITCODE -eq 0 -and $diffOutput) {
    Write-Host $diffOutput
} else {
    Write-Host "  (not enough git history)"
}
