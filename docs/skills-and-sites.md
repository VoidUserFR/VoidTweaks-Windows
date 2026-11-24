# Skills & Sites — install list (for my other PC)

Everything we installed / referenced this session, with install commands + what each does.
Skills install into `~/.claude/skills/` (user-global) or via `/plugin`.

_Last updated: 2026-11-24 — no new installs since 2026-11-18; html-demo now powers the site's live demo window._

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

✅ These 6 are live in `~/.claude/skills/` right now.

## 🧩 Skills from earlier this session

| Skill | Source | What it does | Install |
|---|---|---|---|
| **creating-wpf-animations** | `christian289/dotnet-with-claudecode` | WPF animation patterns (Storyboard, easing). Used for the app's UI animations. | `npx skillfish add christian289/dotnet-with-claudecode creating-wpf-animations` |
| **html-demo** | `MengTo/Skills` | Draw an app demo live in HTML (looks recorded, stays crisp). **Now drives the live "See it live" Optimize-view demo window on the site** (`site/assets/vt-demo.js` + `step-window.js/.css`). | `npx skills add MengTo/Skills --skill html-demo` |
| **everything-claude-code (ECC)** | `WorldFlowAI/everything-claude-code` | Big workflow pack: code-review, security-review, planner, TDD, refactor agents. | `claude plugin marketplace add WorldFlowAI/everything-claude-code` then `claude plugin install everything-claude-code` |

## 🧩 Added for web/coding (this session)

| Skill | Source | What it does | Install |
|---|---|---|---|
| **modern-web-guidance** | `GoogleChrome/modern-web-guidance` | Google Chrome team's up-to-date HTML/CSS/JS best-practices search (modals, container queries, view transitions, Core Web Vitals, a11y…). | `git clone https://github.com/GoogleChrome/modern-web-guidance` → copy `skills/modern-web-guidance` into `~/.claude/skills/` |
| **chrome-extensions** | `GoogleChrome/modern-web-guidance` | Build/publish Chrome extensions (Manifest V3). | same repo → copy `skills/chrome-extensions` into `~/.claude/skills/` |
| **superpowers** ✅ | `superpowers-dev` (plugin) | Already installed (v7.0.2): brainstorming, systematic-debugging, TDD, writing-plans, code-review — covers C#/Python/HTML coding workflow. | `/plugin marketplace add obra/superpowers-marketplace` then `/plugin install superpowers` |

> **C# / Lua / Python dedicated skills:** no vetted single-language skill found. **superpowers** (installed) + **modern-web-guidance** cover the real work. To browse more, use the curated list **[travisvn/awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills)** (Claude Code–focused) or **ComposioHQ/awesome-claude-skills**.

---

## 🟡 Mentioned / talked about but NOT installed

These came up this session but I did **not** install them (either they're not a plain skill, or we only talked about them). Install on the other PC if you want them.

| Name | Source | What it is | How to get it |
|---|---|---|---|
| **impeccable** | `pbakaus/impeccable` | Design-**slop detector** CLI + agent hook — catches ugly AI UI before it ships. Not a plain skill (it's a CLI that installs a hook). | `npx impeccable install` (interactive — say yes). Scan: `npx impeccable detect src/` |
| **skiper-ui** (block) | `skiper-ui.com` | A specific animated UI block (skiper40). React/web only — can't be used in the WPF app. | `npx shadcn add @skiper-ui/skiper40` |
| **shadcn/ui** | `ui.shadcn.com` | The React component CLI those blocks install through. Web only. | `npx shadcn@latest init` |
| **browser-video-recording** | Anthropic skill (referenced by html-demo) | Records a real browser to MP4. We never installed it; html-demo just mentions it. | Look it up in the skills catalog if needed. |
| **website-to-motion-design** | Anthropic skill (referenced by html-demo) | Turns a page into a fixed-length motion film. Only referenced, not installed. | Skills catalog. |
| *(superpowers — now confirmed installed, moved up to the web/coding section)* | | | |

> Tooling used but already present: **Playwright** (frame capture), **Pillow** (WebP encoding), **skillfish** / `npx skills` (skill installers), **Inno Setup** (the installer builder).

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
| https://reactdrops.dev/ | React component "drops" — copy-paste animated UI pieces. |
| https://github.com/travisvn/awesome-claude-skills | Curated catalog of Claude Code skills (browse for more C#/Python/etc). |

---

## 📥 Download LATER on the Mac / other PC (not downloaded here)

| Link | Note |
|---|---|
| https://www.instagram.com/reels/DfzwscexBOa/ | Instagram reel — download on the Mac. |

---

*Notes: `npx skills` = MengTo/community skills CLI. `npx skillfish` = skillfish CLI. `/plugin` needs an up-to-date Claude Code (`npm i -g @anthropic-ai/claude-code@latest`). For git-clone skills, the skill folder (the one containing `SKILL.md`) goes into `~/.claude/skills/<name>/`.*
