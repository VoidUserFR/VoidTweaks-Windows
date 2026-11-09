# VoidTweaks — feature research & recommendations

A scan of what the leading Windows optimizers do, and which of it is worth adding to VoidTweaks.
Tools reviewed: **Chris Titus WinUtil**, **O&O ShutUp10++**, **Winaero Tweaker**, **WPD / Privatezilla**, plus esports/latency guides — alongside what we already pulled from **EXM** and **Paragon**.

---

## What VoidTweaks already matches or beats
- Toggle tweaks each with an explicit undo (WinUtil, O&O) — ✅ we have, plus **dry-run** and **live "is it applied?"** which they don't.
- Privacy/telemetry with plain-language descriptions and risk (O&O's colour-coded idea) — ✅ descriptions + risk badges.
- Windows Update control (WinUtil) — ✅ Updates category.
- Debloat / app removal (WinUtil, Win11Debloat) — ✅ Debloat + Services.
- Restore point before applying — ✅.
- RAMMap-style memory purge, Startup manager, Processes, Health, Presets — ✅ (most of these tools don't have them).

So we're already ahead on **transparency, reversibility, and the dashboard/health/process tooling**. The gaps below are where they add things we don't have yet.

---

## Strong additions (high value, low risk) — recommended

1. **App installer (winget-based)** — *WinUtil's headline feature.*
   A list of popular apps (browsers, 7-Zip, VLC, Discord, Steam, Notepad++, etc.) with checkboxes → `winget install`. Plus "update everything" (`winget upgrade --all`). Huge for a fresh PC. Low risk (winget is official). Medium effort.

2. **Backup & Restore** — safety layer.
   - **Export a `.reg` backup** of the keys a tweak touches *before* applying (one-click rollback even for non-reversible ones).
   - **Restore Points manager**: list existing points, create one, and open System Restore to roll back. Easy win, big confidence boost.

3. **DNS benchmark** (extends the Network test).
   Ping several DNS providers (Cloudflare 1.1.1.1, Google 8.8.8.8, Quad9, AdGuard) and recommend the fastest — then offer to set it. Natural follow-on to what we just built.

4. **More "annoyance" QoL toggles** (Winaero's strength) — all low-risk HKCU:
   - Disable lock-screen ads / "Learn about this picture", disable web search in Start, show seconds in the clock, taskbar alignment (left/centre), disable "recommended" Start section, classic volume flyout, disable Snap suggestions, verbose logon status. A pack of ~10.

5. **Scheduled maintenance** (you picked this before) — a Task Scheduler job that runs Boost / clear-temp / flush-DNS weekly.

6. **Full system report export** — specs + applied tweaks + last benchmark + network test → a shareable `.txt`/`.html`.

7. **Discord Rich Presence** (your idea 🙂) — "Using VoidTweaks" activity card. Doable via Discord's local named-pipe RPC; you'd create a free Discord application for the Client ID and upload the black-hole icon. Self-contained module.

---

## Worth considering (medium value / some risk)

- **Timer-resolution tuner** — the clearest-theory gaming tweak (default ~15.6 ms → 0.5 ms). But it needs a *resident* process holding the resolution, costs a little idle power, and the `bcdedit` advice conflicts between guides. Offer as an optional background toggle with a clear warning. *(We already ship `disabledynamictick` + HPET handling, which is the safe part.)*
- **winget-based driver/app update surfacing** — show what has updates.
- **"Recommended" flag per tweak + a visible Recommended view** — O&O-style guidance (we have a Recommended *set* in the CLI; expose it in the app as a badge/filter).
- **Measurement hooks** — a tiny before/after latency or FPS note (LatencyMon-style is overkill, but we could log DPC latency once).

## Deliberately skip (high risk / out of scope)
- **Custom ISO builder** (WinUtil's MicroWin/Win11 Creator) — massive, and not for a single-PC tool.
- **Interrupt affinity / per-device MSI forcing** — niche; guides report little measurable gain and real breakage risk (one user bricked their NIC). We keep GPU MSI as an opt-in Advanced tweak only.
- **Disabling Defender / security** — never (same stance as before).
- **Kernel drivers** (mouse polling, etc.) — unsigned-driver risk.

---

## My suggested next batch
If you want the biggest bang: **App installer**, **Backup & Restore (reg export + restore points)**, **DNS benchmark**, and the **QoL annoyances pack** — then **Discord Rich Presence** and **Scheduled maintenance**. All low-risk, all fit the "transparent & reversible" ethos.

---

### Sources
- [Chris Titus WinUtil — Win11 Creator](https://winutil.christitus.com/guides/win11creator/) · [WinUtil 2026 update](https://daily.dev/posts/windows-utility-2026-the-biggest-update-yet-3zpqcgrmi) · [MemsTechTips overview](https://memstechtips.com/debloat-optimize-windows-11-chris-titus-utility/)
- [O&O ShutUp10++ / Winaero / Privatezilla comparison](https://www.webfactoryltd.com/best-alternatives-to-windows-11-privacy-tools-comparing-winaero-tweaker-privatezilla-and-oo-shutup10/) · [Best debloat tools 2026](https://rain-city.tech/blog/best-windows-debloat/) · [8 privacy tools](https://www.tech2geek.net/8-free-tools-to-improve-windows-11-privacy-and-reduce-tracking/)
- [Blurbusters Esports Optimization Guide](https://forums.blurbusters.com/viewtopic.php?p=96836) · [IRQ priority guide](https://hackingpc.pages.dev/pc-optimization/irq-priority-optimization-windows) · [Optimize Windows for gaming 2026](https://tiereduptech.com/blogs/gaming-knowledge-hub/how-to-optimize-windows-for-gaming-in-2026-complete-guide)
