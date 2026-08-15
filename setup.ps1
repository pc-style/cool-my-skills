# setup.ps1 - Windows installer for search-cold-skills. Mirrors setup.sh for
# PowerShell 7+. Creates ~/.agents/skills-cold, installs one hot search skill,
# then optionally moves noisy skills into cold storage.

param(
  [Alias('n')]
  [switch]$DryRun,
  [Alias('h')]
  [switch]$Help
)

$RepoUrl    = $env:COOL_MY_SKILLS_REPO    ?? 'https://github.com/pc-style/cool-my-skills'
$TarballUrl = $env:COOL_MY_SKILLS_TARBALL ?? 'https://codeload.github.com/pc-style/cool-my-skills/tar.gz/refs/heads/main'

if ($Help) {
  Write-Host 'usage: pwsh setup.ps1 [-DryRun]'
  Write-Host '  -DryRun, -n   show the whole flow (banner, prompts, picker) without touching disk'
  exit 0
}

if ($args.Count -gt 0) {
  Write-Error "unrecognized argument(s): $($args -join ' ')"
  Write-Host 'usage: pwsh setup.ps1 [-DryRun]'
  exit 2
}

# Where is this script? When piped (irm | iex) $PSScriptRoot is empty.
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$SrcSkill  = Join-Path $ScriptDir 'skills\search-cold-skills'

# ---- bootstrap: piped with no checkout -> fetch ourselves, then re-run -------
if (-not (Test-Path -LiteralPath $SrcSkill)) {
  if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
    Write-Error 'curl.exe is required to bootstrap. install it and retry.'
    exit 1
  }
  if (-not (Get-Command tar.exe -ErrorAction SilentlyContinue)) {
    Write-Error 'tar.exe is required to bootstrap. install it and retry.'
    exit 1
  }
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("cool-my-skills-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null
  try {
    Write-Host 'fetching cool-my-skills...'
    $bundle = Join-Path $tmp 'bundle.tar.gz'
    curl.exe -fsSL "$TarballUrl?cache_bust=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" -o $bundle
    if ($LASTEXITCODE -ne 0) { Write-Error "could not fetch $RepoUrl"; exit 1 }
    tar -xzf $bundle -C $tmp
    if ($LASTEXITCODE -ne 0) { Write-Error "could not fetch $RepoUrl"; exit 1 }
    $repoDir = Get-ChildItem -LiteralPath $tmp -Directory | Select-Object -First 1
    if (-not $repoDir) { Write-Error "could not fetch $RepoUrl"; exit 1 }
    & pwsh -File (Join-Path $repoDir.FullName 'setup.ps1') @PSBoundParameters @args
    exit $LASTEXITCODE
  } finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

$HotDir  = $env:HOT_SKILLS_DIR  ?? (Join-Path $HOME '.agents\skills')
$ColdDir = $env:COLD_SKILLS_DIR ?? (Join-Path $HOME '.agents\skills-cold')
$DestSkill = Join-Path $HotDir 'search-cold-skills'

function Test-Interactive {
  -not [Console]::IsInputRedirected -and $env:CI -ne 'true'
}

function Confirm-Bool([string]$Question) {
  if (-not (Test-Interactive)) { return $false }
  (Read-Host "$Question [y/N]") -match '^[yY]'
}

function Write-Banner([string]$Text) {
  Write-Host ''
  Write-Host "== $Text =="
  Write-Host ''
}
function Write-Step([string]$Msg) { Write-Host "info: $Msg" }
function Write-Ok([string]$Msg)   { Write-Host $Msg }
function Write-Dry([string]$Msg)  { Write-Host "dry-run: $Msg" }

# ---- the pitch --------------------------------------------------------------
if ($DryRun) { Write-Banner 'cool-my-skills (dry run)' } else { Write-Banner 'cool-my-skills' }
if ($DryRun) { Write-Dry 'dry run: showing the whole flow, nothing on disk gets touched.' }
Write-Host 'cold skills are skills kept outside the auto-scanned skills dir.'
Write-Host 'they stay silent until you explicitly call them with: cold <name>'
Write-Host ''
Write-Host 'This installer will create ~/.agents/skills-cold, install one hot search'
Write-Host 'skill, then optionally let you move a few noisy skills into cold storage.'
Write-Host "Don't move everything. two or three loud skills is usually enough."
Write-Host ''

if (-not (Confirm-Bool 'install search-cold-skills now?')) {
  Write-Ok 'cancelled. nothing installed.'
  exit 0
}

# ---- install the hot search skill -------------------------------------------
if ($DryRun) {
  Write-Dry "would create $ColdDir"
  Write-Dry "would install search-cold-skills into $HotDir"
  Write-Dry 'would strip the not-installed warning from the installed SKILL.md'
} else {
  Write-Step "creating $ColdDir"
  New-Item -ItemType Directory -Path $ColdDir, $HotDir -Force | Out-Null

  Write-Step "installing search-cold-skills into $HotDir"
  New-Item -ItemType Directory -Path (Join-Path $DestSkill 'scripts') -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $SrcSkill 'SKILL.md')            -Destination (Join-Path $DestSkill 'SKILL.md') -Force
  Copy-Item -LiteralPath (Join-Path $SrcSkill 'scripts\query.ps1')   -Destination (Join-Path $DestSkill 'scripts\query.ps1') -Force
  Copy-Item -LiteralPath (Join-Path $SrcSkill 'scripts\install.ps1') -Destination (Join-Path $DestSkill 'scripts\install.ps1') -Force

  Write-Step 'finishing skill setup'
  $prevColdDir = $env:COLD_SKILLS_DIR
  try {
    $env:COLD_SKILLS_DIR = $ColdDir
    & pwsh -File (Join-Path $DestSkill 'scripts\install.ps1') | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Write-Error 'skill setup failed.'
      exit 1
    }
  } finally {
    if ($null -eq $prevColdDir) {
      Remove-Item 'Env:\COLD_SKILLS_DIR' -ErrorAction SilentlyContinue
    } else {
      $env:COLD_SKILLS_DIR = $prevColdDir
    }
  }
}

# ---- offer to cool some skills now ------------------------------------------
$candidates = @(
  Get-ChildItem -LiteralPath $HotDir -Directory -ErrorAction SilentlyContinue |
    Where-Object { (Test-Path (Join-Path $_.FullName 'SKILL.md')) -and $_.Name -ne 'search-cold-skills' } |
    ForEach-Object Name |
    Sort-Object
)

if ($candidates.Count -eq 0) {
  Write-Ok 'done. no other hot skills found to cool yet.'
  Write-Host 'install this on a machine with skills and re-run to cool some.'
  exit 0
}

if (-not (Confirm-Bool 'do you want to cool some skills now?')) {
  Write-Ok 'done. search-cold-skills is live. run this again anytime to cool more.'
  Write-Host 'use it with:  cold <skill-name or query>'
  exit 0
}

# pick which ones to move (names, space-separated)
Write-Host 'skills you can cool:'
foreach ($name in $candidates) {
  Write-Host "  - $name"
}
$reply = Read-Host 'type space-separated names to cool (blank to skip)'

$selected = [System.Collections.Generic.List[string]]::new()
foreach ($token in $reply -split ' ') {
  if (-not $token) { continue }
  if ($candidates -contains $token) { $selected.Add($token) }
}

if ($selected.Count -eq 0) {
  Write-Ok 'nothing selected. search-cold-skills is still live.'
  exit 0
}

# move each selection into cold storage
$moved = 0
foreach ($name in $selected) {
  $src = Join-Path $HotDir $name
  $dst = Join-Path $ColdDir $name
  if (-not (Test-Path -LiteralPath $src -PathType Container)) { Write-Step "skip: $name (not found)"; continue }
  if (Test-Path -LiteralPath $dst) { Write-Step "skip: $name (already in cold storage)"; continue }
  if ($DryRun) {
    Write-Dry "would cool: $name  ($src -> $dst)"
  } else {
    Move-Item -LiteralPath $src -Destination $dst
    Write-Step "cooled: $name"
  }
  $moved++
}

Write-Host ''
if ($DryRun) {
  Write-Ok "dry run done. would have cooled $moved skill(s). nothing was moved."
} else {
  Write-Ok "done. cooled $moved skill(s)."
  Write-Host 'they no longer auto-trigger. reach them with:  cold <name or query>'
}
