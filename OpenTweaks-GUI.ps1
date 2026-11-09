<#
.SYNOPSIS
    OpenTweaks - a transparent, reversible Windows optimizer with a real GUI.

.DESCRIPTION
    A native WPF window (no Electron, no install) that reads tweaks.json next to
    it and lets you Scan, Apply and Revert tweaks per-category from menus.

    Everything is local and open: no account, no telemetry, no network calls, no
    paywall. The "Scan PC" button reads your actual settings and shows, per tweak,
    whether it is Applied / Not applied / Custom, and for the Fixes category whether
    an issue was found. You can create a System Restore point before applying, and
    preview any change with Dry run.

.NOTES
    Run it with the OpenTweaks.cmd launcher (handles STA + execution policy), or:
      powershell -NoProfile -ExecutionPolicy Bypass -STA -File .\OpenTweaks-GUI.ps1
#>
param(
    [switch]$NoShow   # build everything but don't show the window (used for self-test)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml | Out-Null

# Fast native perf counters (no WMI) so the dashboard never stutters the UI thread.
if (-not ('OTPerf.Sys' -as [type])) {
    Add-Type -Namespace OTPerf -Name Sys -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)] public struct MEMSTAT { public uint dwLength; public uint dwMemoryLoad; public ulong ullTotalPhys; public ulong ullAvailPhys; public ulong ullTotalPageFile; public ulong ullAvailPageFile; public ulong ullTotalVirtual; public ulong ullAvailVirtual; public ulong ullAvailExtendedVirtual; }
[DllImport("kernel32.dll")] public static extern bool GlobalMemoryStatusEx(ref MEMSTAT lpBuffer);
[DllImport("kernel32.dll")] public static extern bool GetSystemTimes(out long idle, out long kernel, out long user);
'@
}

# ---------------------------------------------------------------- paths / catalog
$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$catalogPath = Join-Path $scriptDir 'tweaks.json'
$logDir      = Join-Path $env:LOCALAPPDATA 'VoidTweaks'
$logFile     = Join-Path $logDir 'voidtweaks.log'
if (-not (Test-Path $catalogPath)) { throw "Catalog not found: $catalogPath" }
$catalog = Get-Content $catalogPath -Raw | ConvertFrom-Json

$RecommendedIds = @(
    'perf-startup-delay', 'perf-sysmain', 'perf-high-power-plan',
    'visual-best-performance', 'visual-transparency-off', 'visual-menu-delay',
    'priv-suggested-content', 'game-dvr-off', 'debloat-widgets',
    'clean-temp', 'clean-windows-temp'
)

$script:stateCache = @{}
$script:running    = $false
$script:isAdmin    = $false

# ---------------------------------------------------------------- settings / themes / density
$settingsFile = Join-Path $logDir 'settings.json'
function Get-Settings {
    $def = @{ theme = 'softdark'; density = 'simple'; seenTutorial = $false }
    if (Test-Path $settingsFile) {
        try { $s = Get-Content $settingsFile -Raw | ConvertFrom-Json; foreach ($k in @('theme', 'density', 'seenTutorial')) { if ($null -ne $s.$k) { $def[$k] = $s.$k } } } catch {}
    }
    $def
}
function Save-Settings { param($s)
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force $logDir | Out-Null }
    [pscustomobject]$s | ConvertTo-Json | Set-Content $settingsFile -Encoding utf8
}
$script:settings = Get-Settings

$Themes = @{
    'dark'     = @{ win = '#FF16161C'; sidebar = '#FF1C1C24'; border = '#FF26262E'; fg = '#FFECECF1'; warnbg = '#FF3A2A14'; warnborder = '#FF5A4418'; orange = '#FFD29922'; warnfg = '#FFEAD9A6'; dashbg = '#FF1A1A22'; faint = '#FF6E6E7B'; accent = '#FF7C6CF0'; surface2 = '#FF2A2A36'; muted = '#FF8E8E9C'; logbg = '#FF101016'; logfg = '#FF9FE0A6'; inputbg = '#FF121219'; inputborder = '#FF2C2C38'; sidefg = '#FFB6B6C4'; hover = '#FF23232E'; selbg = '#FF26233A'; card = '#FF20202A'; cardhover = '#FF262633'; cardhoverb = '#FF3B3B4C'; fg2 = '#FFC7C7D2'; green = '#FF2FA64B'; ghostfg = '#FFCFCFD8'; ghostborder = '#FF3A3A48'; teal = '#FF17B0A3'; red = '#FFE5534B'; blue = '#FF4C8DFF' }
    'softdark' = @{ win = '#FF141418'; sidebar = '#FF17171D'; border = '#FF2A2A34'; fg = '#FFEDEEF2'; warnbg = '#FF362716'; warnborder = '#FF55411A'; orange = '#FFE5AA3D'; warnfg = '#FFEAD9A6'; dashbg = '#FF1A1A20'; faint = '#FF6B6B77'; accent = '#FF8B7CF0'; surface2 = '#FF262630'; muted = '#FF9A9AA6'; logbg = '#FF121218'; logfg = '#FFA8E3AE'; inputbg = '#FF121218'; inputborder = '#FF2A2A34'; sidefg = '#FFBFC0CC'; hover = '#FF24242E'; selbg = '#FF2A2740'; card = '#FF1E1E26'; cardhover = '#FF24242E'; cardhoverb = '#FF343442'; fg2 = '#FFCFD0D8'; green = '#FF4CC38A'; ghostfg = '#FFCFD0D8'; ghostborder = '#FF343442'; teal = '#FF35B9AD'; red = '#FFEF6A60'; blue = '#FF5B9BFF' }
    'light'    = @{ win = '#FFF4F4F8'; sidebar = '#FFEDEDF3'; border = '#FFD9D9E3'; fg = '#FF20202A'; warnbg = '#FFFBEFD2'; warnborder = '#FFE7D8A6'; orange = '#FFB9810F'; warnfg = '#FF6A5312'; dashbg = '#FFEDEDF3'; faint = '#FF9A9AA8'; accent = '#FF6D5AE6'; surface2 = '#FFDFDFE8'; muted = '#FF6E6E7C'; logbg = '#FFEFEFF4'; logfg = '#FF2E7D4F'; inputbg = '#FFFFFFFF'; inputborder = '#FFD0D0DC'; sidefg = '#FF4A4A58'; hover = '#FFE4E4EE'; selbg = '#FFE6E1FA'; card = '#FFFFFFFF'; cardhover = '#FFF6F6FB'; cardhoverb = '#FFD0D0DC'; fg2 = '#FF3A3A46'; green = '#FF2E9E4C'; ghostfg = '#FF3A3A46'; ghostborder = '#FFD0D0DC'; teal = '#FF1AA296'; red = '#FFD23A2E'; blue = '#FF2D6FE0' }
    'comfy'    = @{ win = '#FFF3EEE7'; sidebar = '#FFEDE6DC'; border = '#FFDBD1C3'; fg = '#FF3A332B'; warnbg = '#FFF7E6C8'; warnborder = '#FFE0CDA0'; orange = '#FFB97F1E'; warnfg = '#FF6A5312'; dashbg = '#FFEDE6DC'; faint = '#FFA89C89'; accent = '#FFC57B4E'; surface2 = '#FFE2D9CA'; muted = '#FF897F70'; logbg = '#FFF3EEE7'; logfg = '#FF3A7D4F'; inputbg = '#FFFBF8F3'; inputborder = '#FFD8CEBD'; sidefg = '#FF5A5146'; hover = '#FFE6DED2'; selbg = '#FFEDE0CC'; card = '#FFFBF8F3'; cardhover = '#FFF6F1E9'; cardhoverb = '#FFD8CEBD'; fg2 = '#FF5A5146'; green = '#FF4E9E5A'; ghostfg = '#FF5A5146'; ghostborder = '#FFD8CEBD'; teal = '#FF3AA69A'; red = '#FFC2492E'; blue = '#FF3F7AD0' }
}
# literal colours used in the XAML -> semantic role (single-pass remap at load)
$Sem = @{
    '#FF16161C' = 'win'; '#FF1C1C24' = 'sidebar'; '#FF26262E' = 'border'; '#FFECECF1' = 'fg'; '#FF3A2A14' = 'warnbg'
    '#FF5A4418' = 'warnborder'; '#FFD29922' = 'orange'; '#FFEAD9A6' = 'warnfg'; '#FF1A1A22' = 'dashbg'; '#FF6E6E7B' = 'faint'
    '#FF7C6CF0' = 'accent'; '#FF2A2A36' = 'surface2'; '#FF8E8E9C' = 'muted'; '#FF101016' = 'logbg'; '#FF9FE0A6' = 'logfg'
    '#FF121219' = 'inputbg'; '#FF2C2C38' = 'inputborder'; '#FFB6B6C4' = 'sidefg'; '#FF23232E' = 'hover'; '#FF26233A' = 'selbg'
    '#FF20202A' = 'card'; '#FF262633' = 'cardhover'; '#FF3B3B4C' = 'cardhoverb'; '#FFC7C7D2' = 'fg2'; '#FF2FA64B' = 'green'
    '#FFCFCFD8' = 'ghostfg'; '#FF3A3A48' = 'ghostborder'; '#FF17B0A3' = 'teal'
}
$Densities = @{
    'simple'  = @{ fs = 13; hfs = 22; rad = 13; brad = 9;  cpad = 15; cmargin = '0,0,0,11' }
    'compact' = @{ fs = 12; hfs = 18; rad = 8;  brad = 7;  cpad = 10; cmargin = '0,0,0,6' }
    'big'     = @{ fs = 15; hfs = 26; rad = 12; brad = 10; cpad = 20; cmargin = '0,0,0,14' }
    'smooth'  = @{ fs = 14; hfs = 24; rad = 16; brad = 12; cpad = 18; cmargin = '0,0,0,12' }
}
if (-not $Themes.ContainsKey($script:settings.theme)) { $script:settings.theme = 'softdark' }
if (-not $Densities.ContainsKey($script:settings.density)) { $script:settings.density = 'simple' }
$T = $Themes[$script:settings.theme]
$D = $Densities[$script:settings.density]
$Hex = @{ fg = $T.fg; muted = $T.muted; faint = $T.faint; white = '#FFFFFFFF'; accent = $T.accent; green = $T.green; orange = $T.orange; red = $T.red; blue = $T.blue; teal = $T.teal; card = $T.card }

# ---------------------------------------------------------------- helpers
function Write-FileLog {
    param([string]$Message)
    try {
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
        "$([DateTime]::Now.ToString('s'))  $Message" | Add-Content -Path $logFile -Encoding utf8
    } catch {}
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltinRole]::Administrator)
}

# One-time system-spec scan so tweak evaluation uses real hardware (e.g. SSD vs HDD).
function Get-SysInfo {
    if ($script:sysInfo) { return $script:sysInfo }
    $i = @{}
    try { $c = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1; $i.Cpu = ($c.Name).Trim(); $i.Cores = "$($c.NumberOfCores)C / $($c.NumberOfLogicalProcessors)T" } catch { $i.Cpu = 'Unknown CPU'; $i.Cores = '' }
    try { $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop; $i.RamGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 0) } catch { $i.RamGB = '?' }
    try {
        $gg = Get-CimInstance Win32_VideoController -ErrorAction Stop
        $gp = $gg | Where-Object { $_.Name -and $_.Name -notmatch 'Meta|Virtual|Basic|Remote|Mirror|Parsec|DisplayLink' -and "$($_.Status)" -eq 'OK' } | Select-Object -First 1
        if (-not $gp) { $gp = $gg | Where-Object { $_.CurrentHorizontalResolution } | Select-Object -First 1 }
        $i.Gpu = if ($gp) { $gp.Name } else { 'Unknown GPU' }
    } catch { $i.Gpu = 'Unknown GPU' }
    try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop; $dv = Get-RegVal 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'DisplayVersion'; $i.Os = ($os.Caption -replace 'Microsoft ', '') + $(if ($dv) { " $dv" }) + " (build $($os.BuildNumber))" } catch { $i.Os = 'Windows' }
    try { $pd = Get-Partition -DriveLetter ($env:SystemDrive[0]) -ErrorAction Stop | Get-Disk -ErrorAction Stop | Get-PhysicalDisk -ErrorAction Stop; $i.Media = "$($pd.MediaType)" } catch { $i.Media = 'Unknown' }
    $script:sysInfo = $i
    $i
}

function Get-RegVal {
    param([string]$Path, [string]$Name)
    try { return (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name } catch { return $null }
}

# Parse a 'reg add "KEY" /v NAME /t TYPE /d VALUE /f' command into parts (best effort).
function Get-RegOp {
    param([string]$Command)
    $m = [regex]::Match($Command, 'reg add "([^"]+)" /v (\S+) /t (\S+) /d (\S+) /f')
    if (-not $m.Success) { return $null }
    [pscustomobject]@{
        Path  = 'Registry::' + ($m.Groups[1].Value -replace '^HKLM', 'HKEY_LOCAL_MACHINE' -replace '^HKCU', 'HKEY_CURRENT_USER')
        Name  = $m.Groups[2].Value
        Value = $m.Groups[4].Value
    }
}

# Returns: applied | default | custom | issue | ok | action | n/a
function Get-TweakState {
    param($t)
    try {
        switch ($t.id) {
            'fix-wu-service' {
                foreach ($n in 'wuauserv', 'UsoSvc', 'bits') {
                    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
                    if ($s -and "$($s.StartType)" -eq 'Disabled') { return 'issue' }
                }
                return 'ok'
            }
            'fix-wu-policy' {
                $au = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
                $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
                if ((Get-RegVal $au 'NoAutoUpdate') -eq 1 -or (Get-RegVal $au 'UseWUServer') -eq 1 -or
                    (Get-RegVal $wu 'WUServer') -or (Get-RegVal $wu 'TargetReleaseVersion') -eq 1) { return 'issue' }
                return 'ok'
            }
            'perf-high-power-plan' {
                $a = if ($script:scanPower) { $script:scanPower } else { (powercfg /getactivescheme) -join ' ' }
                if ($a -match '8c5e7fda') { return 'applied' }
                if ($a -match '381b4222') { return 'default' }
                return 'custom'
            }
            'perf-hibernation-off' {
                $v = Get-RegVal 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled'
                if ($v -eq 0) { return 'applied' }
                if ($v -eq 1) { return 'default' }
                return 'n/a'
            }
            'adv-dynamic-tick-off' {
                $b = (bcdedit /enum '{current}' 2>&1) -join "`n"
                if ($b -match 'disabledynamictick\s+Yes') { return 'applied' } else { return 'default' }
            }
            'adv-platform-clock-off' {
                $b = (bcdedit /enum '{current}' 2>&1) -join "`n"
                if ($b -match 'useplatformclock\s+Yes') { return 'custom' } else { return 'applied' }
            }
            'adv-gpu-msi-mode' { return 'n/a' }
            'net-nagle-off' {
                $base = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
                $hit = Get-ChildItem $base -ErrorAction SilentlyContinue |
                    Where-Object { (Get-RegVal $_.PSPath 'TcpAckFrequency') -eq 1 }
                if ($hit) { return 'applied' } else { return 'default' }
            }
            'perf-ultimate-power' {
                $a = if ($script:scanPower) { $script:scanPower } else { (powercfg /getactivescheme) -join ' ' }
                if ($a -match 'e9a42b02') { return 'applied' }
                if ($a -match '381b4222') { return 'default' }
                return 'custom'
            }
            'adv-mem-compression-off' { $mm = if ($script:scanMm) { $script:scanMm } else { try { Get-MMAgent -ErrorAction Stop } catch { $null } }; if (-not $mm) { return 'n/a' }; if (-not $mm.MemoryCompression) { return 'applied' } else { return 'default' } }
            'net-autotuning-off' { $n = if ($script:scanNet) { $script:scanNet } else { try { Get-NetTCPSetting -SettingName Internet -ErrorAction Stop } catch { $null } }; if (-not $n) { return 'n/a' }; if ($n.AutoTuningLevelLocal -eq 'Disabled') { return 'applied' } else { return 'default' } }
            'net-rsc-off'        { $n = if ($script:scanRsc) { $script:scanRsc } else { try { Get-NetOffloadGlobalSetting -ErrorAction Stop } catch { $null } }; if (-not $n) { return 'n/a' }; if ($n.ReceiveSegmentCoalescing -eq 'Disabled') { return 'applied' } else { return 'default' } }
            'net-ecn-off'        { $n = if ($script:scanNet) { $script:scanNet } else { try { Get-NetTCPSetting -SettingName Internet -ErrorAction Stop } catch { $null } }; if (-not $n) { return 'n/a' }; if ($n.EcnCapability -eq 'Disabled') { return 'applied' } else { return 'default' } }
            'net-timestamps-off' { $n = if ($script:scanNet) { $script:scanNet } else { try { Get-NetTCPSetting -SettingName Internet -ErrorAction Stop } catch { $null } }; if (-not $n) { return 'n/a' }; if ($n.Timestamps -eq 'Disabled') { return 'applied' } else { return 'default' } }
            'net-heuristics-off' { return 'n/a' }
            'net-dns-cloudflare' { $d = if ($null -ne $script:scanDns) { $script:scanDns } else { try { @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop | Select-Object -ExpandProperty ServerAddresses) } catch { @() } }; if ($d -contains '1.1.1.1') { return 'applied' } else { return 'default' } }
            'debloat-onedrive' { if (Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe") { return 'default' } else { return 'applied' } }
            'upd-pause-updates' {
                $e = Get-RegVal 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'PauseUpdatesExpiryTime'
                if ($e) { try { if ([datetime]$e -gt (Get-Date)) { return 'applied' } } catch { return 'applied' } }
                return 'default'
            }
            'rc-win10-menu' { if (Test-Path 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32') { return 'applied' } else { return 'default' } }
            'rc-copyto'     { if (Test-Path 'HKLM:\SOFTWARE\Classes\AllFilesystemObjects\shellex\ContextMenuHandlers\CopyTo') { return 'applied' } else { return 'default' } }
            'rc-moveto'     { if (Test-Path 'HKLM:\SOFTWARE\Classes\AllFilesystemObjects\shellex\ContextMenuHandlers\MoveTo') { return 'applied' } else { return 'default' } }
        }
        if ($t.id -in 'clean-temp', 'clean-windows-temp', 'net-flush-dns', 'fix-wu-reset', 'fix-sfc-dism', 'fix-network-reset',
                      'maint-free-ram', 'maint-purge-standby', 'maint-trim-ssd', 'maint-empty-recyclebin', 'maint-benchmark', 'maint-network-test',
                      'maint-clear-store-cache', 'maint-clear-thumbnails', 'maint-restart-explorer') { return 'action' }

        # app removals (Get-AppxPackage *X* | Remove-AppxPackage) -> present = default, gone = applied
        $joined = ($t.apply -join ' ')
        if ($joined -match 'Remove-AppxPackage') {
            $am = [regex]::Match($joined, 'Get-AppxPackage (?:-AllUsers )?\*([^*]+)\*')
            if ($am.Success) {
                $pat = $am.Groups[1].Value.ToLower()
                if ($null -ne $script:scanAppx) {
                    if ($script:scanAppx | Where-Object { $_ -like "*$pat*" }) { return 'default' } else { return 'applied' }
                }
                if (Get-AppxPackage -Name ('*' + $am.Groups[1].Value + '*') -ErrorAction SilentlyContinue) { return 'default' } else { return 'applied' }
            }
        }

        # service-based tweaks (e.g. Set-Service -Name SysMain -StartupType Disabled)
        $svcm = [regex]::Match(($t.apply -join ' '), 'Set-Service -Name (\w+) -StartupType (\w+)')
        if ($svcm.Success) {
            $s = Get-Service -Name $svcm.Groups[1].Value -ErrorAction SilentlyContinue
            if (-not $s) { return 'n/a' }
            if ("$($s.StartType)" -eq $svcm.Groups[2].Value) { return 'applied' } else { return 'default' }
        }

        # registry-based tweaks
        $op = $null
        foreach ($c in $t.apply) { $op = Get-RegOp $c; if ($op) { break } }
        if ($op) {
            try { $current = Get-ItemPropertyValue -Path $op.Path -Name $op.Name -ErrorAction Stop }
            catch { return 'default' }
            $cur = "$current"; $want = "$($op.Value)"
            $n1 = 0; $n2 = 0
            if ([int64]::TryParse($cur, [ref]$n1) -and [int64]::TryParse($want, [ref]$n2)) {
                if ($n1 -eq $n2 -or ($n2 -eq 4294967295 -and $n1 -eq -1)) { return 'applied' }
                return 'custom'
            }
            if ($cur -eq $want) { return 'applied' } else { return 'custom' }
        }
        return 'n/a'
    } catch { return 'n/a' }
}

# ---------------------------------------------------------------- XAML
$xamlStr = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="VoidTweaks" Height="760" Width="1120"
        WindowStartupLocation="CenterScreen" Background="#FF16161C"
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="__FS__" TextOptions.TextFormattingMode="Ideal">
  <Window.Resources>

    <!-- base rounded button template; variants only change Background -->
    <Style x:Key="BtnBase" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Padding" Value="14,7"/>
      <Setter Property="SnapsToDevicePixels" Value="True"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" CornerRadius="__BRAD__" Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                    Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Opacity" Value="0.86"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="bd" Property="Opacity" Value="0.7"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="bd" Property="Opacity" Value="0.4"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="AccentButton"  TargetType="Button" BasedOn="{StaticResource BtnBase}">
      <Setter Property="Background" Value="#FF7C6CF0"/>
    </Style>
    <Style x:Key="SuccessButton" TargetType="Button" BasedOn="{StaticResource BtnBase}">
      <Setter Property="Background" Value="#FF2FA64B"/>
    </Style>
    <Style x:Key="GhostButton"   TargetType="Button" BasedOn="{StaticResource BtnBase}">
      <Setter Property="Background" Value="#FF2A2A36"/>
      <Setter Property="Foreground" Value="#FFCFCFD8"/>
      <Setter Property="BorderBrush" Value="#FF3A3A48"/>
      <Setter Property="BorderThickness" Value="1"/>
    </Style>

    <!-- search box -->
    <Style x:Key="SearchBox" TargetType="TextBox">
      <Setter Property="Foreground" Value="#FFECECF1"/>
      <Setter Property="CaretBrush" Value="#FFECECF1"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border x:Name="bd" CornerRadius="__BRAD__" Background="#FF121219"
                    BorderBrush="#FF2C2C38" BorderThickness="1" Padding="10,7">
              <ScrollViewer x:Name="PART_ContentHost"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="bd" Property="BorderBrush" Value="#FF7C6CF0"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- sidebar item -->
    <Style x:Key="SideItem" TargetType="ListBoxItem">
      <Setter Property="Foreground" Value="#FFB6B6C4"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Margin" Value="6,1"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <Grid>
              <Border x:Name="bd" CornerRadius="__BRAD__" Background="Transparent" Padding="12,9"><ContentPresenter VerticalAlignment="Center"/></Border>
              <Border x:Name="stripe" Width="3" HorizontalAlignment="Left" Margin="0,8" CornerRadius="2" Background="#FF7C6CF0" Visibility="Collapsed"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#FF23232E"/></Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#FF26233A"/>
                <Setter TargetName="stripe" Property="Visibility" Value="Visible"/>
                <Setter Property="Foreground" Value="White"/>
                <Setter Property="FontWeight" Value="SemiBold"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- tweak card -->
    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background" Value="#FF20202A"/>
      <Setter Property="CornerRadius" Value="__RAD__"/>
      <Setter Property="BorderBrush" Value="#FF2A2A36"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="__CPAD__"/>
      <Setter Property="Margin" Value="__CMARGIN__"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="#FF262633"/>
          <Setter Property="BorderBrush" Value="#FF3B3B4C"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <Style x:Key="CheckLight" TargetType="CheckBox">
      <Setter Property="Foreground" Value="#FFC7C7D2"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
    </Style>
  </Window.Resources>

  <DockPanel>
    <Menu DockPanel.Dock="Top" Background="#FF1C1C24" Padding="4,2">
      <MenuItem Header="_File" Foreground="#FFECECF1">
        <MenuItem x:Name="MiScan"   Header="_Scan PC now"          Foreground="#FF202020"/>
        <Separator/>
        <MenuItem x:Name="MiExport" Header="_Export profile..."    Foreground="#FF202020"/>
        <MenuItem x:Name="MiImport" Header="_Import profile..."    Foreground="#FF202020"/>
        <Separator/>
        <MenuItem x:Name="MiExit"   Header="E_xit"                 Foreground="#FF202020"/>
      </MenuItem>
      <MenuItem Header="_Actions" Foreground="#FFECECF1">
        <MenuItem x:Name="MiRecommended" Header="Apply _Recommended set (slow PC)" Foreground="#FF202020"/>
        <MenuItem x:Name="MiUndo"        Header="_Undo last apply"                Foreground="#FF202020"/>
        <MenuItem x:Name="MiRevertAll"   Header="Re_vert everything"               Foreground="#FF202020"/>
        <Separator/>
        <MenuItem x:Name="MiRestore"     Header="Create a restore _point now"      Foreground="#FF202020"/>
      </MenuItem>
      <MenuItem Header="_Help" Foreground="#FFECECF1">
        <MenuItem x:Name="MiShortcut" Header="Create desktop + _Start shortcuts" Foreground="#FF202020"/>
        <MenuItem x:Name="MiLog"   Header="Open _log folder" Foreground="#FF202020"/>
        <MenuItem x:Name="MiAbout" Header="_About"           Foreground="#FF202020"/>
      </MenuItem>
    </Menu>

    <Border x:Name="AdminBar" DockPanel.Dock="Top" Background="#FF3A2A14" Padding="14,8" BorderBrush="#FF5A4418" BorderThickness="0,0,0,1">
      <DockPanel>
        <Button x:Name="ElevateBtn" DockPanel.Dock="Right" Content="Restart as administrator"
                Style="{StaticResource BtnBase}" Background="#FFD29922" Padding="12,5"/>
        <TextBlock x:Name="AdminText" Foreground="#FFEAD9A6" VerticalAlignment="Center" FontSize="13"
                   Text="&#xE7BA;  Not elevated - admin tweaks and the Fixes stay disabled until you restart as administrator."/>
      </DockPanel>
    </Border>

    <Border x:Name="Dashboard" DockPanel.Dock="Top" Background="#FF1A1A22" Padding="18,9" BorderBrush="#FF26262E" BorderThickness="0,0,0,1">
      <StackPanel Orientation="Horizontal">
        <StackPanel Margin="0,0,26,0" VerticalAlignment="Center">
          <TextBlock Text="MEMORY" Foreground="#FF6E6E7B" FontSize="9.5" FontWeight="SemiBold"/>
          <Grid Width="168" Margin="0,4,0,0">
            <ProgressBar x:Name="DashRamBar" Height="18" Minimum="0" Maximum="100" Foreground="#FF7C6CF0" Background="#FF2A2A36" BorderThickness="0"/>
            <TextBlock x:Name="DashRamText" Text="--" Foreground="White" FontSize="10.5" FontWeight="SemiBold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Grid>
        </StackPanel>
        <StackPanel Margin="0,0,26,0" VerticalAlignment="Center">
          <TextBlock Text="CPU" Foreground="#FF6E6E7B" FontSize="9.5" FontWeight="SemiBold"/>
          <TextBlock x:Name="DashCpu" Text="--%" Foreground="#FFECECF1" FontSize="16" FontWeight="SemiBold" Margin="0,2,0,0"/>
        </StackPanel>
        <StackPanel Margin="0,0,26,0" VerticalAlignment="Center">
          <TextBlock Text="SYSTEM DISK" Foreground="#FF6E6E7B" FontSize="9.5" FontWeight="SemiBold"/>
          <TextBlock x:Name="DashDisk" Text="--" Foreground="#FFECECF1" FontSize="13.5" Margin="0,3,0,0"/>
        </StackPanel>
        <StackPanel Margin="0,0,26,0" VerticalAlignment="Center">
          <TextBlock Text="GPU" Foreground="#FF6E6E7B" FontSize="9.5" FontWeight="SemiBold"/>
          <TextBlock x:Name="DashGpu" Text="--" Foreground="#FFECECF1" FontSize="13.5" Margin="0,3,0,0" MaxWidth="260" TextTrimming="CharacterEllipsis"/>
        </StackPanel>
        <StackPanel VerticalAlignment="Center">
          <TextBlock Text="WINDOWS" Foreground="#FF6E6E7B" FontSize="9.5" FontWeight="SemiBold"/>
          <TextBlock x:Name="DashOs" Text="--" Foreground="#FFECECF1" FontSize="13.5" Margin="0,3,0,0"/>
        </StackPanel>
      </StackPanel>
    </Border>

    <Border DockPanel.Dock="Bottom" Background="#FF16161C" BorderBrush="#FF26262E" BorderThickness="0,1,0,0">
      <StatusBar Background="Transparent">
        <TextBlock x:Name="StatusText" Foreground="#FF8E8E9C" FontSize="12" Text="Ready."/>
      </StatusBar>
    </Border>

    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="248"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>

      <Border Grid.Column="0" Background="#FF1C1C24" BorderBrush="#FF26262E" BorderThickness="0,0,1,0">
        <DockPanel>
          <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="16,16,0,4">
            <Border Width="34" Height="34" CornerRadius="9" Background="#FF0A0A10" Margin="0,0,10,0">
              <Grid>
                <Ellipse Width="28" Height="12" Stroke="#FFE59A3A" StrokeThickness="2.4" Opacity="0.7" HorizontalAlignment="Center" VerticalAlignment="Center" RenderTransformOrigin="0.5,0.5">
                  <Ellipse.RenderTransform><RotateTransform Angle="-18"/></Ellipse.RenderTransform>
                </Ellipse>
                <Ellipse Width="12" Height="12" Fill="Black" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                <Ellipse Width="12" Height="12" Stroke="White" StrokeThickness="0.7" Opacity="0.75" HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <StackPanel VerticalAlignment="Center">
              <TextBlock Text="VoidTweaks" Foreground="#FFECECF1" FontSize="17" FontWeight="Bold"/>
              <TextBlock Text="transparent - reversible - local" Foreground="#FF6E6E7B" FontSize="10.5"/>
            </StackPanel>
          </StackPanel>
          <TextBox x:Name="SearchBox" DockPanel.Dock="Top" Style="{StaticResource SearchBox}" Margin="12,12,12,8"/>
          <ListBox x:Name="CategoryList" Background="Transparent" BorderThickness="0"
                   ItemContainerStyle="{StaticResource SideItem}"
                   ScrollViewer.HorizontalScrollBarVisibility="Disabled" Margin="4,2"/>
        </DockPanel>
      </Border>

      <DockPanel Grid.Column="1" Margin="0">
        <StackPanel DockPanel.Dock="Top" Margin="22,18,22,6">
          <TextBlock x:Name="HeaderTitle" Text="All tweaks" Foreground="#FFECECF1" FontSize="__HFS__" FontWeight="Bold"/>
          <TextBlock x:Name="HeaderSub" Text="" Foreground="#FF8E8E9C" FontSize="12.5" Margin="0,2,0,0"/>
        </StackPanel>
        <WrapPanel x:Name="Toolbar" DockPanel.Dock="Top" Margin="22,8,22,6">
          <Button x:Name="BoostBtn"     Content="&#x26A1; Boost now" Style="{StaticResource BtnBase}" Background="#FF17B0A3" Margin="0,0,8,6"/>
          <Button x:Name="ScanBtn"      Content="Scan PC"          Style="{StaticResource AccentButton}"  Margin="0,0,8,6"/>
          <Button x:Name="ApplyAllBtn"  Content="Apply all shown"  Style="{StaticResource SuccessButton}" Margin="0,0,8,6"/>
          <Button x:Name="RevertAllBtn" Content="Revert all shown" Style="{StaticResource GhostButton}"   Margin="0,0,8,6"/>
          <Button x:Name="UndoBtn"      Content="Undo last"        Style="{StaticResource GhostButton}"   Margin="0,0,18,6"/>
          <CheckBox x:Name="RestoreCheck" Content="Restore point first" IsChecked="True" Style="{StaticResource CheckLight}" Margin="0,0,16,6"/>
          <CheckBox x:Name="DryRunCheck"  Content="Dry run (preview only)"               Style="{StaticResource CheckLight}" Margin="0,0,8,6"/>
        </WrapPanel>
        <Border DockPanel.Dock="Bottom" Background="#FF101016" Height="138" BorderBrush="#FF26262E" BorderThickness="0,1,0,0" Margin="0,6,0,0">
          <DockPanel Margin="2">
            <TextBlock DockPanel.Dock="Top" Text="  Output log" Foreground="#FF6E6E7B" FontSize="11" Margin="14,4,0,2"/>
            <TextBox x:Name="LogBox" DockPanel.Dock="Bottom" Margin="14,0,14,8"
                     Background="Transparent" Foreground="#FF9FE0A6" BorderThickness="0"
                     FontFamily="Cascadia Mono, Consolas" FontSize="12" IsReadOnly="True"
                     VerticalScrollBarVisibility="Auto" TextWrapping="NoWrap"/>
          </DockPanel>
        </Border>
        <ScrollViewer x:Name="MainScroll" VerticalScrollBarVisibility="Auto" CanContentScroll="False" PanningMode="VerticalOnly" Padding="22,4,18,14">
          <StackPanel x:Name="TweakList"/>
        </ScrollViewer>
      </DockPanel>
    </Grid>
  </DockPanel>
</Window>
'@

# apply theme (single-pass colour remap) + density tokens, then parse
$xamlStr = [regex]::Replace($xamlStr, '#FF[0-9A-Fa-f]{6}', { param($m) if ($Sem.ContainsKey($m.Value)) { $T[$Sem[$m.Value]] } else { $m.Value } })
$xamlStr = $xamlStr.Replace('__FS__', "$($D.fs)").Replace('__HFS__', "$($D.hfs)").Replace('__RAD__', "$($D.rad)").Replace('__BRAD__', "$($D.brad)").Replace('__CPAD__', "$($D.cpad)").Replace('__CMARGIN__', $D.cmargin)
[xml]$xaml = $xamlStr
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# named controls
$ctl = @{}
'MiScan','MiExport','MiImport','MiExit','MiRecommended','MiUndo','MiRevertAll','MiRestore','MiShortcut','MiLog','MiAbout',
'AdminBar','AdminText','ElevateBtn','StatusText','LogBox','SearchBox','CategoryList',
'BoostBtn','ScanBtn','ApplyAllBtn','RevertAllBtn','UndoBtn','RestoreCheck','DryRunCheck','TweakList','HeaderTitle','HeaderSub',
'DashRamBar','DashRamText','DashCpu','DashDisk','DashGpu','DashOs','MainScroll' |
    ForEach-Object { $ctl[$_] = $window.FindName($_) }

# ---------------------------------------------------------------- palette
function New-Brush([string]$hex) { (New-Object Windows.Media.BrushConverter).ConvertFromString($hex) }
function New-Grad([string]$h1, [string]$h2) {
    $b = New-Object Windows.Media.LinearGradientBrush
    $b.StartPoint = New-Object Windows.Point(0, 0); $b.EndPoint = New-Object Windows.Point(1, 0)
    $b.GradientStops.Add((New-Object Windows.Media.GradientStop((New-Brush $h1).Color, 0)))
    $b.GradientStops.Add((New-Object Windows.Media.GradientStop((New-Brush $h2).Color, 1)))
    $b
}
# $Hex is set from the active theme near the top of the script.
$needs = ([char]0x26A0).ToString() + ' Needs attention'
$script:needsLabel = $needs
$CatColor = @{
    'All' = '#FFECECF1'; 'Presets' = '#FF7C6CF0'; 'Startup' = '#FFD29922'; 'Health' = '#FF3FB950'; 'Processes' = '#FF9B8CFF'; 'Settings' = '#FF9A9AA8'; 'Performance' = '#FF7C6CF0'; 'Gaming' = '#FFF0564B'; 'Privacy' = '#FF3FB950'
    'Network' = '#FF4C8DFF'; 'Visual' = '#FFD29922'; 'Explorer' = '#FFF2C14E'; 'Advanced' = '#FFB084F5'; 'Services' = '#FFC98FFF'; 'AI & Bloat' = '#FFFF8FB1'
    'Debloat' = '#FF8E8E9C'; 'Fixes' = '#FF5AC8FA'; 'Updates' = '#FF4C8DFF'; 'Maintenance' = '#FF5FD0C5'
}
$CatColor[$needs] = '#FFF0564B'

# per-category icon (emoji code points; distinct silhouettes, tinted by category colour)
$CatIcon = @{
    'All' = 0x1F4CB; 'Presets' = 0x1F4BE; 'Startup' = 0x1F50C; 'Health' = 0x2695; 'Processes' = 0x1F4CA; 'Settings' = 0x2699; 'Performance' = 0x1F680; 'Gaming' = 0x1F3AE; 'Privacy' = 0x1F512
    'Network' = 0x1F310; 'Visual' = 0x1F3A8; 'Explorer' = 0x1F4C1; 'Advanced' = 0x1F9F0; 'Services' = 0x1F6E0; 'AI & Bloat' = 0x1F916
    'Debloat' = 0x1F9F9; 'Fixes' = 0x1F527; 'Updates' = 0x1F504; 'Maintenance' = 0x1F9FD
}
$CatIcon[$needs] = 0x26A0

# path to the shared action helpers (RAM functions), dot-sourced into the runner
$actionsPath = Join-Path $scriptDir 'OpenTweaks.Actions.ps1'
$script:preludeCmd = if (Test-Path $actionsPath) { ". `"$actionsPath`"" } else { $null }
function Get-CatIcon([string]$c) {
    $cp = $CatIcon[$c]; if (-not $cp) { $cp = 0x25CF }
    [System.Char]::ConvertFromUtf32($cp)
}

# crisp vector (stroke) icons, 24x24 path data -> scaled into an 18px Viewbox
$IconGeo = @{
    'All' = 'M4 4h7v7H4z M13 4h7v7h-7z M4 13h7v7H4z M13 13h7v7h-7z'
    'Presets' = 'M6 3h12v18l-6-4-6 4z'
    'Startup' = 'M12 3v9 M8 6a7 7 0 1 0 8 0'
    'Health' = 'M3 12h4l2 5 4-12 2 7h6'
    'Processes' = 'M4 18V9 M9 18V5 M14 18v-7 M19 18v-4'
    'Settings' = 'M12 8.8a3.2 3.2 0 1 1 0 6.4 3.2 3.2 0 0 1 0-6.4z M12 2v3 M12 19v3 M2 12h3 M19 12h3 M5 5l2 2 M17 17l2 2 M19 5l-2 2 M7 17l-2 2'
    'Performance' = 'M13 2 4 14h6l-1 8 9-12h-6z'
    'Gaming' = 'M7 11h4 M9 9v4 M4 16l2-7a3 3 0 0 1 3-2h6a3 3 0 0 1 3 2l2 7a2.5 2.5 0 0 1-4.6 1.3L17 15H7l-.4 1.3A2.5 2.5 0 0 1 4 16z'
    'Privacy' = 'M12 3 5 6v6c0 4 3 6.5 7 9 4-2.5 7-5 7-9V6z'
    'Network' = 'M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0z M3 12h18 M12 3c3 3 3 15 0 18 M12 3c-3 3-3 15 0 18'
    'Visual' = 'M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0z'
    'Explorer' = 'M3 7h6l2 2h10v10H3z'
    'Advanced' = 'M4 7h10 M18 7h2 M4 17h2 M10 17h10 M14 4v6 M8 14v6'
    'Services' = 'M3 4h18v6H3z M3 14h18v6H3z'
    'AI & Bloat' = 'M7 7h10v10H7z M9 2v3 M15 2v3 M9 19v3 M15 19v3 M2 9h3 M2 15h3 M19 9h3 M19 15h3'
    'Debloat' = 'M4 7h16 M9 7V5h6v2 M6 7l1 13h10l1-13'
    'Fixes' = 'M14 7a4 4 0 0 1-5 5l-5 5 2 2 5-5a4 4 0 0 0 5-5z'
    'Updates' = 'M20 11a8 8 0 1 0-1 5 M20 5v6h-6'
    'Maintenance' = 'M6 3l3 3-3 3-3-3z M14 6l6 6-3 3-6-6z M14 12 4 22'
}
$IconGeo[$needs] = 'M12 3 2 20h20z M12 10v4 M12 16.8v0.6'

function New-VectorIcon([string]$cat, [string]$colorHex) {
    $vb = New-Object Windows.Controls.Viewbox
    $vb.Width = 18; $vb.Height = 18; $vb.Margin = '0,0,10,0'; $vb.VerticalAlignment = 'Center'
    $d = $IconGeo[$cat]
    try {
        if (-not $d) { throw 'no geometry' }
        $p = New-Object Windows.Shapes.Path
        $p.Data = [Windows.Media.Geometry]::Parse($d)
        $p.Stroke = (New-Brush $colorHex); $p.StrokeThickness = 2; $p.Fill = $null
        $p.StrokeStartLineCap = 'Round'; $p.StrokeEndLineCap = 'Round'; $p.StrokeLineJoin = 'Round'
        $vb.Child = $p
    } catch {
        $e = New-Object Windows.Shapes.Ellipse; $e.Width = 9; $e.Height = 9; $e.Fill = (New-Brush $colorHex); $vb.Child = $e
    }
    $vb
}

# tint brush = same colour at low alpha (hex is #AARRGGBB)
function Tint([string]$hex, [string]$alpha = '33') { New-Brush ('#' + $alpha + $hex.Substring(3)) }

# ---------------------------------------------------------------- UI helpers
function Append-Log {
    param([string]$Text)
    $ctl.LogBox.AppendText($Text + "`r`n")
    $ctl.LogBox.ScrollToEnd()
    Write-FileLog $Text
}
function Set-Status { param([string]$Text) $ctl.StatusText.Text = $Text }

function Get-PillInfo {
    param([string]$state)
    switch ($state) {
        'applied' { @{ Text = 'Applied';      Hex = $Hex.green  } }
        'default' { @{ Text = 'Not applied';  Hex = $Hex.muted  } }
        'custom'  { @{ Text = 'Custom value'; Hex = $Hex.orange } }
        'issue'   { @{ Text = 'Issue found';  Hex = $Hex.red    } }
        'ok'      { @{ Text = 'OK';           Hex = $Hex.green  } }
        'action'  { @{ Text = 'One-time';     Hex = $Hex.blue   } }
        default   { @{ Text = 'Scan to check';Hex = $Hex.muted  } }
    }
}
function Get-RiskHex { param($r) switch ($r) { 'high' { $Hex.red } 'medium' { $Hex.orange } default { $Hex.muted } } }

function New-Badge {
    param([string]$text, [string]$hex)
    $b = New-Object Windows.Controls.Border
    $b.Background = (Tint $hex '22'); $b.CornerRadius = 5; $b.Padding = '7,2'; $b.Margin = '0,0,6,0'
    $b.VerticalAlignment = 'Center'
    $tb = New-Object Windows.Controls.TextBlock
    $tb.Text = $text; $tb.Foreground = (New-Brush $hex); $tb.FontSize = 10; $tb.FontWeight = 'SemiBold'
    $b.Child = $tb
    $b
}

# ---------------------------------------------------------------- the run engine
$runnerScript = {
    param($cmds)
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($c in $cmds) {
        $isMarker = ($c -like 'Write-Output*') -or ($c -like '. "*')
        if (-not $isMarker) { $lines.Add("> $c") }
        try {
            $r = Invoke-Expression $c 2>&1 | Out-String
            if ($r) { foreach ($ln in ($r -split "`r?`n")) { if ($ln.Trim().Length) { $lines.Add('  ' + $ln.TrimEnd()) } } }
        } catch {
            $lines.Add('  ERROR: ' + $_.Exception.Message)
        }
    }
    , $lines.ToArray()
}

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(400)
$timer.Add_Tick({
    if ($script:asyncRes -and $script:asyncRes.IsCompleted) {
        $timer.Stop()
        try { $out = $script:asyncPS.EndInvoke($script:asyncRes) } catch { $out = @("ERROR: $($_.Exception.Message)") }
        try { $script:asyncPS.Dispose() } catch {}
        $script:asyncPS = $null; $script:asyncRes = $null
        foreach ($l in $out) { Append-Log $l }
        $script:running = $false
        $window.Cursor = $null
        Append-Log '=== done ==='
        if ($script:asyncDone) { & $script:asyncDone }
    }
})

function Start-Run {
    param([string[]]$Commands, [string]$Label, [bool]$Dry, [scriptblock]$OnDone)
    if ($script:running) { Append-Log 'Busy - wait for the current action to finish.'; return }
    if ($Dry) {
        foreach ($c in $Commands) { if ($c -notlike 'Write-Output*') { Append-Log "WOULD RUN: $c" } }
        Append-Log '=== dry run complete (nothing executed) ==='
        if ($OnDone) { & $OnDone }
        return
    }
    $script:running = $true
    $window.Cursor = [Windows.Input.Cursors]::Wait
    Set-Status "Running: $Label ..."
    if ($script:preludeCmd) { $Commands = @($script:preludeCmd) + $Commands }   # make RAM helpers available
    $ps = [powershell]::Create()
    [void]$ps.AddScript($runnerScript).AddArgument($Commands)
    $script:asyncPS   = $ps
    $script:asyncDone = $OnDone
    $script:asyncRes  = $ps.BeginInvoke()
    $timer.Start()
}

function Get-RestorePointCmd {
    "Enable-ComputerRestore -Drive `"`$env:SystemDrive\`" -ErrorAction SilentlyContinue; Checkpoint-Computer -Description 'VoidTweaks' -RestorePointType MODIFY_SETTINGS -ErrorAction SilentlyContinue"
}

function Invoke-Tweak {
    param($t, [string]$mode)
    if ($mode -eq 'apply' -and $t.requiresAdmin -and -not $script:isAdmin) {
        [Windows.MessageBox]::Show("'$($t.name)' needs administrator.`n`nClick 'Restart as administrator' at the top of the window, then try again.", 'Administrator required') | Out-Null
        return
    }
    $cmds = if ($mode -eq 'revert') { @($t.revert) } else { @($t.apply) }
    if (-not $cmds -or $cmds.Count -eq 0) { Append-Log "[$($t.id)] nothing to $mode (one-time action)."; return }
    $dry = [bool]$ctl.DryRunCheck.IsChecked
    if ($mode -eq 'apply' -and $ctl.RestoreCheck.IsChecked -and $script:isAdmin -and -not $dry) {
        $cmds = @((Get-RestorePointCmd)) + $cmds
    }
    if ($mode -eq 'apply' -and -not $dry) { Set-LastUndo @($t.id) $t.name }
    Append-Log ''
    Append-Log "=== $mode : $($t.name) [$($t.id)]$(if($dry){' (dry run)'}) ==="
    if ($t.needsRestart) { Append-Log '  note: a restart is needed for this to take full effect.' }
    Start-Run -Commands $cmds -Label "$mode $($t.id)" -Dry $dry -OnDone { Invoke-Scan }
}

function Invoke-Bulk {
    param([object[]]$Tweaks, [string]$mode, [string]$Label)
    $dry = [bool]$ctl.DryRunCheck.IsChecked
    $cmds = @()
    if ($mode -eq 'apply' -and $ctl.RestoreCheck.IsChecked -and $script:isAdmin -and -not $dry) { $cmds += (Get-RestorePointCmd) }
    $n = 0; $skipped = 0; $appliedIds = @()
    foreach ($t in $Tweaks) {
        if ($mode -eq 'apply' -and $t.requiresAdmin -and -not $script:isAdmin) { $skipped++; continue }
        $c = if ($mode -eq 'revert') { $t.revert } else { $t.apply }
        if (-not $c -or $c.Count -eq 0) { continue }
        $cmds += "Write-Output '--- $mode $($t.id) ---'"
        $cmds += $c
        $n++
        if ($mode -eq 'apply' -and $t.reversible) { $appliedIds += $t.id }
    }
    if ($n -eq 0) { Append-Log "Nothing to $mode here$(if($skipped){" ($skipped need admin)"})."; return }
    if ($mode -eq 'apply' -and -not $dry) { Set-LastUndo $appliedIds $Label }
    Append-Log ''
    Append-Log "=== bulk $mode : $Label - $n tweak(s)$(if($skipped){", $skipped skipped (need admin)"})$(if($dry){' (dry run)'}) ==="
    Start-Run -Commands $cmds -Label "bulk $mode" -Dry $dry -OnDone { Invoke-Scan }
}

# ---------------------------------------------------------------- rendering
function Get-SelCat {
    $it = $ctl.CategoryList.SelectedItem
    if ($it -is [Windows.Controls.ListBoxItem]) { return [string]$it.Tag }
    return [string]$it
}

function Get-ShownTweaks {
    $cat = Get-SelCat
    $search = ([string]$ctl.SearchBox.Text).Trim()
    if ($search -eq 'Search tweaks...') { $search = '' }
    $src =
        if     ($cat -eq 'All')               { $catalog.tweaks }
        elseif ($cat -eq 'Presets')           { @() }
        elseif ($cat -eq 'Startup')           { @() }
        elseif ($cat -eq 'Health')            { @() }
        elseif ($cat -eq 'Processes')         { @() }
        elseif ($cat -eq 'Settings')          { @() }
        elseif ($cat -eq $script:needsLabel)  { $catalog.tweaks | Where-Object { $script:stateCache[$_.id] -eq 'issue' } }
        elseif ($cat)                         { $catalog.tweaks | Where-Object { $_.category -eq $cat } }
        else                                  { $catalog.tweaks }
    if ($search) {
        $src = $src | Where-Object { $_.name -like "*$search*" -or $_.description -like "*$search*" -or $_.id -like "*$search*" }
    }
    $src
}

function Render {
    $cat = Get-SelCat
    if ($cat -eq 'Presets')   { Render-Presets; return }
    if ($cat -eq 'Startup')   { Render-Startup; return }
    if ($cat -eq 'Health')    { Render-Health; return }
    if ($cat -eq 'Processes') { Render-Processes; return }
    if ($cat -eq 'Settings')  { Render-Settings; return }
    $ctl.TweakList.Children.Clear()
    $tweaks = @(Get-ShownTweaks)
    $title = if ($cat -eq 'All') { 'All tweaks' } elseif ($cat -eq $script:needsLabel) { 'Needs attention' } else { "$cat" }
    $ctl.HeaderTitle.Text = (Get-CatIcon $cat) + '  ' + $title
    $ctl.HeaderSub.Text = "$($tweaks.Count) tweak(s) shown"

    if ($tweaks.Count -eq 0) {
        $tb = New-Object Windows.Controls.TextBlock
        $tb.Text = if ($cat -eq $script:needsLabel) { 'Nothing needs attention - run Scan PC to re-check.' } else { 'Nothing here. Try another category or clear the search.' }
        $tb.Foreground = (New-Brush $Hex.muted); $tb.Margin = '2,16'; $tb.FontSize = 13
        [void]$ctl.TweakList.Children.Add($tb)
        return
    }

    foreach ($t in $tweaks) {
        $tw = $t
        $state = $script:stateCache[$tw.id]; if (-not $state) { $state = '?' }

        $card = New-Object Windows.Controls.Border
        $card.Style = $window.FindResource('Card')

        $grid = New-Object Windows.Controls.Grid
        $c0 = New-Object Windows.Controls.ColumnDefinition; $c0.Width = '*'
        $c1 = New-Object Windows.Controls.ColumnDefinition; $c1.Width = 'Auto'
        $grid.ColumnDefinitions.Add($c0); $grid.ColumnDefinitions.Add($c1)

        # left column
        $left = New-Object Windows.Controls.StackPanel
        $titleRow = New-Object Windows.Controls.StackPanel; $titleRow.Orientation = 'Horizontal'
        $name = New-Object Windows.Controls.TextBlock
        $name.Text = $tw.name; $name.Foreground = (New-Brush $Hex.fg); $name.FontSize = 15; $name.FontWeight = 'SemiBold'
        $name.VerticalAlignment = 'Center'; $name.Margin = '0,0,10,0'
        [void]$titleRow.Children.Add($name)
        [void]$titleRow.Children.Add((New-Badge ($tw.risk + ' risk') (Get-RiskHex $tw.risk)))
        if ($tw.requiresAdmin)   { [void]$titleRow.Children.Add((New-Badge 'ADMIN'    $Hex.orange)) }
        if ($tw.needsRestart)    { [void]$titleRow.Children.Add((New-Badge 'REBOOT'   $Hex.blue)) }
        if (-not $tw.reversible) { [void]$titleRow.Children.Add((New-Badge 'ONE-TIME' $Hex.muted)) }
        [void]$left.Children.Add($titleRow)

        $desc = New-Object Windows.Controls.TextBlock
        $desc.Text = $tw.description; $desc.Foreground = (New-Brush $Hex.muted); $desc.TextWrapping = 'Wrap'
        $desc.Margin = '0,7,14,0'; $desc.FontSize = 12.5; $desc.LineHeight = 17
        [void]$left.Children.Add($desc)

        $idtb = New-Object Windows.Controls.TextBlock
        $idtb.Text = $tw.id; $idtb.Foreground = (New-Brush '#FF55555F'); $idtb.FontSize = 10.5
        $idtb.FontFamily = New-Object Windows.Media.FontFamily('Cascadia Mono, Consolas')
        $idtb.Margin = '0,6,0,0'
        [void]$left.Children.Add($idtb)

        [Windows.Controls.Grid]::SetColumn($left, 0)
        [void]$grid.Children.Add($left)

        # right column
        $right = New-Object Windows.Controls.StackPanel
        $right.Width = 200; $right.HorizontalAlignment = 'Right'
        $pi = Get-PillInfo $state
        $pill = New-Object Windows.Controls.Border
        $pill.Background = (Tint $pi.Hex '2E'); $pill.CornerRadius = 11; $pill.Padding = '11,4'; $pill.HorizontalAlignment = 'Right'
        $pillTb = New-Object Windows.Controls.TextBlock
        $pillTb.Text = $pi.Text; $pillTb.Foreground = (New-Brush $pi.Hex); $pillTb.FontSize = 11; $pillTb.FontWeight = 'SemiBold'
        $pill.Child = $pillTb
        [void]$right.Children.Add($pill)

        $btnRow = New-Object Windows.Controls.StackPanel
        $btnRow.Orientation = 'Horizontal'; $btnRow.HorizontalAlignment = 'Right'; $btnRow.Margin = '0,12,0,0'

        $applyBtn = New-Object Windows.Controls.Button
        $applyBtn.Content = 'Apply'; $applyBtn.Width = 76; $applyBtn.Margin = '0,0,8,0'
        $applyBtn.Style = $window.FindResource('SuccessButton')
        if ($tw.requiresAdmin -and -not $script:isAdmin) { $applyBtn.IsEnabled = $false; $applyBtn.ToolTip = 'Needs administrator - use "Restart as administrator" at the top' }
        $applyBtn.Add_Click({ $applyBtn.Content = 'Applying...'; $applyBtn.IsEnabled = $false; Invoke-Tweak $tw 'apply' }.GetNewClosure())
        [void]$btnRow.Children.Add($applyBtn)

        if ($tw.reversible -and $tw.revert -and $tw.revert.Count) {
            $revertBtn = New-Object Windows.Controls.Button
            $revertBtn.Content = 'Revert'; $revertBtn.Width = 76
            $revertBtn.Style = $window.FindResource('GhostButton')
            $revertBtn.Background = (Tint $Hex.red '22'); $revertBtn.Foreground = (New-Brush $Hex.red); $revertBtn.BorderBrush = (Tint $Hex.red '66')
            $revertBtn.Add_Click({ $revertBtn.Content = 'Reverting...'; $revertBtn.IsEnabled = $false; Invoke-Tweak $tw 'revert' }.GetNewClosure())
            [void]$btnRow.Children.Add($revertBtn)
        }
        [void]$right.Children.Add($btnRow)

        [Windows.Controls.Grid]::SetColumn($right, 1)
        [void]$grid.Children.Add($right)

        $card.Child = $grid
        [void]$ctl.TweakList.Children.Add($card)
    }
}

function Invoke-Scan {
    Set-Status 'Scanning current settings...'
    # gather the slow stuff ONCE per scan; Get-TweakState reads these caches
    $script:scanPower = (powercfg /getactivescheme 2>$null) -join ' '
    $script:scanBcd = (bcdedit /enum '{current}' 2>&1) -join "`n"
    $script:scanAppx = @(Get-AppxPackage -ErrorAction SilentlyContinue | ForEach-Object { $_.Name.ToLower() })
    try { $script:scanNet = Get-NetTCPSetting -SettingName Internet -ErrorAction Stop } catch { $script:scanNet = $null }
    try { $script:scanRsc = Get-NetOffloadGlobalSetting -ErrorAction Stop } catch { $script:scanRsc = $null }
    try { $script:scanMm = Get-MMAgent -ErrorAction Stop } catch { $script:scanMm = $null }
    try { $script:scanDns = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop | Select-Object -ExpandProperty ServerAddresses) } catch { $script:scanDns = @() }
    foreach ($t in $catalog.tweaks) { $script:stateCache[$t.id] = Get-TweakState $t }
    Render
    $app = @($catalog.tweaks | Where-Object { $script:stateCache[$_.id] -eq 'applied' }).Count
    $iss = @($catalog.tweaks | Where-Object { $script:stateCache[$_.id] -eq 'issue' }).Count
    Set-Status "Scan complete - $app applied, $iss issue(s) found, across $($catalog.tweaks.Count) tweaks."
    if ($iss -gt 0) { Append-Log "Scan: $iss issue(s) found. See the 'Needs attention' category." }
}

# ---------------------------------------------------------------- presets
$presetDir  = Join-Path $logDir 'presets'
$presetFile = Join-Path $scriptDir 'presets.json'

function Build-TweakCmds {
    param([object[]]$Tweaks, [string]$mode)
    $out = @(); $n = 0; $skip = 0
    foreach ($t in $Tweaks) {
        if ($mode -eq 'apply' -and $t.requiresAdmin -and -not $script:isAdmin) { $skip++; continue }
        $c = if ($mode -eq 'revert') { $t.revert } else { $t.apply }
        if (-not $c -or $c.Count -eq 0) { continue }
        $out += "Write-Output '--- $mode $($t.id) ---'"; $out += $c; $n++
    }
    [pscustomobject]@{ Cmds = $out; Count = $n; Skipped = $skip }
}

function Get-Presets {
    $list = @()
    if (Test-Path $presetFile) { try { $list += (Get-Content $presetFile -Raw | ConvertFrom-Json).presets } catch {} }
    if (Test-Path $presetDir) {
        Get-ChildItem $presetDir -Filter *.json -ErrorAction SilentlyContinue | ForEach-Object {
            try { $p = Get-Content $_.FullName -Raw | ConvertFrom-Json; $p | Add-Member -NotePropertyName _file -NotePropertyValue $_.FullName -Force; $list += $p } catch {}
        }
    }
    $list
}

function Invoke-Preset {
    param($p)
    $dry = [bool]$ctl.DryRunCheck.IsChecked
    if ($p.mode -eq 'revert-all') {
        $set = @($catalog.tweaks | Where-Object { $_.reversible -and $_.revert -and $_.revert.Count })
        Invoke-Bulk $set 'revert' $p.name
        return
    }
    $applyIds = @($p.apply)
    $applySet = @($catalog.tweaks | Where-Object { $applyIds -contains $_.id })
    $cmds = @()
    if ($p.revertOthers) {
        $revSet = @($catalog.tweaks | Where-Object { $_.reversible -and $_.revert -and $_.revert.Count -and ($applyIds -notcontains $_.id) })
        $cmds += (Build-TweakCmds $revSet 'revert').Cmds
    }
    if ($ctl.RestoreCheck.IsChecked -and $script:isAdmin -and -not $dry) { $cmds = @((Get-RestorePointCmd)) + $cmds }
    $ab = Build-TweakCmds $applySet 'apply'
    $cmds += $ab.Cmds
    if ($cmds.Count -eq 0) { Append-Log "Preset '$($p.name)': nothing to do (maybe needs admin)."; return }
    if (-not $dry) { Set-LastUndo (@($applySet | Where-Object { $_.reversible } | ForEach-Object { $_.id })) $p.name }
    Append-Log ''
    Append-Log "=== preset: $($p.name)$(if($ab.Skipped){", $($ab.Skipped) skipped (need admin)"})$(if($dry){' (dry run)'}) ==="
    Start-Run -Commands $cmds -Label "preset $($p.name)" -Dry $dry -OnDone { Invoke-Scan }
}

function Save-CurrentPreset {
    Add-Type -AssemblyName Microsoft.VisualBasic
    $name = [Microsoft.VisualBasic.Interaction]::InputBox('Name this preset. Your currently-applied tweaks will be saved so you can return to them later.', 'Save current state as preset', 'My Setup')
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    $applied = @($catalog.tweaks | Where-Object { $script:stateCache[$_.id] -eq 'applied' } | ForEach-Object { $_.id })
    if (-not (Test-Path $presetDir)) { New-Item -ItemType Directory -Force -Path $presetDir | Out-Null }
    $safe = ($name -replace '[^\w\-]', '_')
    $file = Join-Path $presetDir "$safe.json"
    [pscustomobject]@{ id = $safe; name = $name; description = ('Your saved setup - ' + [DateTime]::Now.ToString('g')); revertOthers = $true; apply = $applied } |
        ConvertTo-Json | Set-Content -Path $file -Encoding utf8
    Append-Log "Saved preset '$name' ($($applied.Count) tweaks) to $file"
    Set-Status "Saved preset '$name'."
    Render
}

function New-PresetCard {
    param($p, [bool]$isSaveCard)
    $card = New-Object Windows.Controls.Border
    $card.Style = $window.FindResource('Card')
    $grid = New-Object Windows.Controls.Grid
    $c0 = New-Object Windows.Controls.ColumnDefinition; $c0.Width = '*'
    $c1 = New-Object Windows.Controls.ColumnDefinition; $c1.Width = 'Auto'
    $grid.ColumnDefinitions.Add($c0); $grid.ColumnDefinitions.Add($c1)

    $left = New-Object Windows.Controls.StackPanel
    $nm = New-Object Windows.Controls.TextBlock
    $nm.Foreground = (New-Brush $Hex.fg); $nm.FontSize = 15; $nm.FontWeight = 'SemiBold'
    $nm.Text = if ($isSaveCard) { 'Save current state' } else { $p.name }
    [void]$left.Children.Add($nm)
    $ds = New-Object Windows.Controls.TextBlock
    $ds.Foreground = (New-Brush $Hex.muted); $ds.TextWrapping = 'Wrap'; $ds.Margin = '0,7,14,0'; $ds.FontSize = 12.5; $ds.LineHeight = 17
    $ds.Text = if ($isSaveCard) { "Snapshot everything that's applied right now, so you can come back to it after trying other presets." } else { $p.description }
    [void]$left.Children.Add($ds)
    if (-not $isSaveCard -and $p.mode -ne 'revert-all' -and $p.apply) {
        $ap = @($p.apply | Where-Object { $script:stateCache[$_] -eq 'applied' }).Count
        $tot = @($p.apply).Count
        $st = New-Object Windows.Controls.TextBlock
        $st.Margin = '0,9,0,0'; $st.FontSize = 12; $st.FontWeight = 'SemiBold'
        if ($ap -eq $tot -and $tot -gt 0) { $st.Text = [char]0x25CF + " Active - all $tot tweaks applied"; $st.Foreground = (New-Brush $Hex.green) }
        else { $st.Text = "$ap / $tot of this preset's tweaks applied"; $st.Foreground = (New-Brush $Hex.muted) }
        [void]$left.Children.Add($st)
    }
    [Windows.Controls.Grid]::SetColumn($left, 0); [void]$grid.Children.Add($left)

    $right = New-Object Windows.Controls.StackPanel
    $right.HorizontalAlignment = 'Right'; $right.VerticalAlignment = 'Center'
    $row = New-Object Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'
    $btn = New-Object Windows.Controls.Button
    if ($isSaveCard) {
        $btn.Content = 'Save as preset'; $btn.Style = $window.FindResource('AccentButton'); $btn.Add_Click({ Save-CurrentPreset })
    } else {
        $btn.Content = 'Apply'; $btn.Width = 92; $btn.Style = $window.FindResource('SuccessButton')
        $pp = $p; $btn.Add_Click({ Invoke-Preset $pp }.GetNewClosure())
    }
    [void]$row.Children.Add($btn)
    if (-not $isSaveCard -and $p._file) {
        $ren = New-Object Windows.Controls.Button
        $ren.Content = 'Rename'; $ren.Width = 80; $ren.Margin = '8,0,0,0'; $ren.Style = $window.FindResource('GhostButton')
        $pr = $p; $ren.Add_Click({ Rename-UserPreset $pr }.GetNewClosure())
        [void]$row.Children.Add($ren)
        $del = New-Object Windows.Controls.Button
        $del.Content = 'Delete'; $del.Width = 76; $del.Margin = '8,0,0,0'; $del.Style = $window.FindResource('GhostButton')
        $pf = $p._file; $del.Add_Click({ Remove-Item $pf -Force -ErrorAction SilentlyContinue; Append-Log "Deleted preset file."; Render }.GetNewClosure())
        [void]$row.Children.Add($del)
    }
    [void]$right.Children.Add($row)
    [Windows.Controls.Grid]::SetColumn($right, 1); [void]$grid.Children.Add($right)

    $card.Child = $grid
    [void]$ctl.TweakList.Children.Add($card)
}

function Render-Presets {
    $ctl.HeaderTitle.Text = (Get-CatIcon 'Presets') + '  Presets'
    $appliedN = @($catalog.tweaks | Where-Object { $script:stateCache[$_.id] -eq 'applied' }).Count
    $active = $null
    foreach ($pp in (Get-Presets)) {
        if ($pp.apply -and @($pp.apply).Count -gt 0) {
            $am = @($pp.apply | Where-Object { $script:stateCache[$_] -eq 'applied' }).Count
            if ($am -eq @($pp.apply).Count) { $active = $pp.name }
        }
    }
    $ctl.HeaderSub.Text = "You currently have $appliedN tweak(s) applied. " + $(if ($active) { "Active preset: $active." } else { 'No full preset is active yet.' })
    $ctl.TweakList.Children.Clear()
    New-PresetCard $null $true
    foreach ($p in (Get-Presets)) { New-PresetCard $p $false }
}

# ---------------------------------------------------------------- dashboard
function Update-DashStatic {
    # one-time WMI at startup only (GPU name + build) - not on the live timer
    try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop; $dv = Get-RegVal 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'DisplayVersion'; $ctl.DashOs.Text = "$(if ($dv) { "$dv " })build $($os.BuildNumber)" } catch {}
    try {
        $g = Get-CimInstance Win32_VideoController -ErrorAction Stop
        $pick = $g | Where-Object { $_.Name -and $_.Name -notmatch 'Meta|Virtual|Basic|Remote|Mirror|Parsec|DisplayLink' -and "$($_.Status)" -eq 'OK' } | Select-Object -First 1
        if (-not $pick) { $pick = $g | Where-Object { $_.CurrentHorizontalResolution } | Select-Object -First 1 }
        if (-not $pick) { $pick = $g | Where-Object { $_.Name } | Select-Object -First 1 }
        if ($pick) { $ctl.DashGpu.Text = $pick.Name }
    } catch {}
}
function Get-CpuPercent {
    $i = 0L; $k = 0L; $u = 0L
    [void][OTPerf.Sys]::GetSystemTimes([ref]$i, [ref]$k, [ref]$u)
    $busy = 0
    if ($script:prevK) {
        $dk = $k - $script:prevK; $du = $u - $script:prevU; $di = $i - $script:prevI; $tot = $dk + $du
        if ($tot -gt 0) { $busy = [int](100 * ($tot - $di) / $tot) }
    }
    $script:prevI = $i; $script:prevK = $k; $script:prevU = $u
    if ($busy -lt 0) { 0 } elseif ($busy -gt 100) { 100 } else { $busy }
}
function Update-DashLive {
    # all native + framework calls, instant, so the timer never blocks the UI
    try {
        $m = New-Object 'OTPerf.Sys+MEMSTAT'
        $m.dwLength = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf([type]'OTPerf.Sys+MEMSTAT')
        [void][OTPerf.Sys]::GlobalMemoryStatusEx([ref]$m)
        $pct = [int]$m.dwMemoryLoad
        $ctl.DashRamBar.Value = $pct
        $ctl.DashRamText.Text = ('{0:N1} / {1:N1} GB  ({2}%)' -f ((($m.ullTotalPhys - $m.ullAvailPhys)) / 1GB), ($m.ullTotalPhys / 1GB), $pct)
        $ctl.DashRamBar.Foreground = if ($pct -ge 85) { New-Grad $Hex.red $Hex.orange } elseif ($pct -ge 70) { New-Grad $Hex.orange $Hex.accent } else { New-Grad $Hex.accent $Hex.teal }
    } catch {}
    try { $ctl.DashCpu.Text = "$(Get-CpuPercent)%" } catch {}
    try { $d = New-Object System.IO.DriveInfo($env:SystemDrive); $ctl.DashDisk.Text = ('{0:N0} GB free of {1:N0}' -f ($d.AvailableFreeSpace / 1GB), ($d.TotalSize / 1GB)) } catch {}
}
$dashTimer = New-Object Windows.Threading.DispatcherTimer
$dashTimer.Interval = [TimeSpan]::FromMilliseconds(2000)
$dashTimer.Add_Tick({ Update-DashLive })

# ---------------------------------------------------------------- undo
$script:lastUndo = $null
function Set-LastUndo { param([string[]]$Ids, [string]$Label)
    $Ids = @($Ids | Where-Object { $_ })
    if ($Ids.Count) { $script:lastUndo = [pscustomobject]@{ Label = $Label; Ids = $Ids }; if ($ctl.UndoBtn) { $ctl.UndoBtn.IsEnabled = $true } }
}
function Invoke-Undo {
    if (-not $script:lastUndo) { Append-Log 'Nothing to undo yet.'; return }
    $u = $script:lastUndo
    $set = @($catalog.tweaks | Where-Object { $u.Ids -contains $_.id -and $_.reversible -and $_.revert -and $_.revert.Count })
    if ($set.Count -eq 0) { Append-Log "Last action ('$($u.Label)') had nothing reversible to undo."; return }
    Append-Log ''; Append-Log "=== undo: $($u.Label) ==="
    $script:lastUndo = $null; $ctl.UndoBtn.IsEnabled = $false
    Invoke-Bulk $set 'revert' "undo ($($u.Label))"
}

# ---------------------------------------------------------------- startup manager
$startupBackup = Join-Path $logDir 'startup-backup.json'
$startupDisDir = Join-Path $logDir 'startup-disabled'
function Get-StartupBackup { if (Test-Path $startupBackup) { try { return @(Get-Content $startupBackup -Raw | ConvertFrom-Json) } catch {} }; @() }
function Save-StartupBackup { param($arr) if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force $logDir | Out-Null }; @($arr) | ConvertTo-Json -Depth 5 | Set-Content $startupBackup -Encoding utf8 }

function Get-StartupItems {
    $items = @()
    $runKeys = @(
        @{ Hive = 'HKCU'; Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Admin = $false },
        @{ Hive = 'HKLM'; Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'; Admin = $true },
        @{ Hive = 'HKLM32'; Path = 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run'; Admin = $true }
    )
    foreach ($rk in $runKeys) {
        if (Test-Path $rk.Path) {
            $props = Get-ItemProperty $rk.Path
            $props.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object {
                $items += [pscustomobject]@{ Id = "reg|$($rk.Hive)|$($_.Name)"; Name = $_.Name; Command = [string]$_.Value; Source = "$($rk.Hive) Run"; Type = 'reg'; RegPath = $rk.Path; FilePath = $null; DisabledPath = $null; Admin = $rk.Admin; Enabled = $true }
            }
        }
    }
    $folders = @(
        @{ Path = [Environment]::GetFolderPath('Startup'); Admin = $false; Source = 'Startup folder' },
        @{ Path = [Environment]::GetFolderPath('CommonStartup'); Admin = $true; Source = 'All-users Startup' }
    )
    foreach ($f in $folders) {
        if ($f.Path -and (Test-Path $f.Path)) {
            Get-ChildItem $f.Path -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object {
                $items += [pscustomobject]@{ Id = "file|$($f.Source)|$($_.Name)"; Name = $_.BaseName; Command = $_.FullName; Source = $f.Source; Type = 'file'; RegPath = $null; FilePath = $_.FullName; DisabledPath = $null; Admin = $f.Admin; Enabled = $true }
            }
        }
    }
    foreach ($b in (Get-StartupBackup)) {
        $items += [pscustomobject]@{ Id = $b.Id; Name = $b.Name; Command = $b.Command; Source = $b.Source; Type = $b.Type; RegPath = $b.RegPath; FilePath = $b.FilePath; DisabledPath = $b.DisabledPath; Admin = $b.Admin; Enabled = $false }
    }
    $items | Sort-Object @{ E = { -not $_.Enabled } }, Name
}

function Disable-StartupItem { param($it)
    if ($it.Admin -and -not $script:isAdmin) { [Windows.MessageBox]::Show("Disabling '$($it.Name)' needs administrator.", 'OpenTweaks') | Out-Null; return }
    $bk = @(Get-StartupBackup)
    if ($it.Type -eq 'reg') {
        $rec = [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Command = $it.Command; Source = $it.Source; Type = 'reg'; RegPath = $it.RegPath; FilePath = $null; DisabledPath = $null; Admin = $it.Admin }
        Remove-ItemProperty -Path $it.RegPath -Name $it.Name -ErrorAction SilentlyContinue
    } else {
        if (-not (Test-Path $startupDisDir)) { New-Item -ItemType Directory -Force $startupDisDir | Out-Null }
        $dest = Join-Path $startupDisDir (Split-Path $it.FilePath -Leaf)
        Move-Item -Path $it.FilePath -Destination $dest -Force -ErrorAction SilentlyContinue
        $rec = [pscustomobject]@{ Id = $it.Id; Name = $it.Name; Command = $it.Command; Source = $it.Source; Type = 'file'; RegPath = $null; FilePath = $it.FilePath; DisabledPath = $dest; Admin = $it.Admin }
    }
    Save-StartupBackup ($bk + $rec)
    Append-Log "Startup: disabled '$($it.Name)'."
    Render
}

function Enable-StartupItem { param($it)
    if ($it.Admin -and -not $script:isAdmin) { [Windows.MessageBox]::Show("Re-enabling '$($it.Name)' needs administrator.", 'OpenTweaks') | Out-Null; return }
    $bk = @(Get-StartupBackup)
    $rec = $bk | Where-Object { $_.Id -eq $it.Id } | Select-Object -First 1
    if (-not $rec) { return }
    if ($rec.Type -eq 'reg') {
        New-ItemProperty -Path $rec.RegPath -Name $rec.Name -Value $rec.Command -PropertyType String -Force | Out-Null
    } elseif ($rec.DisabledPath -and (Test-Path $rec.DisabledPath)) {
        Move-Item -Path $rec.DisabledPath -Destination $rec.FilePath -Force -ErrorAction SilentlyContinue
    }
    Save-StartupBackup (@($bk | Where-Object { $_.Id -ne $it.Id }))
    Append-Log "Startup: re-enabled '$($it.Name)'."
    Render
}

function Render-Startup {
    $ctl.HeaderTitle.Text = (Get-CatIcon 'Startup') + '  Startup apps'
    $items = @(Get-StartupItems)
    $en = @($items | Where-Object { $_.Enabled }).Count
    $ctl.HeaderSub.Text = "$($items.Count) item(s), $en enabled. Disabling heavy startup apps speeds up boot - all reversible here."
    $ctl.TweakList.Children.Clear()
    if ($items.Count -eq 0) {
        $tb = New-Object Windows.Controls.TextBlock; $tb.Text = 'No startup items found.'; $tb.Foreground = (New-Brush $Hex.muted); $tb.Margin = '2,16'
        [void]$ctl.TweakList.Children.Add($tb); return
    }
    foreach ($i in $items) {
        $it = $i
        $card = New-Object Windows.Controls.Border; $card.Style = $window.FindResource('Card')
        $grid = New-Object Windows.Controls.Grid
        $c0 = New-Object Windows.Controls.ColumnDefinition; $c0.Width = '*'
        $c1 = New-Object Windows.Controls.ColumnDefinition; $c1.Width = 'Auto'
        $grid.ColumnDefinitions.Add($c0); $grid.ColumnDefinitions.Add($c1)

        $left = New-Object Windows.Controls.StackPanel
        $row = New-Object Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'
        $nm = New-Object Windows.Controls.TextBlock; $nm.Text = $it.Name; $nm.Foreground = (New-Brush $Hex.fg); $nm.FontSize = 15; $nm.FontWeight = 'SemiBold'; $nm.VerticalAlignment = 'Center'; $nm.Margin = '0,0,10,0'
        [void]$row.Children.Add($nm)
        [void]$row.Children.Add((New-Badge $it.Source $Hex.blue))
        if ($it.Admin) { [void]$row.Children.Add((New-Badge 'ADMIN' $Hex.orange)) }
        [void]$left.Children.Add($row)
        $cmd = New-Object Windows.Controls.TextBlock; $cmd.Text = $it.Command; $cmd.Foreground = (New-Brush $Hex.muted); $cmd.TextWrapping = 'Wrap'; $cmd.Margin = '0,6,14,0'; $cmd.FontSize = 11.5; $cmd.MaxHeight = 34; $cmd.TextTrimming = 'CharacterEllipsis'
        [void]$left.Children.Add($cmd)
        [Windows.Controls.Grid]::SetColumn($left, 0); [void]$grid.Children.Add($left)

        $right = New-Object Windows.Controls.StackPanel; $right.HorizontalAlignment = 'Right'; $right.VerticalAlignment = 'Center'
        $pi = if ($it.Enabled) { @{ Text = 'Enabled'; Hex = $Hex.green } } else { @{ Text = 'Disabled'; Hex = $Hex.muted } }
        $pill = New-Object Windows.Controls.Border; $pill.Background = (Tint $pi.Hex '2E'); $pill.CornerRadius = 11; $pill.Padding = '11,4'; $pill.HorizontalAlignment = 'Right'
        $pt = New-Object Windows.Controls.TextBlock; $pt.Text = $pi.Text; $pt.Foreground = (New-Brush $pi.Hex); $pt.FontSize = 11; $pt.FontWeight = 'SemiBold'; $pill.Child = $pt
        [void]$right.Children.Add($pill)
        $btn = New-Object Windows.Controls.Button; $btn.Width = 86; $btn.Margin = '0,10,0,0'; $btn.HorizontalAlignment = 'Right'
        if ($it.Enabled) { $btn.Content = 'Disable'; $btn.Style = $window.FindResource('GhostButton'); $btn.Add_Click({ Disable-StartupItem $it }.GetNewClosure()) }
        else { $btn.Content = 'Enable'; $btn.Style = $window.FindResource('SuccessButton'); $btn.Add_Click({ Enable-StartupItem $it }.GetNewClosure()) }
        if ($it.Admin -and -not $script:isAdmin) { $btn.IsEnabled = $false; $btn.ToolTip = 'Needs administrator' }
        [void]$right.Children.Add($btn)
        [Windows.Controls.Grid]::SetColumn($right, 1); [void]$grid.Children.Add($right)

        $card.Child = $grid
        [void]$ctl.TweakList.Children.Add($card)
    }
}

# ---------------------------------------------------------------- boost
function Invoke-Boost {
    if ($script:isAdmin) {
        $cmds = @('Optimize-RAM', 'Clear-StandbyList', 'ipconfig /flushdns',
            'Get-Volume | Where-Object { $_.DriveType -eq ''Fixed'' -and $_.DriveLetter } | ForEach-Object { Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -ErrorAction SilentlyContinue }')
        Append-Log ''
        Append-Log '=== Boost now (admin): empty working sets + flush modified + purge standby + DNS + TRIM ==='
        Start-Run -Commands $cmds -Label 'Boost' -Dry $false -OnDone { Update-DashLive; Set-Status 'Boost complete - RAM freed.' }
        return
    }
    # not elevated: trim inline (limited), then elevate just the standby purge - the real RAM win
    Append-Log ''
    Append-Log '=== Boost now: trimming RAM + DNS, then purging standby cache (approve the admin prompt) ==='
    Start-Run -Commands @('Optimize-RAM', 'ipconfig /flushdns') -Label 'Boost' -Dry $false -OnDone { Update-DashLive }
    $inner = ". '$actionsPath'; Clear-StandbyList | Out-Null"
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"$inner`"" | Out-Null
        Set-Status 'Purging standby cache (elevated) - approve the prompt; the RAM meter will drop.'
        Append-Log 'Standby purge launched (elevated). Tip: run VoidTweaks as administrator for one-click Boost with no prompt.'
    } catch {
        Append-Log 'Standby purge needs admin - click "Restart as administrator" at the top for a full Boost.'
    }
}

# ---------------------------------------------------------------- health check
function Select-Category { param([string]$name)
    foreach ($it in $ctl.CategoryList.Items) { if ([string]$it.Tag -eq $name) { $ctl.CategoryList.SelectedItem = $it; break } }
}
function Get-HealthChecks {
    $out = @()
    $si = Get-SysInfo
    if ($si.Media -eq 'HDD') { $out += [pscustomobject]@{ Title = 'Hard drive (HDD) detected'; Status = 'info'; Detail = 'On an HDD, keep SysMain/Superfetch ON - disabling it can slow app launches. The single biggest speed-up for this PC would be moving Windows to an SSD.'; Goto = $null } }
    try {
        $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'" -ErrorAction Stop
        $freeGB = [int]($d.FreeSpace / 1GB); $pct = [int](100 * $d.FreeSpace / $d.Size)
        if ($freeGB -lt 20 -or $pct -lt 10) { $out += [pscustomobject]@{ Title = 'Low disk space'; Status = 'warn'; Detail = "$freeGB GB free on $env:SystemDrive ($pct%). Clear temp files and caches."; Goto = 'Maintenance' } }
        else { $out += [pscustomobject]@{ Title = 'Disk space OK'; Status = 'ok'; Detail = "$freeGB GB free on $env:SystemDrive."; Goto = $null } }
    } catch {}
    $wuBad = $false
    foreach ($n in 'wuauserv', 'UsoSvc', 'bits') { $s = Get-Service $n -ErrorAction SilentlyContinue; if ($s -and "$($s.StartType)" -eq 'Disabled') { $wuBad = $true } }
    if ((Get-RegVal 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoUpdate') -eq 1) { $wuBad = $true }
    if ($wuBad) { $out += [pscustomobject]@{ Title = 'Windows Update looks blocked'; Status = 'warn'; Detail = 'A service or policy is stopping updates. Run the Fixes.'; Goto = 'Fixes' } }
    else { $out += [pscustomobject]@{ Title = 'Windows Update OK'; Status = 'ok'; Detail = 'Update services look healthy.'; Goto = $null } }
    try {
        $en = @(Get-StartupItems | Where-Object { $_.Enabled }).Count
        if ($en -gt 8) { $out += [pscustomobject]@{ Title = 'Lots of startup apps'; Status = 'warn'; Detail = "$en apps launch at boot. Disabling heavy ones speeds up startup."; Goto = 'Startup' } }
        else { $out += [pscustomobject]@{ Title = 'Startup apps OK'; Status = 'ok'; Detail = "$en apps launch at boot."; Goto = $null } }
    } catch {}
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $pct = [int](100 * ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize)
        if ($pct -ge 85) { $out += [pscustomobject]@{ Title = 'High memory use'; Status = 'warn'; Detail = "RAM is $pct% full. Try Boost / Free up RAM, or close some apps."; Goto = 'Maintenance' } }
        else { $out += [pscustomobject]@{ Title = 'Memory OK'; Status = 'ok'; Detail = "RAM is $pct% in use."; Goto = $null } }
    } catch {}
    try {
        $tmp = (Get-ChildItem $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        if ($tmp -gt 1GB) { $out += [pscustomobject]@{ Title = 'Large temp folder'; Status = 'warn'; Detail = ("{0:N1} GB of temp files. Clear them in Maintenance." -f ($tmp / 1GB)); Goto = 'Maintenance' } }
    } catch {}
    if ((Get-RegVal 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' 'PendingFileRenameOperations') -or (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')) {
        $out += [pscustomobject]@{ Title = 'Restart pending'; Status = 'info'; Detail = 'A restart is needed to finish recent changes.'; Goto = $null }
    }
    $out
}
function Render-Health {
    $ctl.HeaderTitle.Text = (Get-CatIcon 'Health') + '  Health check'
    $checks = @(Get-HealthChecks)
    $warn = @($checks | Where-Object { $_.Status -eq 'warn' }).Count
    $ctl.HeaderSub.Text = if ($warn) { "$warn thing(s) worth looking at - green items are fine." } else { 'Everything looks good on this PC.' }
    $ctl.TweakList.Children.Clear()
    # system-spec card (scanned once at startup)
    $si = Get-SysInfo
    $syscard = New-Object Windows.Controls.Border; $syscard.Style = $window.FindResource('Card')
    $ssp = New-Object Windows.Controls.StackPanel
    $sh = New-Object Windows.Controls.TextBlock; $sh.Text = 'Your system'; $sh.Foreground = (New-Brush $Hex.fg); $sh.FontSize = 15; $sh.FontWeight = 'SemiBold'
    [void]$ssp.Children.Add($sh)
    $sb = New-Object Windows.Controls.TextBlock
    $sb.Text = "$($si.Cpu)  ($($si.Cores))`n$($si.RamGB) GB RAM   ·   $($si.Gpu)`n$($si.Os)`nSystem drive: $($si.Media)"
    $sb.Foreground = (New-Brush $Hex.muted); $sb.Margin = '0,7,0,0'; $sb.FontSize = 12.5; $sb.LineHeight = 19
    [void]$ssp.Children.Add($sb)
    $syscard.Child = $ssp
    [void]$ctl.TweakList.Children.Add($syscard)
    foreach ($ch in $checks) {
        $c = $ch
        $card = New-Object Windows.Controls.Border; $card.Style = $window.FindResource('Card')
        $grid = New-Object Windows.Controls.Grid
        $k0 = New-Object Windows.Controls.ColumnDefinition; $k0.Width = '*'
        $k1 = New-Object Windows.Controls.ColumnDefinition; $k1.Width = 'Auto'
        $grid.ColumnDefinitions.Add($k0); $grid.ColumnDefinitions.Add($k1)
        $left = New-Object Windows.Controls.StackPanel
        $row = New-Object Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'
        $stHex = if ($c.Status -eq 'warn') { $Hex.orange } elseif ($c.Status -eq 'info') { $Hex.blue } else { $Hex.green }
        $stTxt = if ($c.Status -eq 'warn') { 'Attention' } elseif ($c.Status -eq 'info') { 'Info' } else { 'OK' }
        $pill = New-Object Windows.Controls.Border; $pill.Background = (Tint $stHex '2E'); $pill.CornerRadius = 11; $pill.Padding = '10,3'; $pill.VerticalAlignment = 'Center'; $pill.Margin = '0,0,10,0'
        $pt = New-Object Windows.Controls.TextBlock; $pt.Text = $stTxt; $pt.Foreground = (New-Brush $stHex); $pt.FontSize = 11; $pt.FontWeight = 'SemiBold'; $pill.Child = $pt
        [void]$row.Children.Add($pill)
        $nm = New-Object Windows.Controls.TextBlock; $nm.Text = $c.Title; $nm.Foreground = (New-Brush $Hex.fg); $nm.FontSize = 15; $nm.FontWeight = 'SemiBold'; $nm.VerticalAlignment = 'Center'
        [void]$row.Children.Add($nm)
        [void]$left.Children.Add($row)
        $dt = New-Object Windows.Controls.TextBlock; $dt.Text = $c.Detail; $dt.Foreground = (New-Brush $Hex.muted); $dt.TextWrapping = 'Wrap'; $dt.Margin = '0,7,14,0'; $dt.FontSize = 12.5
        [void]$left.Children.Add($dt)
        [Windows.Controls.Grid]::SetColumn($left, 0); [void]$grid.Children.Add($left)
        if ($c.Goto) {
            $g = $c.Goto
            $btn = New-Object Windows.Controls.Button; $btn.Content = "Go to $g"; $btn.Width = 120; $btn.Style = $window.FindResource('GhostButton'); $btn.VerticalAlignment = 'Center'
            $btn.Add_Click({ Select-Category $g }.GetNewClosure())
            [Windows.Controls.Grid]::SetColumn($btn, 1); [void]$grid.Children.Add($btn)
        }
        $card.Child = $grid
        [void]$ctl.TweakList.Children.Add($card)
    }
}

# ---------------------------------------------------------------- shortcuts / icon
function New-AppIcon {
    $ico = Join-Path $scriptDir 'VoidTweaks.ico'
    try {
        Add-Type -AssemblyName System.Drawing
        $sz = 128
        $bmp = New-Object System.Drawing.Bitmap $sz, $sz
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.Clear([System.Drawing.Color]::Transparent)
        # dark rounded-rect backdrop (deep space)
        $rect = New-Object System.Drawing.Rectangle 6, 6, ($sz - 12), ($sz - 12)
        $d = 44
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
        $path.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
        $path.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
        $path.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
        $path.CloseFigure()
        $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(10, 10, 16))), $path)
        # tiny scattered stars (kept to the corners)
        foreach ($s in @(@(24, 26, 2), @(104, 24, 2.5), @(108, 102, 2), @(20, 104, 2.5), @(112, 60, 1.5), @(18, 58, 1.5))) {
            $r = $s[2]; $g.FillEllipse([System.Drawing.Brushes]::White, ($s[0] - $r), ($s[1] - $r), ($r * 2), ($r * 2))
        }
        # tilted accretion disk seen at an angle (wide + shallow) - Interstellar style
        $disk = New-Object System.Drawing.Rectangle 14, 40, 100, 48
        $glowPath = New-Object System.Drawing.Drawing2D.GraphicsPath; $glowPath.AddEllipse(6, 34, 116, 60)
        $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush ($glowPath)
        $pgb.CenterPoint = New-Object System.Drawing.PointF(64, 64)
        $pgb.CenterColor = [System.Drawing.Color]::FromArgb(170, 255, 170, 80)
        $pgb.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 255, 150, 60))
        $g.FillPath($pgb, $glowPath)
        # back of the disk (arcs behind and over the top)
        $backPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(225, 255, 165, 80), 7); $backPen.StartCap = 'Round'; $backPen.EndCap = 'Round'
        $g.DrawArc($backPen, $disk, 180, 180)
        # event horizon sphere
        $g.FillEllipse([System.Drawing.Brushes]::Black, 42, 42, 44, 44)
        # bright photon halo hugging the sphere
        $g.DrawEllipse((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(235, 255, 238, 212), 2.5)), 38, 38, 52, 52)
        # front of the disk (passes in front at the bottom, brightest)
        $frontPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 255, 205, 150), 8); $frontPen.StartCap = 'Round'; $frontPen.EndCap = 'Round'
        $g.DrawArc($frontPen, $disk, 0, 180)
        $corePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 255, 250, 238), 3); $corePen.StartCap = 'Round'; $corePen.EndCap = 'Round'
        $g.DrawArc($corePen, $disk, 0, 180)
        $g.Dispose()
        $hicon = $bmp.GetHicon()
        $icon = [System.Drawing.Icon]::FromHandle($hicon)
        $fs = [System.IO.File]::Create($ico); $icon.Save($fs); $fs.Close(); $icon.Dispose(); $bmp.Dispose()
        return $ico
    } catch { return $null }
}
function New-Shortcuts {
    $ico = New-AppIcon
    $argLine = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$PSCommandPath`""
    $ws = New-Object -ComObject WScript.Shell
    $made = 0
    foreach ($lnk in @((Join-Path ([Environment]::GetFolderPath('Desktop')) 'VoidTweaks.lnk'), (Join-Path ([Environment]::GetFolderPath('Programs')) 'VoidTweaks.lnk'))) {
        try {
            $sc = $ws.CreateShortcut($lnk)
            $sc.TargetPath = (Get-Command powershell.exe).Source
            $sc.Arguments = $argLine
            $sc.WorkingDirectory = $scriptDir
            if ($ico) { $sc.IconLocation = "$ico,0" }
            $sc.Description = 'VoidTweaks - transparent Windows optimizer'
            $sc.Save(); $made++
        } catch {}
    }
    Append-Log "Created $made shortcut(s): Desktop + Start menu."
    [Windows.MessageBox]::Show("Done - VoidTweaks is now on your Desktop and in the Start menu.`n`nTo pin it to the taskbar, right-click the shortcut and choose 'Pin to taskbar'.", 'VoidTweaks') | Out-Null
}

# ---------------------------------------------------------------- processes
# Core Windows processes that must never be ended (plus our own host), per Microsoft's
# critical-system-services list. These are shown locked, with no End button.
$script:CriticalProcs = @(
    'system', 'idle', 'registry', 'memcompression', 'smss', 'csrss', 'wininit', 'winlogon', 'services', 'lsass',
    'lsaiso', 'fontdrvhost', 'dwm', 'explorer', 'svchost', 'taskhostw', 'ctfmon', 'runtimebroker', 'sihost',
    'shellexperiencehost', 'startmenuexperiencehost', 'searchhost', 'searchindexer', 'textinputhost', 'wudfhost',
    'dllhost', 'conhost', 'audiodg', 'spoolsv', 'rundll32', 'msmpeng', 'nissrv', 'securityhealthservice',
    'securityhealthsystray', 'lockapp', 'logonui', 'smartscreen', 'applicationframehost', 'systemsettings',
    'wmiprvse', 'dashost', 'sgrmbroker', 'powershell', 'pwsh', 'windowsterminal', 'wininit'
)
# Known background bloat that is safe to end (it either stays gone or just respawns idle).
$script:BloatProcs = @(
    'cortana', 'searchapp', 'yourphone', 'phoneexperiencehost', 'gamebar', 'gamebarft', 'gamebarftserver',
    'gamebarpresencewriter', 'widgets', 'widgetservice', 'onedrive', 'msteams', 'teams', 'skypeapp',
    'feedbackhub', 'gethelp', 'clipchamp', 'mixedrealityportal', 'peopleexperiencehost'
)
function Get-ProcessList {
    $me = $PID
    Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $me } | Group-Object ProcessName | ForEach-Object {
        $ws = ($_.Group | Measure-Object -Property WorkingSet64 -Sum).Sum
        $lc = $_.Name.ToLower()
        $type = if ($script:CriticalProcs -contains $lc) { 'system' } elseif ($script:BloatProcs -contains $lc) { 'bloat' } else { 'other' }
        [pscustomobject]@{ Name = $_.Name; Count = $_.Count; WS = $ws; Type = $type }
    } | Where-Object { $_.WS -gt 20MB -or $_.Type -eq 'bloat' } | Sort-Object WS -Descending
}
function Stop-ProcessItem { param($it)
    $res = [Windows.MessageBox]::Show("End all '$($it.Name)' process(es)?`n`nAny unsaved work in that app will be lost - you can reopen it afterwards.", 'VoidTweaks', 'YesNo', 'Warning')
    if ($res -ne 'Yes') { return }
    Stop-Process -Name $it.Name -Force -ErrorAction SilentlyContinue
    Append-Log "Ended process '$($it.Name)'."
    Start-Sleep -Milliseconds 300
    Render
}
function Render-Processes {
    $ctl.HeaderTitle.Text = (Get-CatIcon 'Processes') + '  Processes'
    $list = @(Get-ProcessList)
    $bloat = @($list | Where-Object { $_.Type -eq 'bloat' }).Count
    $ctl.HeaderSub.Text = "$($list.Count) shown, heaviest first. Green = safe to end; SYSTEM ones are locked. $bloat known background app(s) you can close."
    $ctl.TweakList.Children.Clear()
    foreach ($p in $list) {
        $it = $p
        $card = New-Object Windows.Controls.Border; $card.Style = $window.FindResource('Card')
        $grid = New-Object Windows.Controls.Grid
        $k0 = New-Object Windows.Controls.ColumnDefinition; $k0.Width = '*'
        $k1 = New-Object Windows.Controls.ColumnDefinition; $k1.Width = 'Auto'
        $grid.ColumnDefinitions.Add($k0); $grid.ColumnDefinitions.Add($k1)
        $left = New-Object Windows.Controls.StackPanel
        $row = New-Object Windows.Controls.StackPanel; $row.Orientation = 'Horizontal'
        $nm = New-Object Windows.Controls.TextBlock; $nm.Text = $it.Name; $nm.Foreground = (New-Brush $Hex.fg); $nm.FontSize = 15; $nm.FontWeight = 'SemiBold'; $nm.VerticalAlignment = 'Center'; $nm.Margin = '0,0,10,0'
        [void]$row.Children.Add($nm)
        if ($it.Count -gt 1) { [void]$row.Children.Add((New-Badge "x$($it.Count)" $Hex.muted)) }
        if ($it.Type -eq 'system') { [void]$row.Children.Add((New-Badge 'SYSTEM' $Hex.muted)) }
        [void]$left.Children.Add($row)
        $dt = New-Object Windows.Controls.TextBlock; $dt.Text = ('{0:N0} MB memory' -f ($it.WS / 1MB)); $dt.Foreground = (New-Brush $Hex.muted); $dt.Margin = '0,6,14,0'; $dt.FontSize = 12.5
        [void]$left.Children.Add($dt)
        [Windows.Controls.Grid]::SetColumn($left, 0); [void]$grid.Children.Add($left)
        $right = New-Object Windows.Controls.StackPanel; $right.HorizontalAlignment = 'Right'; $right.VerticalAlignment = 'Center'
        $pHex = if ($it.Type -eq 'bloat') { $Hex.green } elseif ($it.Type -eq 'system') { $Hex.muted } else { $Hex.blue }
        $pTxt = if ($it.Type -eq 'bloat') { 'Safe to end' } elseif ($it.Type -eq 'system') { 'Locked' } else { 'Running' }
        $pill = New-Object Windows.Controls.Border; $pill.Background = (Tint $pHex '2E'); $pill.CornerRadius = 11; $pill.Padding = '11,4'; $pill.HorizontalAlignment = 'Right'
        $pt = New-Object Windows.Controls.TextBlock; $pt.Text = $pTxt; $pt.Foreground = (New-Brush $pHex); $pt.FontSize = 11; $pt.FontWeight = 'SemiBold'; $pill.Child = $pt
        [void]$right.Children.Add($pill)
        if ($it.Type -ne 'system') {
            $btn = New-Object Windows.Controls.Button; $btn.Content = 'End task'; $btn.Width = 92; $btn.Margin = '0,10,0,0'; $btn.HorizontalAlignment = 'Right'
            $btn.Style = if ($it.Type -eq 'bloat') { $window.FindResource('SuccessButton') } else { $window.FindResource('GhostButton') }
            $btn.Add_Click({ Stop-ProcessItem $it }.GetNewClosure())
            [void]$right.Children.Add($btn)
        }
        [Windows.Controls.Grid]::SetColumn($right, 1); [void]$grid.Children.Add($right)
        $card.Child = $grid
        [void]$ctl.TweakList.Children.Add($card)
    }
}

# ---------------------------------------------------------------- settings view
function New-ChoiceButton { param([string]$label, [bool]$selected, [scriptblock]$onClick)
    $b = New-Object Windows.Controls.Button
    $b.Content = $label; $b.Margin = '0,0,8,8'; $b.MinWidth = 108
    $b.Style = if ($selected) { $window.FindResource('AccentButton') } else { $window.FindResource('GhostButton') }
    $b.Add_Click($onClick)
    $b
}
function New-SettingsCard { param([string]$title, [string]$desc, $buttons)
    $card = New-Object Windows.Controls.Border; $card.Style = $window.FindResource('Card')
    $sp = New-Object Windows.Controls.StackPanel
    $t = New-Object Windows.Controls.TextBlock; $t.Text = $title; $t.Foreground = (New-Brush $Hex.fg); $t.FontSize = 15; $t.FontWeight = 'SemiBold'
    [void]$sp.Children.Add($t)
    if ($desc) { $d = New-Object Windows.Controls.TextBlock; $d.Text = $desc; $d.Foreground = (New-Brush $Hex.muted); $d.TextWrapping = 'Wrap'; $d.Margin = '0,6,0,12'; $d.FontSize = 12.5; [void]$sp.Children.Add($d) }
    $wrap = New-Object Windows.Controls.WrapPanel
    foreach ($b in $buttons) { [void]$wrap.Children.Add($b) }
    [void]$sp.Children.Add($wrap)
    $card.Child = $sp
    [void]$ctl.TweakList.Children.Add($card)
}
function Render-Settings {
    $ctl.HeaderTitle.Text = (Get-CatIcon 'Settings') + '  Settings'
    $ctl.HeaderSub.Text = 'Theme and layout. Changes take effect after a quick restart of the app.'
    $ctl.TweakList.Children.Clear()
    New-SettingsCard 'Theme' 'Pick a colour palette. Soft Dark and Comfy are the gentle, low-contrast ones.' @(
        (New-ChoiceButton 'Soft Dark' ($script:settings.theme -eq 'softdark') { $script:settings.theme = 'softdark'; Render-Settings }),
        (New-ChoiceButton 'Dark'      ($script:settings.theme -eq 'dark')     { $script:settings.theme = 'dark'; Render-Settings }),
        (New-ChoiceButton 'Light'     ($script:settings.theme -eq 'light')    { $script:settings.theme = 'light'; Render-Settings }),
        (New-ChoiceButton 'Comfy'     ($script:settings.theme -eq 'comfy')    { $script:settings.theme = 'comfy'; Render-Settings })
    )
    New-SettingsCard 'Layout density' 'Compact fits more on screen; Big and Smooth are roomier and more rounded.' @(
        (New-ChoiceButton 'Compact' ($script:settings.density -eq 'compact') { $script:settings.density = 'compact'; Render-Settings }),
        (New-ChoiceButton 'Simple'  ($script:settings.density -eq 'simple')  { $script:settings.density = 'simple'; Render-Settings }),
        (New-ChoiceButton 'Big'     ($script:settings.density -eq 'big')     { $script:settings.density = 'big'; Render-Settings }),
        (New-ChoiceButton 'Smooth'  ($script:settings.density -eq 'smooth')  { $script:settings.density = 'smooth'; Render-Settings })
    )
    $applyCard = New-Object Windows.Controls.Border; $applyCard.Style = $window.FindResource('Card')
    $asp = New-Object Windows.Controls.StackPanel
    $atext = New-Object Windows.Controls.TextBlock; $atext.Text = "Current pick: $($script:settings.theme) / $($script:settings.density). Apply restarts VoidTweaks to load it."; $atext.Foreground = (New-Brush $Hex.muted); $atext.Margin = '0,0,0,12'; $atext.TextWrapping = 'Wrap'; $atext.FontSize = 12.5
    [void]$asp.Children.Add($atext)
    $ab = New-Object Windows.Controls.Button; $ab.Content = 'Apply & restart'; $ab.Style = $window.FindResource('AccentButton'); $ab.HorizontalAlignment = 'Left'
    $ab.Add_Click({ Save-Settings $script:settings; Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$PSCommandPath`""; $window.Close() })
    [void]$asp.Children.Add($ab)
    $applyCard.Child = $asp
    [void]$ctl.TweakList.Children.Add($applyCard)
}

function Rename-UserPreset { param($p)
    Add-Type -AssemblyName Microsoft.VisualBasic
    $new = [Microsoft.VisualBasic.Interaction]::InputBox('New name for this preset:', 'Rename preset', [string]$p.name)
    if ([string]::IsNullOrWhiteSpace($new)) { return }
    try {
        $obj = Get-Content $p._file -Raw | ConvertFrom-Json
        $obj.name = $new
        $obj | ConvertTo-Json | Set-Content $p._file -Encoding utf8
        Append-Log "Renamed preset to '$new'."; Render
    } catch { [Windows.MessageBox]::Show("Couldn't rename: $($_.Exception.Message)", 'VoidTweaks') | Out-Null }
}

function Show-Tutorial {
    $steps = @(
        "Welcome to VoidTweaks!`n`nA transparent, reversible Windows optimizer - no account, no telemetry, nothing hidden.`n`n(OK = next, Cancel = skip the tour)",
        "The basics:`n`n- 'Scan PC' reads your current settings`n- Every tweak has Apply and Revert`n- 'Restore point first' is on by default, so you can always roll back",
        "Handy spots:`n`n- Boost now - free RAM in one click`n- Health - what's worth fixing, in plain English`n- Presets - save and switch whole setups`n- Startup & Processes - trim what runs",
        "Admin & looks:`n`nTweaks that need administrator are greyed out until you click 'Restart as administrator' at the top.`n`nSettings lets you change the theme and layout. Enjoy!"
    )
    foreach ($s in $steps) {
        $r = [Windows.MessageBox]::Show($s, 'VoidTweaks - quick tour', 'OKCancel', 'Information')
        if ($r -ne 'OK') { break }
    }
    $script:settings.seenTutorial = $true
    Save-Settings $script:settings
}

# ---------------------------------------------------------------- wire up
$script:isAdmin = Test-Admin
if ($script:isAdmin) {
    $ctl.AdminBar.Visibility = 'Collapsed'
} else {
    $ctl.ElevateBtn.Add_Click({
        try {
            Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$PSCommandPath`"")
            $window.Close()
        } catch { [Windows.MessageBox]::Show("Could not elevate: $($_.Exception.Message)", 'OpenTweaks') | Out-Null }
    })
}

# sidebar with group headers (MENU / TWEAKS / APP)
function Add-SideGroup([string]$label) {
    $gi = New-Object Windows.Controls.ListBoxItem
    $gi.IsHitTestVisible = $false; $gi.Focusable = $false
    $tb = New-Object Windows.Controls.TextBlock
    $tb.Text = $label; $tb.FontSize = 10; $tb.FontWeight = 'Bold'; $tb.Foreground = (New-Brush $Hex.faint); $tb.Margin = '6,13,0,2'
    $gi.Content = $tb
    [void]$ctl.CategoryList.Items.Add($gi)
}
function Add-SideItem([string]$c) {
    $item = New-Object Windows.Controls.ListBoxItem
    $item.Tag = $c
    $sp = New-Object Windows.Controls.StackPanel; $sp.Orientation = 'Horizontal'
    $col = $CatColor[$c]; if (-not $col) { $col = $Hex.muted }
    $icon = New-VectorIcon $c $col
    $lbl = New-Object Windows.Controls.TextBlock; $lbl.Text = $c; $lbl.VerticalAlignment = 'Center'
    [void]$sp.Children.Add($icon); [void]$sp.Children.Add($lbl)
    $item.Content = $sp
    [void]$ctl.CategoryList.Items.Add($item)
}
Add-SideGroup 'MENU'
foreach ($c in @('All', $needs, 'Presets', 'Startup', 'Health', 'Processes')) { Add-SideItem $c }
Add-SideGroup 'TWEAKS'
foreach ($c in @($catalog.categories)) { Add-SideItem $c }
Add-SideGroup 'APP'
Add-SideItem 'Settings'
$ctl.CategoryList.SelectedIndex = 1   # 'All' (index 0 is the MENU header)
$ctl.CategoryList.Add_SelectionChanged({ Render })

# search box with placeholder
$ctl.SearchBox.Add_TextChanged({ Render })
$ctl.SearchBox.Add_GotFocus({ if ($ctl.SearchBox.Text -eq 'Search tweaks...') { $ctl.SearchBox.Text = '' ; $ctl.SearchBox.Foreground = (New-Brush $Hex.fg) } })
$ctl.SearchBox.Add_LostFocus({ if ([string]::IsNullOrWhiteSpace($ctl.SearchBox.Text)) { $ctl.SearchBox.Text = 'Search tweaks...'; $ctl.SearchBox.Foreground = (New-Brush $Hex.muted) } })
$ctl.SearchBox.Text = 'Search tweaks...'
$ctl.SearchBox.Foreground = (New-Brush $Hex.muted)

$ctl.BoostBtn.Add_Click({ Invoke-Boost })
$ctl.ScanBtn.Add_Click({ Invoke-Scan })
$ctl.ApplyAllBtn.Add_Click({ Invoke-Bulk (@(Get-ShownTweaks)) 'apply' (Get-SelCat) })
$ctl.RevertAllBtn.Add_Click({ Invoke-Bulk (@(Get-ShownTweaks)) 'revert' (Get-SelCat) })
$ctl.UndoBtn.IsEnabled = $false
$ctl.UndoBtn.Add_Click({ Invoke-Undo })
$ctl.MiUndo.Add_Click({ Invoke-Undo })

$ctl.MiScan.Add_Click({ Invoke-Scan })
$ctl.MiExit.Add_Click({ $window.Close() })
$ctl.MiRecommended.Add_Click({
    $set = @($catalog.tweaks | Where-Object { $RecommendedIds -contains $_.id })
    Invoke-Bulk $set 'apply' 'Recommended (slow PC)'
})
$ctl.MiRevertAll.Add_Click({
    $res = [Windows.MessageBox]::Show('Revert every reversible tweak back to Windows defaults?', 'OpenTweaks', 'YesNo', 'Question')
    if ($res -eq 'Yes') {
        $set = @($catalog.tweaks | Where-Object { $_.reversible -and $_.revert -and $_.revert.Count })
        Invoke-Bulk $set 'revert' 'everything'
    }
})
$ctl.MiRestore.Add_Click({
    if (-not $script:isAdmin) { [Windows.MessageBox]::Show('Creating a restore point needs administrator.', 'OpenTweaks') | Out-Null; return }
    Append-Log 'Creating a System Restore point...'
    Start-Run -Commands @((Get-RestorePointCmd)) -Label 'restore point' -Dry $false -OnDone { Set-Status 'Restore point requested.' }
})
$ctl.MiExport.Add_Click({
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter = 'JSON profile (*.json)|*.json'; $dlg.FileName = 'opentweaks-profile.json'
    if ($dlg.ShowDialog()) {
        $applied = @($catalog.tweaks | Where-Object { $script:stateCache[$_.id] -eq 'applied' } | ForEach-Object { $_.id })
        [pscustomobject]@{ exportedAt = [DateTime]::Now.ToString('s'); applied = $applied } |
            ConvertTo-Json | Set-Content -Path $dlg.FileName -Encoding utf8
        Append-Log "Exported $($applied.Count) applied tweak id(s) to $($dlg.FileName)"
        Set-Status "Exported $($applied.Count) tweak(s)."
    }
})
$ctl.MiImport.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = 'JSON profile (*.json)|*.json'
    if ($dlg.ShowDialog()) {
        try {
            $prof = Get-Content $dlg.FileName -Raw | ConvertFrom-Json
            $set = @($catalog.tweaks | Where-Object { $prof.applied -contains $_.id })
            Append-Log "Importing profile: $($set.Count) tweak(s) from $($dlg.FileName)"
            Invoke-Bulk $set 'apply' 'imported profile'
        } catch { [Windows.MessageBox]::Show("Could not read profile: $($_.Exception.Message)", 'OpenTweaks') | Out-Null }
    }
})
$ctl.MiShortcut.Add_Click({ New-Shortcuts })
$ctl.MiLog.Add_Click({
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
    Start-Process explorer.exe $logDir
})
$ctl.MiAbout.Add_Click({
    [Windows.MessageBox]::Show(
        "VoidTweaks`n`nA transparent, reversible Windows optimizer.`nNo account, no telemetry, no network calls, no paywall.`n`nEvery tweak's exact commands live in tweaks.json. Everything you do is logged to:`n$logFile`n`n$($catalog.tweaks.Count) tweaks across $($catalog.categories.Count) categories.",
        'About VoidTweaks') | Out-Null
})

Append-Log 'VoidTweaks ready. Click "Scan PC" to read your current settings.'
if (-not $script:isAdmin) { Append-Log 'Tip: some tweaks (and the Fixes) need admin - use "Restart as administrator" at the top.' }

# animated (eased) smooth wheel scrolling for the main list
$scrollTimer = New-Object Windows.Threading.DispatcherTimer
$scrollTimer.Interval = [TimeSpan]::FromMilliseconds(15)
$script:scrollTarget = 0.0
$scrollTimer.Add_Tick({
    $sv = $ctl.MainScroll
    $cur = $sv.VerticalOffset
    $diff = $script:scrollTarget - $cur
    if ([Math]::Abs($diff) -lt 0.5) { $sv.ScrollToVerticalOffset($script:scrollTarget); $scrollTimer.Stop(); return }
    $sv.ScrollToVerticalOffset($cur + $diff * 0.2)
})
$ctl.MainScroll.Add_PreviewMouseWheel({
    param($s, $e)
    $e.Handled = $true
    if (-not $scrollTimer.IsEnabled) { $script:scrollTarget = $ctl.MainScroll.VerticalOffset }
    $script:scrollTarget = [Math]::Max(0, [Math]::Min($ctl.MainScroll.ScrollableHeight, $script:scrollTarget - ($e.Delta * 1.1)))
    $scrollTimer.Start()
})

$window.Add_ContentRendered({
        Update-DashStatic; Update-DashLive; $dashTimer.Start()
        $si = Get-SysInfo; Append-Log "System: $($si.Cpu) · $($si.RamGB) GB RAM · $($si.Gpu) · system drive $($si.Media)"
        Invoke-Scan
        if (-not $script:settings.seenTutorial) { Show-Tutorial }
    })

if ($NoShow) {
    Update-DashStatic; Update-DashLive
    Invoke-Scan
    Render-Presets
    Render-Startup
    Render-Health
    Render-Processes
    Render-Settings
    $icoPath = New-AppIcon
    Write-Host "SELF-TEST OK: theme=$($script:settings.theme)/$($script:settings.density), tweaks=$($catalog.tweaks.Count), presets=$((Get-Presets).Count), startup=$((Get-StartupItems).Count), health=$((Get-HealthChecks).Count), procs=$((Get-ProcessList).Count), icon=$(if($icoPath){'ok'}else{'FAILED'}), admin=$script:isAdmin"
} else {
    [void]$window.ShowDialog()
}
