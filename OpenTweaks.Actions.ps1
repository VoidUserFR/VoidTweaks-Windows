<#
    OpenTweaks.Actions.ps1 - helper functions for the Maintenance actions.

    These are dot-sourced into the runner (and by the CLI engine) so a tweak's
    command can just call e.g. "Optimize-RAM". Kept in one place so the GUI and
    the command-line engine behave identically.
#>

# Trim the working set of every process we can touch, pushing idle pages out of
# physical RAM. No admin needed for your own processes (admin reaches all of them).
function Optimize-RAM {
    $sig = '[DllImport("psapi.dll")] public static extern bool EmptyWorkingSet(IntPtr hProcess);'
    if (-not ('OTMem' -as [type])) {
        Add-Type -Name OTMem -Namespace '' -MemberDefinition $sig -ErrorAction SilentlyContinue
    }
    $n = 0
    Get-Process | ForEach-Object {
        try { if ([OTMem]::EmptyWorkingSet($_.Handle)) { $n++ } } catch {}
    }
    "Trimmed the working set of $n process(es). Cached pages move to standby; free RAM should rise."
}

# Replicates RAMMap: empty all working sets (2), flush the modified page list (3),
# then purge the standby list (4) - via NtSetSystemInformation(SystemMemoryListInformation
# = 0x50, &cmd, 4) under SeProfileSingleProcessPrivilege. The 2->3->4 sequence is what
# actually reclaims the most RAM back to "free". Needs an elevated (admin) run.
function Clear-StandbyList {
    $src = @'
using System;
using System.Runtime.InteropServices;
public static class OTVoidMem {
    [DllImport("ntdll.dll")] static extern int NtSetSystemInformation(int infoClass, ref int info, int length);
    [DllImport("advapi32.dll", SetLastError=true)] static extern bool OpenProcessToken(IntPtr h, int access, out IntPtr token);
    [DllImport("advapi32.dll", SetLastError=true)] static extern bool LookupPrivilegeValue(string host, string name, out long luid);
    [StructLayout(LayoutKind.Sequential)] struct TOKPRIV { public int Count; public long Luid; public int Attr; }
    [DllImport("advapi32.dll", SetLastError=true)] static extern bool AdjustTokenPrivileges(IntPtr token, bool dis, ref TOKPRIV ns, int len, IntPtr prev, IntPtr ret);
    [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
    [StructLayout(LayoutKind.Sequential)] public struct MEMSTAT { public uint dwLength; public uint dwMemoryLoad; public ulong total; public ulong avail; public ulong a; public ulong b; public ulong c; public ulong d; public ulong e; }
    [DllImport("kernel32.dll")] public static extern bool GlobalMemoryStatusEx(ref MEMSTAT b);
    static void EnablePriv() {
        IntPtr t;
        if (OpenProcessToken(GetCurrentProcess(), 0x28, out t)) {
            long l;
            if (LookupPrivilegeValue(null, "SeProfileSingleProcessPrivilege", out l)) {
                TOKPRIV tp; tp.Count = 1; tp.Luid = l; tp.Attr = 0x2;
                AdjustTokenPrivileges(t, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
            }
        }
    }
    public static ulong Avail() { MEMSTAT m = new MEMSTAT(); m.dwLength = (uint)Marshal.SizeOf(m); GlobalMemoryStatusEx(ref m); return m.avail; }
    public static int Run(int cmd) { EnablePriv(); int c = cmd; return NtSetSystemInformation(0x50, ref c, 4); }
}
'@
    if (-not ('OTVoidMem' -as [type])) { Add-Type -TypeDefinition $src -ErrorAction Stop }
    $before = [OTVoidMem]::Avail()
    [void][OTVoidMem]::Run(2)   # MemoryEmptyWorkingSets -> pages move to standby
    [void][OTVoidMem]::Run(3)   # MemoryFlushModifiedList -> dirty pages flushed to standby
    $r = [OTVoidMem]::Run(4)    # MemoryPurgeStandbyList  -> standby freed
    Start-Sleep -Milliseconds 500
    $after = [OTVoidMem]::Avail()
    $freed = [math]::Round(($after - $before) / 1MB, 0)
    if ($r -eq 0) { "Freed ~$freed MB (emptied working sets, flushed modified pages, purged standby) - like RAMMap." }
    else { ("Could not purge standby memory - needs an elevated run (status 0x{0:X})." -f $r) }
}

# Delete throwaway files from the temp folders. Locked/in-use files are skipped.
# Reports an approximate amount reclaimed. Safe - only touches %TEMP% and Windows\Temp.
function Clear-TempFiles {
    $freed = 0.0
    foreach ($p in @($env:TEMP, (Join-Path $env:SystemRoot 'Temp'))) {
        if (Test-Path $p) {
            Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                if (-not $_.PSIsContainer) {
                    $sz = $_.Length
                    try { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop; $freed += $sz } catch {}
                }
            }
        }
    }
    "Cleared temp files (~{0} MB reclaimed; in-use files skipped)." -f [math]::Round($freed / 1MB, 0)
}

# A safe, read-only performance snapshot. Changes nothing - just times a bit of CPU
# math, a RAM copy, and a temp-file write/read so you can compare before vs after.
function Invoke-QuickBenchmark {
    $L = New-Object System.Collections.Generic.List[string]
    $L.Add('PC speed check - what it means in plain words (nothing was changed):')
    $L.Add('')

    # CPU: time a chunk of math. Lower time = faster processor.
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $acc = 0.0; for ($i = 0; $i -lt 5000000; $i++) { $acc += [math]::Sqrt($i) }
    $sw.Stop(); $ms = [int]$sw.ElapsedMilliseconds
    $cv = if ($ms -lt 700) { 'Fast - great for gaming and everyday use.' }
          elseif ($ms -lt 1200) { 'Good - handles games and multitasking well.' }
          elseif ($ms -lt 2200) { 'Average - fine for normal use, may struggle in heavy games.' }
          else { 'Slow - older or budget chip; close background apps for best results.' }
    $L.Add('PROCESSOR (CPU)'); $L.Add("  Speed: $cv"); $L.Add('')

    # RAM: how fast memory copies data. Higher MB/s = quicker.
    try {
        $n = 20000000; $a = New-Object byte[] $n; $b = New-Object byte[] $n
        $sw.Restart(); [Array]::Copy($a, $b, $n); $sw.Stop()
        $mbs = [int]($n / 1MB / $sw.Elapsed.TotalSeconds)
        $a = $null; $b = $null
        $rv = if ($mbs -gt 8000) { 'Fast - apps and games load quickly.' }
              elseif ($mbs -gt 5000) { 'Good - no real slowdowns.' }
              elseif ($mbs -gt 3000) { 'Average - enabling XMP/EXPO in BIOS would help.' }
              else { 'Slow - almost certainly running below rated speed; turn on XMP/EXPO.' }
        $L.Add('MEMORY (RAM)'); $L.Add("  Speed: $rv")
    } catch { $L.Add('MEMORY (RAM)'); $L.Add('  Speed: (could not test)') }
    $L.Add('')

    # Disk: write then read a 64 MB file. Tells you SSD vs old hard drive.
    try {
        $tmp = Join-Path $env:TEMP ('ot_bench_' + [guid]::NewGuid().ToString('N') + '.tmp')
        $buf = New-Object byte[] (64MB)
        $sw.Restart(); [System.IO.File]::WriteAllBytes($tmp, $buf); $sw.Stop(); $w = [int](64 / $sw.Elapsed.TotalSeconds)
        $sw.Restart(); [void][System.IO.File]::ReadAllBytes($tmp); $sw.Stop(); $r = [int](64 / $sw.Elapsed.TotalSeconds)
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        $dv = if ($r -gt 1500) { 'Fast SSD (NVMe) - Windows and games load very fast.' }
              elseif ($r -gt 400) { 'SSD (SATA) - good, quick load times.' }
              elseif ($r -gt 120) { 'Slow SSD or a fast hard drive - OK, but an NVMe SSD would help.' }
              else { 'Likely an old hard drive (HDD) - a cheap SSD is the single biggest speed upgrade you can buy.' }
        $L.Add('MAIN DRIVE (storage)'); $L.Add("  Speed: $dv")
    } catch { $L.Add('MAIN DRIVE (storage)'); $L.Add('  Speed: (could not test)') }
    $L.Add('')
    $L.Add('Tip: run this again AFTER turning on XMP/EXPO in BIOS - the Memory result should improve.')
    [GC]::Collect()
    $L -join "`r`n"
}

# Read-only network test: latency (ping) to a few hosts, plus a quick download-speed check.
function Invoke-NetworkTest {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('Network test (read-only):')
    foreach ($h in @('1.1.1.1', '8.8.8.8', 'google.com')) {
        try {
            $r = @(Test-Connection -ComputerName $h -Count 4 -ErrorAction Stop)
            $avg = [math]::Round(($r | Measure-Object -Property ResponseTime -Average).Average, 0)
            $lines.Add("  Ping $h : avg $avg ms  ($($r.Count)/4 replies)")
        } catch { $lines.Add("  Ping $h : no reply") }
    }
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        $url = 'https://speed.cloudflare.com/__down?bytes=10000000'
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $data = (New-Object System.Net.WebClient).DownloadData($url)
        $sw.Stop()
        $mbps = [math]::Round(($data.Length * 8) / 1000000 / $sw.Elapsed.TotalSeconds, 1)
        $lines.Add("  Download: ~$mbps Mbps ($([math]::Round($data.Length / 1MB, 0)) MB in $([math]::Round($sw.Elapsed.TotalSeconds, 1))s via Cloudflare)")
    } catch { $lines.Add("  Download: test skipped ($($_.Exception.Message))") }
    $lines -join "`r`n"
}

# Benchmark DNS resolvers: average resolve time across a few domains, report the fastest.
function Invoke-DnsBenchmark {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('DNS benchmark (avg resolve time, lower is better):')
    $servers = [ordered]@{ 'Cloudflare' = '1.1.1.1'; 'Google' = '8.8.8.8'; 'Quad9' = '9.9.9.9'; 'AdGuard' = '94.140.14.14' }
    $domains = 'google.com', 'youtube.com', 'github.com', 'wikipedia.org', 'amazon.com'
    $best = $null; $bestMs = [double]::MaxValue
    foreach ($name in $servers.Keys) {
        $ip = $servers[$name]; $sw = [System.Diagnostics.Stopwatch]::new(); $ok = 0; $tot = 0.0
        foreach ($d in $domains) {
            try { $sw.Restart(); Resolve-DnsName -Name $d -Server $ip -Type A -DnsOnly -QuickTimeout -ErrorAction Stop | Out-Null; $sw.Stop(); $tot += $sw.Elapsed.TotalMilliseconds; $ok++ } catch {}
        }
        if ($ok -gt 0) { $avg = [math]::Round($tot / $ok, 0); $lines.Add("  $name ($ip): $avg ms  ($ok/$($domains.Count))"); if ($avg -lt $bestMs) { $bestMs = $avg; $best = "$name ($ip)" } }
        else { $lines.Add("  $name ($ip): no response") }
    }
    if ($best) { $lines.Add("  Fastest: $best - set it in Network > 'Use Cloudflare DNS' or on your router.") }
    $lines -join "`r`n"
}
