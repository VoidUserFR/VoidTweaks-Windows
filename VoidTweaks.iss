; VoidTweaks installer — Inno Setup script
; Compile with:  "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" VoidTweaks.iss
; Output: installer\VoidTweaks-Setup.exe

#define MyAppName "VoidTweaks"
#define MyAppVersion "2.7"
#define MyAppPublisher "VoidTweaks"
#define MyAppExe "VoidTweaks.exe"

[Setup]
AppId={{B7F3B2A1-9C4E-4F2A-9B1D-VOIDTWEAKS20}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\VoidTweaks
DefaultGroupName=VoidTweaks
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExe}
OutputDir=installer
OutputBaseFilename=VoidTweaks-Setup
SetupIconFile=VoidTweaks.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"

[Files]
Source: "VoidTweaksApp\bin\publish\VoidTweaks.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "VoidTweaksApp\bin\publish\tweaks.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "VoidTweaksApp\bin\publish\presets.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "VoidTweaksApp\bin\publish\OpenTweaks.Actions.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "VoidTweaksApp\bin\publish\i18n.json"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\VoidTweaks"; Filename: "{app}\{#MyAppExe}"
Name: "{autodesktop}\VoidTweaks"; Filename: "{app}\{#MyAppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExe}"; Description: "Launch VoidTweaks"; Flags: nowait postinstall skipifsilent
