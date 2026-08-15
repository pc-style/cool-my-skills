# install.ps1 - Windows finisher for the search-cold-skills skill. Mirrors
# install.sh for PowerShell 7+.
#
# This runs when the skill was dropped in by a copy-only installer (e.g.
# `npx skills add`) that does not create the cold-storage directory or strip the
# "not installed yet" warning. Agents should explain this first and ask the user
# before running it. It only does these things:
#   1. create ~/.agents/skills-cold/
#   2. remove the NOT-INSTALLED warning block from this skill's SKILL.md
#
# For the full interactive experience (moving skills into cold storage), run the
# repo's setup.ps1 instead.

$SkillDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$SkillMd  = Join-Path $SkillDir 'SKILL.md'
$ColdDir  = $env:COLD_SKILLS_DIR ?? (Join-Path $HOME '.agents\skills-cold')

# 1. Ensure cold-storage directory exists.
New-Item -ItemType Directory -Path $ColdDir -Force | Out-Null

# 2. Strip the NOT-INSTALLED warning block (markers inclusive) if present.
if (Test-Path -LiteralPath $SkillMd) {
  $text = Get-Content -LiteralPath $SkillMd -Raw
  if ($text -match 'COOL-MY-SKILLS:NOT-INSTALLED:START') {
    $text = $text -replace '(?s)\s*<!--\s*COOL-MY-SKILLS:NOT-INSTALLED:START\s*-->.*?<!--\s*COOL-MY-SKILLS:NOT-INSTALLED:END\s*-->\s*', "`n"
    $text = $text -replace '(\r?\n){3,}', "`n`n"
    Set-Content -LiteralPath $SkillMd -Value $text -Encoding utf8
  }
}

Write-Host "search-cold-skills: setup complete. cold storage at $ColdDir"
