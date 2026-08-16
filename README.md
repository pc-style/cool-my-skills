# cool-my-skills

every skill you install adds a tripwire. its `description` gets checked on every single message, so 30 skills means 30 chances for your agent to misfire on something you didn't ask for.

cold skills fix that. a cold skill is just a skill that agreed to shut up until spoken to. it lives in `~/.agents/skills-cold/`, outside the dir your agent auto-scans, so its metadata never loads. you summon it on demand with `cold <name>`, and one small hot skill goes and fetches it.

this repo installs that one hot skill (`search-cold-skills`) and gives you a setup script to move your noisy skills into cold storage.

> [!IMPORTANT]
> **status: beta.** setup moves directories in your user-level skills store, and there is not yet an automated rollback or tagged release. the supported environments are macOS/Linux with Bash and `rg`, or Windows with PowerShell 7+.

## install

there is no tagged release yet. use the reviewed source snapshot below so the setup code cannot move with `main` between review and execution.

mac / linux:

```bash
REF=a9ae1f162df7730284cc873d9664aa1e225aee8b
git init cool-my-skills
git -C cool-my-skills remote add origin https://github.com/pc-style/cool-my-skills.git
git -C cool-my-skills fetch --depth 1 origin "$REF"
git -C cool-my-skills checkout --detach "$REF"
bash cool-my-skills/setup.sh
```

windows (powershell 7+):

```powershell
$ref = 'a9ae1f162df7730284cc873d9664aa1e225aee8b'
git init cool-my-skills
git -C cool-my-skills remote add origin https://github.com/pc-style/cool-my-skills.git
git -C cool-my-skills fetch --depth 1 origin $ref
git -C cool-my-skills checkout --detach $ref
pwsh -File cool-my-skills/setup.ps1
```

review and change `REF` deliberately when updating. there are no signed bundles or published checksums yet; the immutable git commit is the reproducibility boundary. if either setup script has to bootstrap its own source, it also defaults to this commit and accepts `COOL_MY_SKILLS_REF` as an explicit override.

want to see the flow without moving or writing skills? pass `--dry-run` (`-DryRun` on windows) to the pinned checkout:

```bash
bash cool-my-skills/setup.sh --dry-run
```

```powershell
pwsh -File cool-my-skills/setup.ps1 -DryRun
```

or grab just the skill through the skills cli:

```bash
npx skills add pc-style/cool-my-skills -g
```

the skills CLI follows the repository's current default branch because this project has no tag to select. review what it copied before running the finisher; use the pinned checkout above when you need an immutable install.

heads up: `npx skills` only copies files. it doesn't make `~/.agents/skills-cold/`, so the skill ships with a big "not set up yet" warning at the top. run the embedded finisher once and the warning deletes itself:

```bash
bash ~/.agents/skills/search-cold-skills/scripts/install.sh
```

or on windows:

```powershell
pwsh "$env:USERPROFILE\.agents\skills\search-cold-skills\scripts\install.ps1"
```

if an agent sees that warning, it should stop, tell you the skill is only copied (not installed), explain exactly what that script does, and ask before running it. after it finishes, it should ask if you want to call any cold skills now.

## what setup.sh / setup.ps1 does

- creates `~/.agents/skills-cold/`
- installs `search-cold-skills` into `~/.agents/skills/`
- strips the not-installed warning
- asks "do you want to cool some skills now?" and lets you pick from your own skills

it's built with [gum](https://github.com/charmbracelet/gum) when you have it, and falls back to plain prompts when you don't. `setup.ps1` skips gum and uses plain prompts throughout.

## trust and privacy boundaries

- setup reads skill names and `SKILL.md` files under your configured hot-skills directory, copies `search-cold-skills`, and moves only directories you explicitly select. an existing cold destination is skipped rather than overwritten.
- the local setup and query scripts do not transmit skill contents. when run from the pinned checkout, they need no network access. the convenience skills CLI uses its own network and install behavior.
- on macOS, setup may offer to install optional `gum` through Homebrew; it runs `brew install gum` only after an explicit yes.
- the generated `INDEX.md` contains cold skill names, relative paths, and descriptions and stays in the cold-skills directory.
- loading a cold skill gives its instructions to the agent for that request. cold storage reduces automatic discovery; it does not sandbox or make a skill trustworthy.

this repository is the canonical implementation and has no successor. the source is available under the [MIT license](LICENSE).

## the idea

don't go hard here. moving two or three of your loudest, rarely-right skills into cold storage already buys back a lot of quiet. the always-on set stays small and sharp. everything else stays reachable, just silent. being aggressive about it mostly just makes stuff annoying to find.

## using a cold skill

type `cold <name>` or `cold <fuzzy description>`. e.g. `cold to-prd`, `cold something that writes prds`. the search skill greps your cold dir, reads the one match, and follows it for that single request. same instructions, same scripts, loaded on demand instead of by default.
