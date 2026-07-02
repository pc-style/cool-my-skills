---
name: search-cold-skills
description: Use when the user says "cold <skill-name or query>" (e.g. "cold to-prd", "cold something that writes prds"), "Search your skills", or asks to find/use a cold, hidden, or non-autoloaded skill. Searches ~/.agents/skills-cold and manually loads matching skill instructions on demand.
---

<!-- COOL-MY-SKILLS:NOT-INSTALLED:START -->
> [!WARNING]
> **cool-my-skills is not set up on this machine yet.**
>
> This skill needs the cold-storage directory `~/.agents/skills-cold/` to exist
> before it can find anything. It probably got dropped here by a copy-only
> installer (e.g. `npx skills add`), which does not create that directory or run
> any setup.
>
> **Do not try to search cold skills yet.** First run the embedded installer,
> which lives next to this file:
>
> ```bash
> bash "$(dirname "$0")/scripts/install.sh"   # or, from this skill's dir:
> bash scripts/install.sh
> ```
>
> It creates `~/.agents/skills-cold/` and removes this warning. It asks nothing
> and touches nothing else. Once it finishes, re-read this SKILL.md and proceed.
>
> For the full experience (moving your noisy skills into cold storage
> interactively), run `setup.sh` from the cool-my-skills repo instead.
<!-- COOL-MY-SKILLS:NOT-INSTALLED:END -->

# Search Cold Skills

Cold skills live at `~/.agents/skills-cold/<skill-name>/`. They are intentionally outside your agent's auto-discovered skill directories to reduce always-loaded skill metadata (fewer trigger tripwires on every message).

Trigger phrases: `cold <skill-name>`, `cold <query>`, "search your skills", "search cold skills", "use a cold skill", "find a hidden skill".

When invoked:

1. Extract the query (everything after `cold` / the trigger phrase). It may be an exact skill name or a fuzzy description.
2. Run the helper script:

   ```bash
   ~/.agents/skills/search-cold-skills/scripts/query.sh <query>
   ```

   It regenerates `skills-cold/INDEX.md`, searches it (trying hyphenated, stemmed, and partial-word variants of the query), falls back to hot skills if nothing matches, and suggests `--deep` (full SKILL.md body search) as a last resort.
3. If the script is unavailable, search manually with `rg` under `~/.agents/skills-cold`, preferring frontmatter `name:` and `description:` matches, and try hyphenated/stemmed/partial variants of the query before giving up.
4. If exactly one skill clearly matches, read that cold skill's `SKILL.md` fully.
5. If several skills match, show the likely matches and ask the user to choose unless one is clearly strongest.
6. If no cold skill matches but a hot (auto-loaded) skill does, use the hot skill — but explicitly tell the user you fell back to a hot skill.
7. Treat the matched cold skill directory as the skill root. Resolve `scripts/`, `references/`, `resources/`, and other relative paths under that cold skill directory.
8. Follow the cold skill's instructions manually for this request.
9. Respect compatibility, environment, MCP, and tool notes in the cold skill frontmatter/body, but remember your agent will not automatically apply cold skill metadata.
