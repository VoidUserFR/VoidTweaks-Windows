# Skills & Sites — install list (for my other PC)

Everything we installed / referenced this session, with install commands + what each does.
Skills install into `~/.claude/skills/` (user-global) or via `/plugin`.

---

## 🧩 Skills installed THIS session

| Skill | Source | What it does | Install |
|---|---|---|---|
| **ponytail** | `DietrichGebert/ponytail` | Makes the agent **write less code** (YAGNI). Cuts lines ~50%. | `npx skills add DietrichGebert/ponytail --skill ponytail --agent claude-code` — or `/plugin marketplace add DietrichGebert/ponytail` then `/plugin install ponytail@ponytail` |
| **caveman** | `JuliusBrussee/caveman` | Ultra-compressed replies (caveman speak), ~75% fewer tokens, keeps technical accuracy. Levels: lite/full/ultra. | `npx skills add JuliusBrussee/caveman --skill caveman --agent claude-code` |
| **security-audit** | `cloudflare/security-audit-skill` | Security review / vulnerability research / pen-test workflow for codebases, APIs, CLIs. | `git clone https://github.com/cloudflare/security-audit-skill` → copy `skills/security-audit` into `~/.claude/skills/` |
| **hallmark** | `Nutlope/hallmark` | Makes **new** websites/pages look designed, not AI-generated. (New designs only.) | `git clone https://github.com/Nutlope/hallmark` → copy `skills/hallmark` into `~/.claude/skills/` |
| **taste-skill** (design-taste-frontend) | `Leonxlnx/taste-skill` | Frontend **design taste** — good-looking UI judgment. Has `install.sh`. | `git clone https://github.com/Leonxlnx/taste-skill && cd taste-skill && ./install.sh` |
| **cli-anything** | `HKUDS/CLI-Anything` | Build Python **CLI harnesses** that drive GUI apps / source repos so an agent can control them. | `git clone https://github.com/HKUDS/CLI-Anything` → copy `cli-hub-meta-skill` into `~/.claude/skills/cli-anything` |
| **impeccable** ⚠️ | `pbakaus/impeccable` | Design-**slop detector** CLI + agent hook. Catches ugly AI UI before it ships. *(CLI tool, not a plain skill — not auto-installed here.)* | `npx impeccable install` (sets up the design hook interactively — say yes). Scan: `npx impeccable detect src/` |

## 🧩 Skills from earlier this session

| Skill | Source | What it does | Install |
|---|---|---|---|
| **creating-wpf-animations** | `christian289/dotnet-with-claudecode` | WPF animation patterns (Storyboard, easing). Used for the app's UI animations. | `npx skillfish add christian289/dotnet-with-claudecode creating-wpf-animations` |
| **html-demo** | `MengTo/Skills` | Draw an app demo live in HTML (looks recorded, stays crisp). Used for the README GIF. | `npx skills add MengTo/Skills --skill html-demo` |
| **everything-claude-code (ECC)** | `WorldFlowAI/everything-claude-code` | Big workflow pack: code-review, security-review, planner, TDD, refactor agents. | `claude plugin marketplace add WorldFlowAI/everything-claude-code` then `claude plugin install everything-claude-code` |

---

## 🎨 Websites to remember (design / animation / components)

| Site | What it's for |
|---|---|
| https://prompt-motion.com/ | Motion/animation prompt ideas for building animated UIs. |
| https://magicui.design/ | Animated React components (copy-paste), design inspiration. |
| https://www.cult-ui.com/ | Polished React UI components. |
| https://skiper-ui.com/ | React UI components. Install a block: `npx shadcn add @skiper-ui/skiper40`. |
| https://componentry.dev/ | Component library / UI building blocks. |
| https://gsap.com/ | GSAP — the pro JS animation library (timelines, scroll, SVG). |

---

## 📥 Download LATER on the Mac / other PC (not downloaded here)

| Link | Note |
|---|---|
| https://www.instagram.com/reels/DfzwscexBOa/ | Instagram reel — download on the Mac. |

---

*Notes: `npx skills` = MengTo/community skills CLI. `npx skillfish` = skillfish CLI. `/plugin` needs an up-to-date Claude Code (`npm i -g @anthropic-ai/claude-code@latest`). For git-clone skills, the skill folder (the one containing `SKILL.md`) goes into `~/.claude/skills/<name>/`.*
