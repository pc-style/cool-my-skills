---
name: search-cold-skills
description: Use when the user says "cold <skill-name or query>" (e.g. "cold to-prd", "cold something that writes prds"), "Search your skills", or asks to find/use a cold, hidden, or non-autoloaded skill. Searches ~/.agents/skills-cold and manually loads matching skill instructions on demand.
---

<!-- COOL-MY-SKILLS:NOT-INSTALLED:START -->
> [!WARNING]
> **cool-my-skills has been copied here, but it has not been installed.**
>
> This usually happens after a copy-only install such as `npx skills add`.
> That copies this skill, but it does not create `~/.agents/skills-cold/` or
> finish initialization.
>
> **Do not search cold skills yet.** Tell the user it is not installed, then ask
> if they want to run this embedded initialization script:
>
> ```bash
> bash "$(dirname "$0")/scripts/install.sh"   # or, from this skill's dir:
> bash scripts/install.sh
> ```
>
> Before asking, explain that the script will only:
>
> - create `~/.agents/skills-cold/`
> - remove this warning from this copied `SKILL.md`
> - make `scripts/query.sh` executable
>
> After the user agrees and the script completes, ask whether they want to call
> any cold skills now. If they want the interactive picker for moving existing
> skills into cold storage, tell them to run the repo's `setup.sh` instead.
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
