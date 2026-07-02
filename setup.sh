#!/usr/bin/env bash
# setup.sh — installs the search-cold-skills skill and optionally moves your
# noisy skills into cold storage. Pretty when gum is around, still works without.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SKILL="$SCRIPT_DIR/skills/search-cold-skills"

HOT_DIR="${HOT_SKILLS_DIR:-$HOME/.agents/skills}"
COLD_DIR="${COLD_SKILLS_DIR:-$HOME/.agents/skills-cold}"
DEST_SKILL="$HOT_DIR/search-cold-skills"

has() { command -v "$1" >/dev/null 2>&1; }
is_interactive() { [ -t 0 ] && [ -t 1 ] && [ "${CI:-}" != "true" ]; }

# ---- gum, with a soft offer to install it ------------------------------------
if ! has gum && is_interactive && has brew; then
  printf 'gum makes this nicer. install it with homebrew? [y/N] '
  read -r reply
  case "$reply" in [yY]*) brew install gum || true ;; esac
fi

# ---- output helpers (gum if present, plain otherwise) ------------------------
banner() {
  if has gum; then
    gum style --border rounded --margin "1 0" --padding "1 3" \
      --border-foreground 212 --foreground 212 --bold "$1"
  else
    printf '\n== %s ==\n\n' "$1"
  fi
}
say()  { if has gum; then gum style --foreground 244 "$1"; else printf '%s\n' "$1"; fi; }
step() { if has gum; then gum log --level info "$1"; else printf 'info: %s\n' "$1"; fi; }
ok()   { if has gum; then gum style --foreground 42 --bold "$1"; else printf '%s\n' "$1"; fi; }

confirm() { # confirm "question"  -> 0 yes / 1 no
  local q="$1"
  if has gum && is_interactive; then
    gum confirm "$q"
  elif is_interactive; then
    printf '%s [y/N] ' "$q"; read -r r; case "$r" in [yY]*) return 0 ;; *) return 1 ;; esac
  else
    return 1
  fi
}

# ---- the pitch --------------------------------------------------------------
banner "cool-my-skills"
say "every skill you install adds a tripwire. its description gets checked on"
say "every single message, so a big pile of skills is a big pile of chances to"
say "misfire on something you never asked for."
printf '\n'
say "cold skills fix that. a cold skill just agreed to shut up until spoken to."
say "it lives in ~/.agents/skills-cold, outside the dir your agent auto-scans,"
say "so its metadata never loads. you summon it on demand with 'cold <name>'."
printf '\n'
say "you don't need to go hard here. moving two or three of your loudest,"
say "rarely-right skills into cold storage already buys back a lot of quiet."
say "keep the always-on set small and sharp. everything else stays reachable,"
say "just silent. being aggressive mostly just makes things annoying to find."
printf '\n'

# ---- install the hot search skill -------------------------------------------
step "creating $COLD_DIR"
mkdir -p "$COLD_DIR" "$HOT_DIR"

step "installing search-cold-skills into $HOT_DIR"
mkdir -p "$DEST_SKILL/scripts"
cp "$SRC_SKILL/SKILL.md" "$DEST_SKILL/SKILL.md"
cp "$SRC_SKILL/scripts/query.sh" "$DEST_SKILL/scripts/query.sh"
cp "$SRC_SKILL/scripts/install.sh" "$DEST_SKILL/scripts/install.sh"
chmod +x "$DEST_SKILL/scripts/query.sh" "$DEST_SKILL/scripts/install.sh"

# finish setup: create cold dir + strip the not-installed warning
step "finishing skill setup"
COLD_SKILLS_DIR="$COLD_DIR" bash "$DEST_SKILL/scripts/install.sh" >/dev/null

# ---- offer to cool some skills now ------------------------------------------
candidates=()
while IFS= read -r name; do
  [ -n "$name" ] && candidates+=("$name")
done < <(
  find "$HOT_DIR" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/SKILL.md' ';' -print 2>/dev/null \
    | sed "s#^$HOT_DIR/##" | grep -vx 'search-cold-skills' | sort
)

if [ "${#candidates[@]}" -eq 0 ]; then
  ok "done. no other hot skills found to cool yet."
  say "install this on a machine with skills and re-run to cool some."
  exit 0
fi

if ! confirm "do you want to cool some skills now?"; then
  ok "done. search-cold-skills is live. run this again anytime to cool more."
  say "use it with:  cold <skill-name or query>"
  exit 0
fi

# pick which ones to move
if has gum && is_interactive; then
  chosen="$(printf '%s\n' "${candidates[@]}" \
    | gum choose --no-limit --height 20 \
        --header 'space to select, enter to confirm (pick a few, not all):' || true)"
else
  printf 'skills you can cool:\n'
  printf '  - %s\n' "${candidates[@]}"
  printf 'type space-separated names to cool (blank to skip): '
  read -r chosen
  chosen="${chosen// /$'\n'}"
fi

if [ -z "${chosen:-}" ]; then
  ok "nothing selected. search-cold-skills is still live."
  exit 0
fi

# move each selection into cold storage
moved=0
while IFS= read -r name; do
  [ -n "$name" ] || continue
  src="$HOT_DIR/$name"
  dst="$COLD_DIR/$name"
  if [ ! -d "$src" ]; then step "skip: $name (not found)"; continue; fi
  if [ -e "$dst" ]; then step "skip: $name (already in cold storage)"; continue; fi
  mv "$src" "$dst"
  step "cooled: $name"
  moved=$((moved + 1))
done <<< "$chosen"

printf '\n'
ok "done. cooled $moved skill(s)."
say "they no longer auto-trigger. reach them with:  cold <name or query>"
