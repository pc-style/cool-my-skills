# cool-my-skills

every skill you install adds a tripwire. its `description` gets checked on every single message, so 30 skills means 30 chances for your agent to misfire on something you didn't ask for.

cold skills fix that. a cold skill is just a skill that agreed to shut up until spoken to. it lives in `~/.agents/skills-cold/`, outside the dir your agent auto-scans, so its metadata never loads. you summon it on demand with `cold <name>`, and one small hot skill goes and fetches it.

this repo installs that one hot skill (`search-cold-skills`) and gives you a setup script to move your noisy skills into cold storage.

## install

full experience, one line (installs the skill, then lets you cool some skills right away):

```bash
curl -fsSL https://raw.githubusercontent.com/pc-style/cool-my-skills/main/setup.sh | bash
```

the script clones itself and reads your answers from the terminal, so the picker still works through the pipe. if you'd rather see the code first, clone it:

```bash
git clone https://github.com/pc-style/cool-my-skills
cd cool-my-skills
bash setup.sh
```

or grab just the skill through the skills cli:

```bash
npx skills add pc-style/cool-my-skills -g
```

heads up: `npx skills` only copies files. it doesn't make `~/.agents/skills-cold/`, so the skill ships with a big "not set up yet" warning at the top. run the embedded finisher once and the warning deletes itself:

```bash
bash ~/.agents/skills/search-cold-skills/scripts/install.sh
```

## what setup.sh does

- creates `~/.agents/skills-cold/`
- installs `search-cold-skills` into `~/.agents/skills/`
- strips the not-installed warning
- asks "do you want to cool some skills now?" and lets you pick from your own skills

it's built with [gum](https://github.com/charmbracelet/gum) when you have it, and falls back to plain prompts when you don't.

## the idea

don't go hard here. moving two or three of your loudest, rarely-right skills into cold storage already buys back a lot of quiet. the always-on set stays small and sharp. everything else stays reachable, just silent. being aggressive about it mostly just makes stuff annoying to find.

## using a cold skill

type `cold <name>` or `cold <fuzzy description>`. e.g. `cold to-prd`, `cold something that writes prds`. the search skill greps your cold dir, reads the one match, and follows it for that single request. same instructions, same scripts, loaded on demand instead of by default.
