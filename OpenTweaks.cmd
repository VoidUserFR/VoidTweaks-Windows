@echo off
rem OpenTweaks launcher - opens the GUI with the right PowerShell settings.
rem Some tweaks (and all of the Fixes) need administrator: use the red
rem "Restart as administrator" button at the top of the window.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0OpenTweaks-GUI.ps1"
