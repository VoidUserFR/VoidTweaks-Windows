# Clearing the "possibly harmful" / SmartScreen warning

VoidTweaks is unsigned (no paid code-signing cert yet), so Windows flags it on first run.
Nothing malicious — the full source is in this repo. Two separate systems warn, and each
has its own fix. Submit the **exact file from the GitHub release** so the hash matches.

---

## 1. Microsoft Defender (removes "virus/threat" detections)

Use this if Defender or another engine *detects* the file as malware.

1. Go to **https://www.microsoft.com/en-us/wdsi/filesubmission**
2. Sign in and choose **"Software developer"** (not "Home customer").
3. Upload **`VoidTweaks-Setup.exe`** (and `VoidTweaks.exe` if it's flagged too).
4. **Detection name:** paste exactly what Defender showed (e.g. `Program:Win32/Wacapew.C!ml`,
   `Trojan:Script/Wacatac`). Find it in Windows Security → Protection history.
5. **Category:** *"Incorrectly detected as malware / The file is clean."*
6. **Notes:** "Open-source MIT Windows optimizer, self-contained .NET single-file app.
   Source: https://github.com/VoidUserFR/VoidTweaks-Windows . No telemetry. False positive."
7. Submit. Microsoft usually replies in **1–3 days**; on acceptance the flag clears via a
   definition update for everyone.

---

## 2. SmartScreen (removes "Windows protected your PC / unrecognized app")

Use this for the blue "unrecognized app" box and the browser "this file may be harmful".

1. On the SmartScreen box, click **More info → Report this app as safe** (opens a form), **or**
   go to **https://feedback.smartscreen.microsoft.com/** and choose **"I think this file is safe."**
2. Enter the **GitHub release asset URL** of `VoidTweaks-Setup.exe` and a short reason
   (open-source, MIT, link the repo).
3. Submit.

> ⚠️ SmartScreen reputation is built mostly from **code signing + download volume**, so a
> submission helps but isn't guaranteed. A signing certificate is the only instant, reliable
> fix (OV ≈ $70–200/yr; EV ≈ $250–400/yr + token, clears SmartScreen immediately).

---

## 3. What we already do to reduce flags

- The installer carries full version metadata (publisher, product, version, repo URLs).
- Everything is open-source and auditable — anyone can build it themselves (see the README).
- No packing/obfuscation beyond the standard .NET single-file bundle.

## For users who just want to run it now

On the SmartScreen box: **More info → Run anyway**. Or build from source (README → Build).
