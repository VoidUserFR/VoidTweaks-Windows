# VoidTweaks

**An open, transparent, simple to use, fully-reversible Windows 11 optimizer.**

VoidTweaks is a free Windows tweaking and cleanup tool. Every change is shown in
plain language, nothing is hidden, nothing phones home, and almost everything can
be reverted with one click. No paywall, no telemetry, no accounts.

**🔥 I made VoidTweaks with the intention of making use of various functions from 
your usual Windows Tweaks app, and make it ALL FREE AND OPEN-SOURCE.
This is because I hate (and I'm sure you do too) paying for stuff**

> ⚠️ **Use at your own risk.** These are real system changes. Keep "Restore point
> first" ticked (on by default) and only apply what you understand. The authors
> are not responsible for any damage.

## Features

- **Home** — live CPU / RAM usage and smart recommendations for your PC.
- **100+ tweaks** grouped by purpose (Performance, Gaming, Privacy, Network,
  Visual, Debloat, Fixes, Services, Updates, Maintenance…). Each card glows
  **green when applied, red when not**, with a toggle to apply/revert.
- **Cleanup** — one-click "clean everything" (temp, caches, Recycle Bin, DNS,
  trim SSD, free RAM) and bulk bloatware removal.
- **Security** — deep virus scanning with Windows Defender (quick / full /
  offline), plus pointers to heavier community tools.
- **Networking** — test your connection + DNS benchmark, with region-tuned advice
  (Europe / Americas / Asia).
- **Overclock** — benchmarks your PC in plain English and gives safe, spec-aware
  tuning advice (benchmark only — it never changes voltages/clocks for you).
- **Game profiles** — one-click reversible tweak sets per game type.
- **Presets** — built-in and your own; export / import your profile.
- **Apps** — install popular apps via winget, grouped by type.
- **Boost** — RAMMap-style memory cleanup in one click.
- **Discord Rich Presence** (optional).

## Install

**Easiest:** download the latest **`VoidTweaks-Setup.exe`** from the
[Releases](../../releases) page and run it.

**Portable:** download **`VoidTweaks-portable.zip`**, unzip, and run
`VoidTweaks.exe` — no install needed. Keep the `.json` and `.ps1` files next to
the `.exe`.

Both builds are self-contained — **.NET is not required** on the target PC.
For admin-only tweaks, right-click → *Run as administrator*.

## Build from source

Requires the [.NET 10 SDK](https://dotnet.microsoft.com/download).

```bash
cd VoidTweaksApp
dotnet build -c Release
# or a self-contained single-file exe:
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

## How it works

- `tweaks.json` — the full, human-readable catalog of tweaks (apply/revert commands).
- `OpenTweaks.Actions.ps1` — shared PowerShell helpers (RAM cleanup, benchmarks, network tests).
- `VoidTweaksApp/` — the C# / WPF-UI (Fluent) app.

Everything a tweak does is visible in `tweaks.json` — no hidden actions.

## License

[MIT](LICENSE) — free to use, modify and share.
