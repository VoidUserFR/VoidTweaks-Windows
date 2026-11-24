## VoidTweaks v3.2

Free, open, fully reversible — everything new since v3.1.

### ✨ New
- **5 new UI styles**, each with its own animated background:
  - **Event Horizon** — a violet gravitational core with rotating accretion rings.
  - **Nebula** — drifting multi-colour gas clouds over a starfield.
  - **Midnight Terminal** — a hacker-style green matrix rain with scanlines.
  - **Synthwave** — a retrowave beach: a cut-bar sun setting into a mirrored ocean, dark hills and palm silhouettes.
  - **Fluent** — soft, slow-moving acrylic light-blooms.
  - Pick any of them in **Settings → UI style**.
- **Unified three-pane layout** — every style except Legacy now uses the clean rail → category → content layout.
- Switching styles now **keeps you in Settings** instead of jumping back to the tweak list.

### 🐛 Fixes
- **"V3.1 doesn't open" on some PCs (#1)** — the app no longer closes silently when something fails at startup. A global crash handler now writes a log to `%LocalAppData%\VoidTweaks\crash.log` and shows a dialog, and the startup path is hardened so one failing subsystem can't block launch. If you still hit a problem, that log tells us exactly what happened — please attach it to a bug report.

### ⬇️ Install
- **Installer:** `VoidTweaks-v3.2-Setup.exe`
- **Portable:** `VoidTweaks-portable.zip` (unzip, keep the `.json` / `.ps1` files next to the `.exe`)
- Self-contained — **.NET is not required**. Verify your download with `SHA256SUMS-v3.2.txt`.
