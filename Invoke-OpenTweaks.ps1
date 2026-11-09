<#
.SYNOPSIS
    OpenTweaks - a transparent, reversible Windows tweaking engine.

.DESCRIPTION
    Reads tweaks.json (next to this script) and applies or reverts individual
    tweaks or whole categories. Everything is local and open: no telemetry, no
    network calls, no licensing. Before applying anything it can create a System
    Restore point, and every tweak carries an explicit revert.

    Features that closed optimizers don't give you:
      -DryRun        print the exact commands, run nothing
      -Status        read the registry and show which tweaks are already applied
      -Export/-Import save and restore a tweak profile as plain JSON
      -Recommended   a safe, high-impact set tuned for an old / slow PC

.EXAMPLE
    .\Invoke-OpenTweaks.ps1 -List
.EXAMPLE
    .\Invoke-OpenTweaks.ps1 -Status
.EXAMPLE
    .\Invoke-OpenTweaks.ps1 -Info game-dvr-off
.EXAMPLE
    .\Invoke-OpenTweaks.ps1 -Apply game-dvr-off -DryRun
.EXAMPLE
    .\Invoke-OpenTweaks.ps1 -Recommended            # apply the slow-PC set
.EXAMPLE
    .\Invoke-OpenTweaks.ps1 -Export myprofile.json
.EXAMPLE
    .\Invoke-OpenTweaks.ps1 -Import myprofile.json
#>
[CmdletBinding(DefaultParameterSetName = 'List')]
param(
    [Parameter(ParameterSetName = 'List')]    [switch]$List,
    [Parameter(ParameterSetName = 'Status')]  [switch]$Status,
    [Parameter(ParameterSetName = 'Info')]    [string]$Info,
    [Parameter(ParameterSetName = 'Apply')]   [string]$Apply,
    [Parameter(ParameterSetName = 'Revert')]  [string]$Revert,
    [Parameter(ParameterSetName = 'Recommended')] [switch]$Recommended,
    [Parameter(ParameterSetName = 'Export')]  [string]$Export,
    [Parameter(ParameterSetName = 'Import')]  [string]$Import,
    [string]$Category,
    [switch]$DryRun,
    [switch]$NoRestorePoint
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$catalogPath = Join-Path $scriptDir 'tweaks.json'
$logDir = Join-Path $env:LOCALAPPDATA 'OpenTweaks'
$logFile = Join-Path $logDir 'opentweaks.log'

# Curated, safe, high-impact set for an aging machine.
$RecommendedIds = @(
    'perf-startup-delay', 'perf-sysmain', 'perf-high-power-plan',
    'visual-best-performance', 'visual-transparency-off', 'visual-menu-delay',
    'priv-suggested-content', 'game-dvr-off', 'debloat-widgets',
    'clean-temp', 'clean-windows-temp'
)

if (-not (Test-Path $catalogPath)) { throw "Catalog not found: $catalogPath" }
$catalog = Get-Content $catalogPath -Raw | ConvertFrom-Json

# shared helpers for the Maintenance actions (Optimize-RAM, Clear-StandbyList)
$actionsPath = Join-Path $scriptDir 'OpenTweaks.Actions.ps1'
if (Test-Path $actionsPath) { . $actionsPath }

function Write-Log {
    param([string]$Message)
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
    "$([DateTime]::Now.ToString('s'))  $Message" | Add-Content -Path $logFile -Encoding utf8
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Get-Tweaks {
    param([string]$Selector)
    if ([string]::IsNullOrWhiteSpace($Selector) -or $Selector -eq 'all') { return $catalog.tweaks }
    $byId = $catalog.tweaks | Where-Object { $_.id -eq $Selector }
    if ($byId) { return $byId }
    $byCat = $catalog.tweaks | Where-Object { $_.category -eq $Selector }
    if ($byCat) { return $byCat }
    throw "No tweak or category matches '$Selector'. Use -List to see ids."
}

# Parse a 'reg add "KEY" /v NAME /t TYPE /d VALUE /f' command into parts (best effort).
function Get-RegOp {
    param([string]$Command)
    $m = [regex]::Match($Command, 'reg add "([^"]+)" /v (\S+) /t (\S+) /d (\S+) /f')
    if (-not $m.Success) { return $null }
    [pscustomobject]@{
        Path  = 'Registry::' + ($m.Groups[1].Value -replace '^HKLM', 'HKEY_LOCAL_MACHINE' -replace '^HKCU', 'HKEY_CURRENT_USER')
        Name  = $m.Groups[2].Value
        Type  = $m.Groups[3].Value
        Value = $m.Groups[4].Value
    }
}

# Returns: applied | default | custom | n/a  (best-effort, registry tweaks only)
function Get-TweakState {
    param($Tweak)
    $applyOp = $null
    foreach ($c in $Tweak.apply) { $applyOp = Get-RegOp $c; if ($applyOp) { break } }
    if (-not $applyOp) { return 'n/a' }
    try {
        $current = Get-ItemPropertyValue -Path $applyOp.Path -Name $applyOp.Name -ErrorAction Stop
    } catch { return 'default' }   # value absent = not applied
    $cur = "$current"; $want = "$($applyOp.Value)"
    # normalise DWORD numeric compare where possible
    $n1 = 0; $n2 = 0
    if ([int64]::TryParse($cur, [ref]$n1) -and [int64]::TryParse($want, [ref]$n2)) {
        if ($n1 -eq $n2 -or ($n2 -eq 4294967295 -and $n1 -eq -1)) { return 'applied' }
        return 'custom'
    }
    if ($cur -eq $want) { return 'applied' } else { return 'custom' }
}

function Show-List {
    $items = if ($Category) { $catalog.tweaks | Where-Object { $_.category -eq $Category } } else { $catalog.tweaks }
    $items | Sort-Object category, id | Format-Table -AutoSize @(
        @{ L = 'Id'; E = { $_.id } },
        @{ L = 'Category'; E = { $_.category } },
        @{ L = 'Risk'; E = { $_.risk } },
        @{ L = 'Admin'; E = { if ($_.requiresAdmin) { 'yes' } else { '' } } },
        @{ L = 'Reboot'; E = { if ($_.needsRestart) { 'yes' } else { '' } } },
        @{ L = 'Name'; E = { $_.name } }
    )
    Write-Host "`n$($items.Count) tweak(s). -Info <id> for commands, -Status for current state.`n" -ForegroundColor DarkGray
}

function Show-Status {
    $items = if ($Category) { $catalog.tweaks | Where-Object { $_.category -eq $Category } } else { $catalog.tweaks }
    Write-Host "`nReading current system state...`n" -ForegroundColor DarkGray
    $rows = foreach ($t in ($items | Sort-Object category, id)) {
        [pscustomobject]@{ Id = $t.id; Category = $t.category; State = (Get-TweakState $t); Name = $t.name }
    }
    $rows | Format-Table -AutoSize @(
        @{ L = 'Id'; E = { $_.Id } },
        @{ L = 'Category'; E = { $_.Category } },
        @{ L = 'State'; E = { $_.State } },
        @{ L = 'Name'; E = { $_.Name } }
    )
    $applied = ($rows | Where-Object State -eq 'applied').Count
    Write-Host "`napplied=$applied  (state is detected for registry tweaks; powercfg/service/action tweaks show n/a)`n" -ForegroundColor DarkGray
}

function Show-Info {
    param($Tweak)
    Write-Host "`n$($Tweak.name)" -ForegroundColor Cyan
    Write-Host "  id:        $($Tweak.id)"
    Write-Host "  category:  $($Tweak.category)   risk: $($Tweak.risk)   impact: $($Tweak.impact)"
    Write-Host "  admin:     $($Tweak.requiresAdmin)   reboot: $($Tweak.needsRestart)   reversible: $($Tweak.reversible)"
    Write-Host "  state:     $(Get-TweakState $Tweak)"
    Write-Host "  $($Tweak.description)" -ForegroundColor Gray
    Write-Host "`n  APPLY:" -ForegroundColor Green
    $Tweak.apply | ForEach-Object { Write-Host "    $_" }
    if ($Tweak.revert -and $Tweak.revert.Count) {
        Write-Host "`n  REVERT:" -ForegroundColor Yellow
        $Tweak.revert | ForEach-Object { Write-Host "    $_" }
    } else {
        Write-Host "`n  REVERT: (one-time action, nothing to undo)" -ForegroundColor DarkYellow
    }
    Write-Host ""
}

function New-RestorePointSafe {
    if ($NoRestorePoint -or $DryRun) { return }
    if (-not (Test-Admin)) { Write-Host "  (skip restore point: needs admin)" -ForegroundColor DarkGray; return }
    try {
        Write-Host "  Creating System Restore point..." -ForegroundColor DarkGray
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "OpenTweaks $([DateTime]::Now.ToString('g'))" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Log "Created restore point"
    } catch {
        Write-Host "  (restore point not created: $($_.Exception.Message))" -ForegroundColor DarkYellow
    }
}

function Invoke-Commands {
    param($Tweak, [string]$Mode)  # Mode = 'apply' | 'revert'
    $commands = if ($Mode -eq 'revert') { $Tweak.revert } else { $Tweak.apply }
    if (-not $commands -or $commands.Count -eq 0) {
        Write-Host "  [$($Tweak.id)] nothing to $Mode." -ForegroundColor DarkYellow
        return
    }
    if ($Tweak.requiresAdmin -and -not (Test-Admin) -and -not $DryRun) {
        Write-Host "  [$($Tweak.id)] SKIPPED - needs an elevated (admin) PowerShell." -ForegroundColor Red
        Write-Log "SKIP $Mode $($Tweak.id) (not admin)"
        return
    }
    Write-Host "  [$($Tweak.id)] $Mode : $($Tweak.name)" -ForegroundColor Cyan
    foreach ($cmd in $commands) {
        if ($DryRun) { Write-Host "    WOULD RUN: $cmd" -ForegroundColor DarkGray; continue }
        try {
            Invoke-Expression $cmd | Out-Null
            Write-Host "    ok: $cmd" -ForegroundColor DarkGreen
            Write-Log "$Mode OK  $($Tweak.id) :: $cmd"
        } catch {
            Write-Host "    FAIL: $cmd  -> $($_.Exception.Message)" -ForegroundColor Red
            Write-Log "$Mode FAIL $($Tweak.id) :: $cmd :: $($_.Exception.Message)"
        }
    }
    if ($Tweak.needsRestart) { Write-Host "    (a restart is needed for this to take full effect)" -ForegroundColor Yellow }
}

function Invoke-Apply {
    param([object[]]$Tweaks, [string]$Label)
    Write-Host "`nApplying $($Tweaks.Count) tweak(s) [$Label]`n" -ForegroundColor White
    New-RestorePointSafe
    foreach ($t in $Tweaks) { Invoke-Commands $t 'apply' }
    Write-Host "`nDone. Revert any time with -Revert <id>.`n" -ForegroundColor White
}

# ---- dispatch ----
Write-Host "OpenTweaks - transparent, reversible Windows tweaks" -ForegroundColor White
if ($DryRun) { Write-Host "(dry run - nothing will be executed)`n" -ForegroundColor Yellow }

switch ($PSCmdlet.ParameterSetName) {
    'List'   { Show-List }
    'Status' { Show-Status }
    'Info'   { Show-Info (Get-Tweaks $Info | Select-Object -First 1) }
    'Apply'  {
        $target = if ($Apply) { $Apply } elseif ($Category) { $Category } else { 'all' }
        Invoke-Apply (Get-Tweaks $target) $target
    }
    'Recommended' {
        $tweaks = $catalog.tweaks | Where-Object { $RecommendedIds -contains $_.id }
        Write-Host "`nRecommended set for an old/slow PC: $($tweaks.Count) tweak(s)." -ForegroundColor White
        Invoke-Apply $tweaks 'recommended'
    }
    'Revert' {
        $target = if ($Revert) { $Revert } else { 'all' }
        $tweaks = Get-Tweaks $target
        Write-Host "`nReverting $($tweaks.Count) tweak(s) [$target]`n" -ForegroundColor White
        foreach ($t in $tweaks) { Invoke-Commands $t 'revert' }
        Write-Host "`nDone.`n" -ForegroundColor White
    }
    'Export' {
        $applied = @($catalog.tweaks | Where-Object { (Get-TweakState $_) -eq 'applied' } | ForEach-Object { $_.id })
        $profile = [pscustomobject]@{ exportedAt = [DateTime]::Now.ToString('s'); applied = $applied }
        $profile | ConvertTo-Json | Set-Content -Path $Export -Encoding utf8
        Write-Host "`nExported $($applied.Count) applied tweak id(s) to $Export`n" -ForegroundColor White
    }
    'Import' {
        if (-not (Test-Path $Import)) { throw "Profile not found: $Import" }
        $profile = Get-Content $Import -Raw | ConvertFrom-Json
        $tweaks = $catalog.tweaks | Where-Object { $profile.applied -contains $_.id }
        Write-Host "`nImporting profile: $($tweaks.Count) tweak(s) from $Import" -ForegroundColor White
        Invoke-Apply $tweaks 'imported'
    }
}
