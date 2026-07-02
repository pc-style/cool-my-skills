#!/usr/bin/env bash
# setup.sh — installs the search-cold-skills skill and optionally moves your
# noisy skills into cold storage. Pretty when gum is around, still works without.
set -euo pipefail

REPO_URL="${COOL_MY_SKILLS_REPO:-https://github.com/pc-style/cool-my-skills}"

has() { command -v "$1" >/dev/null 2>&1; }

# ---- flags ------------------------------------------------------------------
DRY_RUN=0
for a in "$@"; do
  case "$a" in
    --dry-run|-n) DRY_RUN=1 ;;
    -h|--help)
      printf 'usage: setup.sh [--dry-run]\n'
      printf '  --dry-run, -n   show the whole flow (banner, prompts, picker) without touching disk\n'
      exit 0 ;;
  esac
done

# Where is this script? When piped (curl | bash) BASH_SOURCE is not a real path.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
SRC_SKILL="$SCRIPT_DIR/skills/search-cold-skills"

# ---- bootstrap: piped with no checkout -> clone ourselves, then re-run -------
if [ ! -d "$SRC_SKILL" ]; then
  has git || { printf 'git is required to bootstrap. install git and retry.\n' >&2; exit 1; }
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  printf 'fetching cool-my-skills...\n'
  git clone --depth 1 "$REPO_URL" "$tmp/repo" >/dev/null 2>&1 \
    || { printf 'could not clone %s\n' "$REPO_URL" >&2; exit 1; }
  bash "$tmp/repo/setup.sh" "$@"
  exit $?
fi

HOT_DIR="${HOT_SKILLS_DIR:-$HOME/.agents/skills}"
COLD_DIR="${COLD_SKILLS_DIR:-$HOME/.agents/skills-cold}"
DEST_SKILL="$HOT_DIR/search-cold-skills"

# Read from the terminal even when stdin is a pipe (curl | bash).
TTY="/dev/tty"
# Actually try to open /dev/tty rather than trusting file-test bits; some
# environments expose the node but can't open it.
have_tty() { ( exec 3<>"$TTY" ) 2>/dev/null; }
is_interactive() { [ "${CI:-}" != "true" ] && have_tty; }
ask() { # ask "prompt" -> echoes the reply
  local reply=""
  printf '%s' "$1" > "$TTY"
  IFS= read -r reply < "$TTY" || true
  printf '%s' "$reply"
}

# ---- gum, with a soft offer to install it ------------------------------------
if ! has gum && is_interactive && has brew; then
  case "$(ask 'gum makes this nicer. install it with homebrew? [y/N] ')" in
    [yY]*) brew install gum || true ;;
  esac
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
dry()  { # dry "message"  -> yellow "would ..." note, only in dry-run
  if has gum; then gum log --level warn "$1"; else printf 'dry-run: %s\n' "$1"; fi
}

confirm() { # confirm "question"  -> 0 yes / 1 no
  local q="$1"
  if ! is_interactive; then return 1; fi
  if has gum; then
    gum confirm "$q" < "$TTY"
  else
    case "$(ask "$q [y/N] ")" in [yY]*) return 0 ;; *) return 1 ;; esac
  fi
}

# ---- the pitch --------------------------------------------------------------
if [ "$DRY_RUN" = 1 ]; then banner "cool-my-skills (dry run)"; else banner "cool-my-skills"; fi
[ "$DRY_RUN" = 1 ] && dry "dry run: showing the whole flow, nothing on disk gets touched."
say "cold skills are skills kept outside the auto-scanned skills dir."
say "they stay silent until you explicitly call them with: cold <name>"
printf '\n'
say "This installer will create ~/.agents/skills-cold, install one hot search"
say "skill, then optionally let you move a few noisy skills into cold storage."
say "Don't move everything. two or three loud skills is usually enough."
printf '\n'

if ! confirm "install search-cold-skills now?"; then
  ok "cancelled. nothing installed."
  exit 0
fi

# ---- install the hot search skill -------------------------------------------
if [ "$DRY_RUN" = 1 ]; then
  dry "would create $COLD_DIR"
  dry "would install search-cold-skills into $HOT_DIR"
  dry "would strip the not-installed warning from the installed SKILL.md"
else
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
fi

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

# pick which ones to move. pass items as args so stdin stays free for the tty.
if has gum && is_interactive; then
  chosen="$(gum choose --no-limit --height 20 \
      --header 'space to select, enter to confirm (pick a few, not all):' \
      "${candidates[@]}" < "$TTY" || true)"
else
  printf 'skills you can cool:\n'
  printf '  - %s\n' "${candidates[@]}"
  chosen="$(ask 'type space-separated names to cool (blank to skip): ')"
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
  if [ "$DRY_RUN" = 1 ]; then
    dry "would cool: $name  ($src -> $dst)"
  else
    mv "$src" "$dst"
    step "cooled: $name"
  fi
  moved=$((moved + 1))
done <<< "$chosen"

printf '\n'
if [ "$DRY_RUN" = 1 ]; then
  ok "dry run done. would have cooled $moved skill(s). nothing was moved."
else
  ok "done. cooled $moved skill(s)."
  say "they no longer auto-trigger. reach them with:  cold <name or query>"
fi
