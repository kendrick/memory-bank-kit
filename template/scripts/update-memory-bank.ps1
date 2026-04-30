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

# Same key=value parser the hooks use (kept inline to avoid making this
# script depend on a shared lib).
function Get-Cfg ($key, $default) {
    $file = Join-Path $repoRoot '.memory-bankrc'
    if (-not (Test-Path $file)) { return $default }
    $line = Get-Content $file | Where-Object { $_ -match "^$key=" } | Select-Object -First 1
    if (-not $line) { return $default }
    $val = ($line -split '=', 2)[1].Trim().Trim('"').Trim("'")
    if ($val) { return $val } else { return $default }
}

# Env var > .memory-bankrc > built-in default. Same precedence as the hooks,
# so what this script reports matches what SessionStart and Stop will use.
$maxLines      = if ($env:MEMORY_BANK_MAX_LINES)       { [int]$env:MEMORY_BANK_MAX_LINES }       else { [int](Get-Cfg 'MAX_ACTIVE_CONTEXT_LINES' 20) }
$fileThreshold = if ($env:MEMORY_BANK_FILE_THRESHOLD)  { [int]$env:MEMORY_BANK_FILE_THRESHOLD }  else { [int](Get-Cfg 'NUDGE_FILE_THRESHOLD' 5) }
$lineThreshold = if ($env:MEMORY_BANK_LINE_THRESHOLD)  { [int]$env:MEMORY_BANK_LINE_THRESHOLD }  else { [int](Get-Cfg 'NUDGE_LINE_THRESHOLD' 200) }

Write-Host "Active config:"
Write-Host "  activeContext.md max lines: $maxLines"
Write-Host "  Nudge: > $fileThreshold files OR > $lineThreshold lines changed"
if (Test-Path (Join-Path $repoRoot '.memory-bankrc')) {
    Write-Host "  (source: .memory-bankrc; env vars override per developer)"
}
Write-Host ""

# activeContext.md status
$activeContext = Join-Path $bankDir 'activeContext.md'
if (Test-Path $activeContext) {
    $lines = (Get-Content $activeContext | Where-Object { $_.Trim() -ne '' }).Count
    Write-Host "activeContext.md: $lines non-empty lines (limit: $maxLines)"
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
