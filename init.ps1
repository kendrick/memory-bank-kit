# memory-bank-kit installer (Windows / PowerShell)
# Scaffolds a two-tier memory bank into the current project, with config
# for both Claude Code and GitHub Copilot.

$ErrorActionPreference = 'Stop'

# Replace $RepoDefault before publishing the kit. Forks and private mirrors
# override at install time via the env vars below.
$RepoDefault = 'yourorg/memory-bank-kit'
$Repo   = if ($env:MEMORY_BANK_KIT_REPO)   { $env:MEMORY_BANK_KIT_REPO }   else { $RepoDefault }
$Branch = if ($env:MEMORY_BANK_KIT_BRANCH) { $env:MEMORY_BANK_KIT_BRANCH } else { 'main' }

# ---------- helpers ----------

function Write-Info ($msg) { Write-Host "[info] $msg" -ForegroundColor Blue }
function Write-Ok   ($msg) { Write-Host "[ok] $msg"   -ForegroundColor Green }
function Write-Warn ($msg) { Write-Host "[warn] $msg" -ForegroundColor Yellow }
function Write-Fail ($msg) { Write-Host "[error] $msg" -ForegroundColor Red }

function Confirm-Prompt ($prompt, $defaultYes = $true) {
    $hint = if ($defaultYes) { '[Y/n]' } else { '[y/N]' }
    $reply = Read-Host "$prompt $hint"
    if ([string]::IsNullOrWhiteSpace($reply)) { return $defaultYes }
    return $reply -match '^(y|yes)$'
}

# Always prompts before overwriting. Re-running the installer to pick up
# kit upgrades is expected, and a silent overwrite would clobber local edits.
function Copy-IfAbsent ($src, $dst) {
    if (Test-Path $dst) {
        if (Confirm-Prompt "  $dst already exists. Overwrite?" $false) {
            Copy-Item $src $dst -Force
            Write-Ok "overwrote $dst"
        } else {
            Write-Info "kept existing $dst"
        }
    } else {
        $parent = Split-Path $dst -Parent
        if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item $src $dst
        Write-Ok "created $dst"
    }
}

# Idempotency relies on the marker line. If a user renames the heading the
# detection misses and a duplicate section gets appended on re-run, which is
# easier to spot than a silent skip. That's the trade we want.
function Append-SectionIfMissing ($srcContent, $dst, $marker) {
    if (-not (Test-Path $dst)) {
        $parent = Split-Path $dst -Parent
        if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Set-Content -Path $dst -Value $srcContent
        Write-Ok "created $dst"
        return
    }
    $current = Get-Content $dst -Raw
    if ($current -like "*$marker*") {
        Write-Info "$dst already contains memory-bank section, leaving alone"
        return
    }
    Add-Content -Path $dst -Value "`n$srcContent"
    Write-Ok "appended memory-bank section to $dst"
}

# ---------- locate template ----------

# Two install paths: a cloned kit (template/ next to this script) or curl-pipe
# (script alone, fetches the tarball). Local wins so kit devs can iterate
# without round-tripping GitHub.
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TargetDir = (Get-Location).Path
$Template  = $null

if (Test-Path (Join-Path $ScriptDir 'template')) {
    $Template = Join-Path $ScriptDir 'template'
    Write-Info "using local template at $Template"
} else {
    Write-Info "downloading template from $Repo@$Branch"
    $tmp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "mbk-$([guid]::NewGuid().Guid)")
    $tarUrl = "https://codeload.github.com/$Repo/tar.gz/refs/heads/$Branch"
    $tarPath = Join-Path $tmp.FullName 'kit.tar.gz'
    try {
        Invoke-WebRequest -Uri $tarUrl -OutFile $tarPath -UseBasicParsing
        tar -xzf $tarPath -C $tmp.FullName
    } catch {
        Write-Fail "could not download template from $Repo@$Branch"
        Write-Fail "set MEMORY_BANK_KIT_REPO and MEMORY_BANK_KIT_BRANCH if you forked"
        exit 1
    }
    $Template = (Get-ChildItem -Path $tmp.FullName -Recurse -Directory -Filter 'template' | Select-Object -First 1).FullName
    if (-not $Template) {
        Write-Fail "downloaded archive did not contain a template/ directory"
        exit 1
    }
}

# ---------- intro ----------

Write-Host ""
Write-Host "memory-bank-kit installer" -ForegroundColor Blue
Write-Host "Target: $TargetDir"
Write-Host ""

if ($TargetDir -eq $ScriptDir) {
    Write-Warn "you're running this from the kit's own repo."
    Write-Warn "this would scaffold the kit into itself (dogfood). Continue only if that's intentional."
    if (-not (Confirm-Prompt "Proceed?" $false)) { Write-Host "aborted."; exit 0 }
}

# ---------- detect stack ----------

function Get-Stack {
    $lang = ''
    $framework = ''
    if (Test-Path 'package.json') {
        $lang = 'JavaScript/TypeScript'
        $pj = Get-Content 'package.json' -Raw
        if     ($pj -match '"next"')   { $framework = 'Next.js' }
        elseif ($pj -match '"react"')  { $framework = 'React' }
        elseif ($pj -match '"vue"')    { $framework = 'Vue' }
        elseif ($pj -match '"svelte"') { $framework = 'Svelte' }
    } elseif (Test-Path 'pyproject.toml') {
        $lang = 'Python'
        $py = Get-Content 'pyproject.toml' -Raw
        if     ($py -match 'django')  { $framework = 'Django' }
        elseif ($py -match 'fastapi') { $framework = 'FastAPI' }
        elseif ($py -match 'flask')   { $framework = 'Flask' }
    } elseif (Test-Path 'Cargo.toml') {
        $lang = 'Rust'
    } elseif (Test-Path 'go.mod') {
        $lang = 'Go'
    } elseif (Test-Path 'Gemfile') {
        $lang = 'Ruby'
        if ((Get-Content 'Gemfile' -Raw) -match 'rails') { $framework = 'Rails' }
    }
    return @{ Language = $lang; Framework = $framework }
}

$Stack = Get-Stack
if ($Stack.Language) {
    $msg = $Stack.Language
    if ($Stack.Framework) { $msg += " ($($Stack.Framework))" }
    Write-Info "detected: $msg"
} else {
    Write-Info "no recognized stack detected"
}

# ---------- check existing structure ----------

$Existing = @()
if (Test-Path 'memory-bank') { $Existing += 'memory-bank/' }
if (Test-Path '.claude')     { $Existing += '.claude/' }
if (Test-Path '.github')     { $Existing += '.github/' }
if (Test-Path 'AGENTS.md')   { $Existing += 'AGENTS.md' }
if (Test-Path 'CLAUDE.md')   { $Existing += 'CLAUDE.md' }

if ($Existing.Count -gt 0) {
    Write-Warn "found existing config: $($Existing -join ', ')"
    Write-Warn "files will be merged where possible. You'll be prompted before overwrites."
    if (-not (Confirm-Prompt 'Continue?' $true)) { Write-Host 'aborted.'; exit 0 }
}

Write-Host ''
Write-Info 'scaffolding...'

# ---------- memory-bank ----------

if (-not (Test-Path 'memory-bank')) { New-Item -ItemType Directory -Path 'memory-bank' | Out-Null }
$bankFiles = @('activeContext.example.md','projectOverview.md','decisionLog.md','dataContracts.md','conventions.md','openQuestions.md')
foreach ($f in $bankFiles) {
    Copy-IfAbsent (Join-Path $Template "memory-bank\$f") (Join-Path $TargetDir "memory-bank\$f")
}

if (-not (Test-Path 'memory-bank\activeContext.md')) {
    Copy-Item 'memory-bank\activeContext.example.md' 'memory-bank\activeContext.md'
    Write-Ok 'created your local memory-bank/activeContext.md from the template'
}

# Skip pre-population if the placeholder marker is gone: the team has filled
# in their overview by hand and we shouldn't clobber it on re-run.
if ($Stack.Language -and (Get-Content 'memory-bank\projectOverview.md' -Raw) -match '^_To be filled\._') {
    $repoName = Split-Path $TargetDir -Leaf
    $dirs = (Get-ChildItem -Directory | Select-Object -First 20 | ForEach-Object { "- $($_.Name)" }) -join "`n"
    $fwLine = if ($Stack.Framework) { $Stack.Framework } else { '_(none detected)_' }
    $overview = @"
# Project Overview

## What This Is
<!-- One sentence. What does this project do? -->
$repoName — _add a one-sentence description here._

## Stack
- Language: $($Stack.Language)
- Framework: $fwLine
- Styling:
- Data layer:
- Deployment:

## Repository Structure
<!-- Top-level directory map. Update as the layout changes. -->
``````
$dirs
``````

## Key Constraints
<!-- Non-obvious things an agent must know: monorepo rules, legacy code -->
<!-- boundaries, API version requirements, browser support, etc. -->
"@
    Set-Content -Path 'memory-bank\projectOverview.md' -Value $overview
    Write-Ok 'pre-populated memory-bank/projectOverview.md with detected stack'
}

# ---------- .memory-bankrc.example ----------

# We ship the example, not the rc itself. Defaults are baked into the hook
# scripts; the rc is opt-in for teams that want to override line limits or
# nudge thresholds.
Copy-IfAbsent (Join-Path $Template '.memory-bankrc.example') `
              (Join-Path $TargetDir '.memory-bankrc.example')

# ---------- AGENTS.md ----------

$agentsTemplate = Get-Content (Join-Path $Template 'AGENTS.md') -Raw
Append-SectionIfMissing $agentsTemplate (Join-Path $TargetDir 'AGENTS.md') '## Memory Bank'

# ---------- Claude Code config ----------

if (-not (Test-Path '.claude\agents')) { New-Item -ItemType Directory -Path '.claude\agents' -Force | Out-Null }
Copy-IfAbsent `
    (Join-Path $Template '.claude\agents\memory-bank-synchronizer.md') `
    (Join-Path $TargetDir '.claude\agents\memory-bank-synchronizer.md')

$claudeSection = @'

## Memory Bank

On session start, always read `memory-bank/activeContext.md`.
Read other memory bank files as directed by the table in `AGENTS.md`.
After significant work, run the memory-bank-synchronizer agent or manually update active context.
'@
Append-SectionIfMissing $claudeSection (Join-Path $TargetDir 'CLAUDE.md') '## Memory Bank'

# ---------- Copilot config ----------

foreach ($d in @('.github\agents','.github\skills\update-memory-bank','.github\hooks','.github\instructions')) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

Copy-IfAbsent (Join-Path $Template '.github\agents\memory-bank-synchronizer.agent.md') `
              (Join-Path $TargetDir '.github\agents\memory-bank-synchronizer.agent.md')
Copy-IfAbsent (Join-Path $Template '.github\skills\update-memory-bank\SKILL.md') `
              (Join-Path $TargetDir '.github\skills\update-memory-bank\SKILL.md')
Copy-IfAbsent (Join-Path $Template '.github\hooks\memory-bank-hooks.json') `
              (Join-Path $TargetDir '.github\hooks\memory-bank-hooks.json')
Copy-IfAbsent (Join-Path $Template '.github\instructions\data-layer.instructions.md') `
              (Join-Path $TargetDir '.github\instructions\data-layer.instructions.md')

$copilotTemplate = Get-Content (Join-Path $Template '.github\copilot-instructions.md') -Raw
Append-SectionIfMissing $copilotTemplate (Join-Path $TargetDir '.github\copilot-instructions.md') '## Memory Bank'

# ---------- scripts ----------

if (-not (Test-Path 'scripts')) { New-Item -ItemType Directory -Path 'scripts' | Out-Null }
$scriptFiles = @(
    'memory-bank-session-start.sh','memory-bank-session-start.ps1',
    'memory-bank-session-end.sh','memory-bank-session-end.ps1',
    'update-memory-bank.sh','update-memory-bank.ps1'
)
foreach ($f in $scriptFiles) {
    Copy-IfAbsent (Join-Path $Template "scripts\$f") (Join-Path $TargetDir "scripts\$f")
}
Write-Info 'shell scripts: PowerShell does not need chmod. On Unix systems, run: chmod +x scripts/*.sh'

# ---------- gitignore ----------

$gitignore = '.gitignore'
$line = 'memory-bank/activeContext.md'
if (Test-Path $gitignore) {
    $content = Get-Content $gitignore
    if ($content -contains $line) {
        Write-Info '.gitignore already excludes activeContext.md'
    } else {
        Add-Content $gitignore "`n# Local-only active context (memory-bank-kit)`n$line"
        Write-Ok 'added activeContext.md to .gitignore'
    }
} else {
    Set-Content $gitignore "# Local-only active context (memory-bank-kit)`n$line"
    Write-Ok 'created .gitignore with activeContext.md entry'
}

# ---------- parity check ----------

Write-Host ''
Write-Info 'verifying parity...'
$pairs = @(
    @{ Claude = '.claude\agents\memory-bank-synchronizer.md'; Copilot = '.github\agents\memory-bank-synchronizer.agent.md' }
)
$parityOk = $true
foreach ($p in $pairs) {
    if ((Test-Path $p.Claude) -and (Test-Path $p.Copilot)) {
        Write-Ok "parity: $($p.Claude) <-> $($p.Copilot)"
    } else {
        Write-Warn "parity miss: $($p.Claude) or $($p.Copilot) is absent"
        $parityOk = $false
    }
}

# ---------- done ----------

Write-Host ''
Write-Host 'done.' -ForegroundColor Green
Write-Host ''
Write-Host 'next steps:'
Write-Host '  1. Open memory-bank\projectOverview.md and fill in "What This Is".'
Write-Host '  2. Edit memory-bank\activeContext.md to reflect what you''re working on.'
Write-Host '  3. Teammates: after cloning, run:'
Write-Host '       Copy-Item memory-bank\activeContext.example.md memory-bank\activeContext.md'
Write-Host '  4. To sync the bank: invoke the memory-bank-synchronizer agent, or'
Write-Host '     run: .\scripts\update-memory-bank.ps1'
Write-Host '  5. To tune line limits or nudge thresholds:'
Write-Host '       Copy-Item .memory-bankrc.example .memory-bankrc   # then edit'

if (-not $parityOk) {
    Write-Host ''
    Write-Warn 'some parity checks failed. Review the messages above.'
}
