# Ensures activeContext.md exists at session start.
# If missing, copies from the example template.

$ErrorActionPreference = 'Stop'

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

$bankDir = Join-Path $repoRoot 'memory-bank'

# Hooks fire on every session in every project, not just memory-bank
# consumers. Bail quietly so unrelated repos don't see noise.
if (-not (Test-Path $bankDir)) { exit 0 }

$activeContext = Join-Path $bankDir 'activeContext.md'
$exampleFile = Join-Path $bankDir 'activeContext.example.md'

# {"systemMessage":"..."} on stdout is the hook protocol — the host surfaces
# it to the user. Plain Write-Host calls get ignored.
if (-not (Test-Path $activeContext)) {
    if (Test-Path $exampleFile) {
        Copy-Item $exampleFile $activeContext
        Write-Output '{"systemMessage":"Created memory-bank/activeContext.md from template. Update it with your current focus."}'
    } else {
        Write-Output '{"systemMessage":"No activeContext.example.md found. Memory bank may not be initialized."}'
    }
} else {
    # 20 is the hard limit set by activeContext.example.md. Past that, the
    # file has stopped being a queue and started being an archive.
    $lineCount = (Get-Content $activeContext | Where-Object { $_.Trim() -ne '' }).Count
    if ($lineCount -gt 20) {
        Write-Output "{`"systemMessage`":`"Warning: activeContext.md has $lineCount non-empty lines (limit is 20). Run /update-memory-bank to prune it.`"}"
    }
}
