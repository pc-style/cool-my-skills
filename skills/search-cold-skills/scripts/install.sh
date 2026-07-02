#!/usr/bin/env bash
# install.sh — embedded finisher for the search-cold-skills skill.
#
# This runs when the skill was dropped in by a copy-only installer (e.g.
# `npx skills add`) that does not create the cold-storage directory or strip the
# "not installed yet" warning. Agents should explain this first and ask the user
# before running it. It only does these things:
#   1. create ~/.agents/skills-cold/
#   2. remove the NOT-INSTALLED warning block from this skill's SKILL.md
#   3. make scripts/query.sh executable
#
# For the full interactive experience (moving skills into cold storage), run the
# repo's setup.sh instead.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_MD="$SKILL_DIR/SKILL.md"
COLD_DIR="${COLD_SKILLS_DIR:-$HOME/.agents/skills-cold}"

# 1. Ensure cold-storage directory exists.
mkdir -p "$COLD_DIR"

# 2. Strip the NOT-INSTALLED warning block (markers inclusive) if present.
if [ -f "$SKILL_MD" ] && grep -q 'COOL-MY-SKILLS:NOT-INSTALLED:START' "$SKILL_MD"; then
  sed -i.bak '/COOL-MY-SKILLS:NOT-INSTALLED:START/,/COOL-MY-SKILLS:NOT-INSTALLED:END/d' "$SKILL_MD"
  rm -f "$SKILL_MD.bak"
fi

# Make the query helper runnable (copy installers can drop the +x bit).
[ -f "$SKILL_DIR/scripts/query.sh" ] && chmod +x "$SKILL_DIR/scripts/query.sh" || true

echo "search-cold-skills: setup complete. cold storage at $COLD_DIR"
