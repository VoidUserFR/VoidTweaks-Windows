using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace VoidTweaks;

public class Tweak
{
    [JsonPropertyName("id")] public string Id { get; set; } = "";
    [JsonPropertyName("name")] public string Name { get; set; } = "";
    [JsonPropertyName("category")] public string Category { get; set; } = "";
    [JsonPropertyName("description")] public string Description { get; set; } = "";
    [JsonPropertyName("impact")] public string Impact { get; set; } = "";
    [JsonPropertyName("risk")] public string Risk { get; set; } = "";
    [JsonPropertyName("requiresAdmin")] public bool RequiresAdmin { get; set; }
    [JsonPropertyName("needsRestart")] public bool NeedsRestart { get; set; }
    [JsonPropertyName("reversible")] public bool Reversible { get; set; }
    [JsonPropertyName("apply")] public List<string> Apply { get; set; } = new();
    [JsonPropertyName("revert")] public List<string> Revert { get; set; } = new();
}

public class Catalog
{
    [JsonPropertyName("categories")] public List<string> Categories { get; set; } = new();
    [JsonPropertyName("tweaks")] public List<Tweak> Tweaks { get; set; } = new();
}

public class Preset
{
    [JsonPropertyName("id")] public string Id { get; set; } = "";
    [JsonPropertyName("name")] public string Name { get; set; } = "";
    [JsonPropertyName("description")] public string Description { get; set; } = "";
    [JsonPropertyName("mode")] public string? Mode { get; set; }
    [JsonPropertyName("apply")] public List<string> Apply { get; set; } = new();
}
public class PresetFile { [JsonPropertyName("presets")] public List<Preset> Presets { get; set; } = new(); }

public class StartupRec
{
    public string Id { get; set; } = ""; public string Name { get; set; } = ""; public string Cmd { get; set; } = "";
    public string Source { get; set; } = ""; public string Type { get; set; } = "reg"; public string Hive { get; set; } = "";
    public string? FilePath { get; set; } public string? DisabledPath { get; set; } public bool Admin { get; set; } public bool Enabled { get; set; }
}

public static class Engine
{
    public static readonly HashSet<string> Actions = new(StringComparer.OrdinalIgnoreCase)
    { "clean-temp","clean-windows-temp","net-flush-dns","fix-wu-reset","fix-sfc-dism","fix-network-reset","fix-usb-detect","maint-free-ram",
      "maint-purge-standby","maint-trim-ssd","maint-empty-recyclebin","maint-benchmark","maint-network-test",
      "maint-clear-store-cache","maint-clear-thumbnails","maint-restart-explorer","maint-dns-benchmark" };

    public record AppInfo(string Name, string Id, string Cat);
    public static readonly List<AppInfo> Apps = new()
    {
        // Browsers
        new("Google Chrome", "Google.Chrome", "Browsers"), new("Firefox", "Mozilla.Firefox", "Browsers"),
        new("Brave", "Brave.Brave", "Browsers"), new("Opera GX", "Opera.OperaGX", "Browsers"),
        // Gaming
        new("Steam", "Valve.Steam", "Gaming"), new("Discord", "Discord.Discord", "Gaming"),
        new("Epic Games", "EpicGames.EpicGamesLauncher", "Gaming"), new("Ubisoft Connect", "Ubisoft.Connect", "Gaming"),
        new("GOG Galaxy", "GOG.Galaxy", "Gaming"),
        // Media
        new("VLC", "VideoLAN.VLC", "Media"), new("Spotify", "Spotify.Spotify", "Media"),
        new("OBS Studio", "OBSProject.OBSStudio", "Media"), new("Audacity", "Audacity.Audacity", "Media"),
        // Dev
        new("VS Code", "Microsoft.VisualStudioCode", "Dev"), new("Git", "Git.Git", "Dev"),
        new("Notepad++", "Notepad++.Notepad++", "Dev"), new("Python 3", "Python.Python.3.12", "Dev"),
        new("Windows Terminal", "Microsoft.WindowsTerminal", "Dev"),
        // Utilities
        new("7-Zip", "7zip.7zip", "Utilities"), new("PowerToys", "Microsoft.PowerToys", "Utilities"),
        new("qBittorrent", "qBittorrent.qBittorrent", "Utilities"), new("Everything", "voidtools.Everything", "Utilities"),
        new("ShareX", "ShareX.ShareX", "Utilities"),
    };
    public static string InstallApp(string id) => RunCommands(new[] { $"winget install --id {id} -e --silent --accept-source-agreements --accept-package-agreements" });
    public static string UpdateAllApps() => RunCommands(new[] { "winget upgrade --all --silent --accept-source-agreements --accept-package-agreements" });
    public static string ScheduleMaintenance() => RunCommands(new[] { "schtasks /Create /SC WEEKLY /D SUN /ST 12:00 /F /TN \"VoidTweaks Maintenance\" /TR \"powershell -NoProfile -WindowStyle Hidden -Command \\\"ipconfig /flushdns; Get-ChildItem $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue\\\"\"" });

    public static List<Preset> LoadPresets()
    {
        try { return JsonSerializer.Deserialize<PresetFile>(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "presets.json")))?.Presets ?? new(); }
        catch { return new(); }
    }

    public static bool IsIssue(Tweak t)
    {
        if (t.Id == "fix-wu-service")
            return new[] { "wuauserv", "UsoSvc", "bits" }.Any(n => ReadReg($"HKLM\\SYSTEM\\CurrentControlSet\\Services\\{n}", "Start") == "4");
        if (t.Id == "fix-wu-policy")
            return ReadReg("HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU", "NoAutoUpdate") == "1";
        return false;
    }

    public static string RestorePoint()
        => RunOne("Enable-ComputerRestore -Drive \"$env:SystemDrive\\\" -ErrorAction SilentlyContinue; Checkpoint-Computer -Description 'VoidTweaks' -RestorePointType MODIFY_SETTINGS -ErrorAction SilentlyContinue; 'Restore point requested.'");

    private static string BackupPath => Path.Combine(System.Environment.GetFolderPath(System.Environment.SpecialFolder.LocalApplicationData), "VoidTweaks", "startup-backup.json");
    private static List<StartupRec> LoadBackup() { try { return JsonSerializer.Deserialize<List<StartupRec>>(File.ReadAllText(BackupPath)) ?? new(); } catch { return new(); } }
    private static void SaveBackup(List<StartupRec> r) { try { Directory.CreateDirectory(Path.GetDirectoryName(BackupPath)!); File.WriteAllText(BackupPath, JsonSerializer.Serialize(r)); } catch { } }

    public static List<StartupRec> StartupItems()
    {
        var list = new List<StartupRec>();
        void FromRun(string hive, Microsoft.Win32.RegistryKey root, bool admin)
        {
            try
            {
                using var k = root.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run");
                if (k != null) foreach (var n in k.GetValueNames())
                        list.Add(new StartupRec { Id = $"reg|{hive}|{n}", Name = n, Cmd = k.GetValue(n)?.ToString() ?? "", Source = $"{hive} Run", Type = "reg", Hive = hive, Admin = admin, Enabled = true });
            }
            catch { }
        }
        FromRun("HKCU", Microsoft.Win32.Registry.CurrentUser, false);
        FromRun("HKLM", Microsoft.Win32.Registry.LocalMachine, true);
        foreach (var (folder, src, admin) in new[] {
            (System.Environment.GetFolderPath(System.Environment.SpecialFolder.Startup), "Startup folder", false),
            (System.Environment.GetFolderPath(System.Environment.SpecialFolder.CommonStartup), "All-users Startup", true) })
        {
            try
            {
                foreach (var f in Directory.GetFiles(folder).Where(f => !f.EndsWith("desktop.ini", StringComparison.OrdinalIgnoreCase)))
                    list.Add(new StartupRec { Id = $"file|{src}|{Path.GetFileName(f)}", Name = Path.GetFileNameWithoutExtension(f), Cmd = f, Source = src, Type = "file", FilePath = f, Admin = admin, Enabled = true });
            }
            catch { }
        }
        foreach (var b in LoadBackup()) { b.Enabled = false; list.Add(b); }
        return list.OrderBy(x => x.Enabled ? 0 : 1).ThenBy(x => x.Name).ToList();
    }

    public static void DisableStartup(StartupRec it)
    {
        var bk = LoadBackup();
        if (it.Type == "reg")
        {
            try { var root = it.Hive == "HKLM" ? Microsoft.Win32.Registry.LocalMachine : Microsoft.Win32.Registry.CurrentUser; using var k = root.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", true); k?.DeleteValue(it.Name, false); } catch { }
        }
        else
        {
            try { var dir = Path.Combine(Path.GetDirectoryName(BackupPath)!, "startup-disabled"); Directory.CreateDirectory(dir); var dest = Path.Combine(dir, Path.GetFileName(it.FilePath!)); if (File.Exists(it.FilePath)) File.Move(it.FilePath!, dest, true); it.DisabledPath = dest; } catch { }
        }
        bk.Add(it); SaveBackup(bk);
    }

    public static void EnableStartup(StartupRec it)
    {
        var bk = LoadBackup(); var rec = bk.FirstOrDefault(x => x.Id == it.Id); if (rec == null) return;
        if (rec.Type == "reg")
        {
            try { var root = rec.Hive == "HKLM" ? Microsoft.Win32.Registry.LocalMachine : Microsoft.Win32.Registry.CurrentUser; using var k = root.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", true); k?.SetValue(rec.Name, rec.Cmd); } catch { }
        }
        else if (!string.IsNullOrEmpty(rec.DisabledPath) && File.Exists(rec.DisabledPath))
        {
            try { File.Move(rec.DisabledPath!, rec.FilePath!, true); } catch { }
        }
        bk.RemoveAll(x => x.Id == it.Id); SaveBackup(bk);
    }

    public static Catalog Load()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "tweaks.json");
        var json = File.ReadAllText(path);
        return JsonSerializer.Deserialize<Catalog>(json) ?? new Catalog();
    }

    // Reuse the exact command strings by running them through PowerShell.
    public static string RunCommands(IEnumerable<string> cmds)
    {
        var sb = new StringBuilder();
        foreach (var c in cmds)
        {
            sb.AppendLine("> " + c);
            try
            {
                var psi = new ProcessStartInfo("powershell.exe")
                {
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                };
                psi.ArgumentList.Add("-NoProfile");
                psi.ArgumentList.Add("-ExecutionPolicy");
                psi.ArgumentList.Add("Bypass");
                psi.ArgumentList.Add("-Command");
                psi.ArgumentList.Add(c);
                using var p = Process.Start(psi)!;
                string o = p.StandardOutput.ReadToEnd();
                string e = p.StandardError.ReadToEnd();
                p.WaitForExit();
                if (!string.IsNullOrWhiteSpace(o)) sb.AppendLine("  " + o.Trim());
                if (!string.IsNullOrWhiteSpace(e)) sb.AppendLine("  " + e.Trim());
            }
            catch (Exception ex) { sb.AppendLine("  ERROR: " + ex.Message); }
        }
        return sb.ToString();
    }

    // Basic status detection for registry tweaks: reg add "KEY" /v NAME /t TYPE /d VAL /f
    public static string State(Tweak t)
    {
        if (Actions.Contains(t.Id)) return "action";
        foreach (var c in t.Apply)
        {
            var m = Regex.Match(c, "reg add \"([^\"]+)\" /v (\\S+) /t (\\S+) /d (\\S+) /f");
            if (!m.Success) continue;
            var cur = ReadReg(m.Groups[1].Value, m.Groups[2].Value);
            var want = m.Groups[4].Value;
            if (cur == null) return "default";
            if (long.TryParse(cur, out var a) && long.TryParse(want, out var b)) return a == b ? "applied" : "custom";
            return string.Equals(cur, want, StringComparison.OrdinalIgnoreCase) ? "applied" : "custom";
        }
        // service tweaks: Set-Service -Name X -StartupType Disabled/Automatic/Manual  -> registry Start value
        var joined = string.Join(" ", t.Apply);
        var svc = Regex.Match(joined, @"Set-Service -Name (\w+) -StartupType (\w+)");
        if (svc.Success)
        {
            var start = ReadReg($"HKLM\\SYSTEM\\CurrentControlSet\\Services\\{svc.Groups[1].Value}", "Start");
            if (start != null && int.TryParse(start, out var sv))
            {
                int want = svc.Groups[2].Value switch { "Disabled" => 4, "Automatic" => 2, "Manual" => 3, _ => -1 };
                return sv == want ? "applied" : "default";
            }
        }
        return "na";
    }

    public static readonly HashSet<string> Critical = new(StringComparer.OrdinalIgnoreCase)
    { "system","idle","registry","memcompression","smss","csrss","wininit","winlogon","services","lsass","lsaiso",
      "fontdrvhost","dwm","explorer","svchost","taskhostw","ctfmon","runtimebroker","sihost","shellexperiencehost",
      "startmenuexperiencehost","searchhost","searchindexer","textinputhost","wudfhost","dllhost","conhost","audiodg",
      "spoolsv","rundll32","msmpeng","nissrv","securityhealthservice","securityhealthsystray","lockapp","logonui",
      "smartscreen","applicationframehost","systemsettings","wmiprvse","dashost","sgrmbroker","powershell","pwsh",
      "windowsterminal","voidtweaks","dotnet" };

    public static readonly HashSet<string> Useless = new(StringComparer.OrdinalIgnoreCase)
    { "cortana","searchapp","yourphone","phoneexperiencehost","gamebar","gamebarft","gamebarftserver",
      "gamebarpresencewriter","widgets","widgetservice","onedrive","msteams","teams","skypeapp","feedbackhub",
      "gethelp","clipchamp","mixedrealityportal","peopleexperiencehost" };

    public record ProcInfo(string Name, int Count, long Mem, string Type);

    public static List<ProcInfo> Processes()
    {
        int me = Process.GetCurrentProcess().Id;
        return Process.GetProcesses().Where(p => p.Id != me)
            .GroupBy(p => p.ProcessName)
            .Select(g =>
            {
                long mem = 0;
                foreach (var p in g) { try { mem += p.WorkingSet64; } catch { } }
                string n = g.Key.ToLowerInvariant();
                string type = Critical.Contains(n) ? "system" : Useless.Contains(n) ? "useless" : "other";
                return new ProcInfo(g.Key, g.Count(), mem, type);
            })
            .Where(x => x.Mem > 20L * 1024 * 1024 || x.Type == "useless")
            .OrderByDescending(x => x.Mem).ToList();
    }

    public static string RunOne(string cmd)
    {
        try
        {
            var psi = new ProcessStartInfo("powershell.exe") { RedirectStandardOutput = true, UseShellExecute = false, CreateNoWindow = true };
            psi.ArgumentList.Add("-NoProfile"); psi.ArgumentList.Add("-Command"); psi.ArgumentList.Add(cmd);
            using var p = Process.Start(psi)!;
            var o = p.StandardOutput.ReadToEnd(); p.WaitForExit();
            return o.Trim();
        }
        catch { return ""; }
    }

    public static void EndProcess(string name)
    {
        foreach (var p in Process.GetProcessesByName(name)) { try { p.Kill(); } catch { } }
    }

    public static string Boost(bool admin)
    {
        var actions = Path.Combine(AppContext.BaseDirectory, "OpenTweaks.Actions.ps1");
        var cmds = new List<string>();
        if (File.Exists(actions))
        {
            cmds.Add($". '{actions}'; Optimize-RAM");
            if (admin) cmds.Add($". '{actions}'; Clear-StandbyList");
            cmds.Add($". '{actions}'; Clear-TempFiles");
        }
        cmds.Add("ipconfig /flushdns | Out-Null; 'Flushed the DNS resolver cache.'");
        return RunCommands(cmds);
    }

    private static string ActionsPath => Path.Combine(AppContext.BaseDirectory, "OpenTweaks.Actions.ps1");
    public static string NetInfo()
    {
        var s = "$l=@(); $a=Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1; "
              + "if($a){$l+=\"Adapter : $($a.Name) - $($a.LinkSpeed)\"}; "
              + "$w=netsh wlan show interfaces 2>$null; "
              + "foreach($k in 'SSID','Signal','Radio type','Channel','Receive rate','Transmit rate'){ $m=$w | Select-String (\"^\\s*\"+$k+\"\\s*:\") | Select-Object -First 1; if($m){$l+=(($m.ToString()).Trim())} }; "
              + "if($l.Count -eq 0){$l+='No active adapter found.'}; $l -join \"`r`n\"";
        return RunOne(s);
    }
    public static string NetTest() => File.Exists(ActionsPath) ? RunOne($". '{ActionsPath}'; Invoke-NetworkTest") : "Actions file missing.";
    public static string DnsBench() => File.Exists(ActionsPath) ? RunOne($". '{ActionsPath}'; Invoke-DnsBenchmark") : "Actions file missing.";
    public static string Benchmark() => File.Exists(ActionsPath) ? RunOne($". '{ActionsPath}'; Invoke-QuickBenchmark") : "Actions file missing.";

    // ---- Windows Defender (built-in) deep scanning ----
    public static string DefenderUpdate() => RunOne("try { Update-MpSignature -ErrorAction Stop; 'Virus definitions updated to the latest.' } catch { 'Could not update definitions (need internet / admin): ' + $_.Exception.Message }");
    public static string DefenderScan(string kind)
    {
        // kind = Quick or Full
        var s = "try { "
              + $"Start-MpScan -ScanType {kind}Scan -ErrorAction Stop; "
              + "$t = @(Get-MpThreat | Where-Object { $_.IsActive }); "
              + $"if ($t.Count -gt 0) {{ \"{kind} scan done - {{0}} ACTIVE threat(s) found. Open Windows Security to quarantine/remove.\" -f $t.Count }} "
              + $"else {{ '{kind} scan done - no active threats found. You are clean.' }} "
              + "} catch { 'Scan could not run: ' + $_.Exception.Message }";
        return RunOne(s);
    }
    public static string DefenderOffline() => RunOne("try { Start-MpWDOScan -ErrorAction Stop; 'Offline scan scheduled - your PC will REBOOT shortly and scan before Windows loads.' } catch { 'Could not start offline scan (needs admin): ' + $_.Exception.Message }");

    private static string DataDir => Path.Combine(System.Environment.GetFolderPath(System.Environment.SpecialFolder.LocalApplicationData), "VoidTweaks");
    private static string UserPresetPath => Path.Combine(DataDir, "user-presets.json");
    public static List<Preset> LoadUserPresets()
    {
        try { return JsonSerializer.Deserialize<PresetFile>(File.ReadAllText(UserPresetPath))?.Presets ?? new(); } catch { return new(); }
    }
    public static void SaveUserPresets(List<Preset> list)
    {
        try { Directory.CreateDirectory(DataDir); File.WriteAllText(UserPresetPath, JsonSerializer.Serialize(new PresetFile { Presets = list }, new JsonSerializerOptions { WriteIndented = true })); } catch { }
    }
    public static string ExportProfile(IEnumerable<string> appliedIds, string path)
    {
        try
        {
            var ids = appliedIds.ToList();
            File.WriteAllText(path, JsonSerializer.Serialize(new PresetFile { Presets = new() { new Preset { Name = "Exported profile", Description = "VoidTweaks export", Apply = ids } } }, new JsonSerializerOptions { WriteIndented = true }));
            return $"Exported {ids.Count} tweak(s) to {path}";
        }
        catch (Exception e) { return "Export failed: " + e.Message; }
    }
    public static List<string> ImportProfile(string path)
    {
        try { return JsonSerializer.Deserialize<PresetFile>(File.ReadAllText(path))?.Presets?.FirstOrDefault()?.Apply ?? new(); } catch { return new(); }
    }
    public static string PurgeStandbyElevated()
    {
        if (!File.Exists(ActionsPath)) return "Actions file missing.";
        var tmp = Path.Combine(Path.GetTempPath(), "voidtweaks_purge.txt");
        try { if (File.Exists(tmp)) File.Delete(tmp); } catch { }
        var cmd = $". '{ActionsPath}'; Clear-StandbyList | Out-File -FilePath '{tmp}' -Encoding utf8";
        try
        {
            var psi = new ProcessStartInfo("powershell.exe") { UseShellExecute = true, Verb = "runas", WindowStyle = ProcessWindowStyle.Hidden };
            psi.ArgumentList.Add("-NoProfile"); psi.ArgumentList.Add("-ExecutionPolicy"); psi.ArgumentList.Add("Bypass");
            psi.ArgumentList.Add("-Command"); psi.ArgumentList.Add(cmd);
            using var p = Process.Start(psi)!; p.WaitForExit();
            if (File.Exists(tmp)) return File.ReadAllText(tmp).Trim();
            return "Standby purge ran (elevated).";
        }
        catch (Exception e) { return "Elevated purge cancelled: " + e.Message; }
    }
    private static string DiscordIdPath => Path.Combine(DataDir, "discord.txt");
    public static string GetDiscordId() { try { return File.Exists(DiscordIdPath) ? File.ReadAllText(DiscordIdPath).Trim() : ""; } catch { return ""; } }
    public static void SetDiscordId(string id) { try { Directory.CreateDirectory(DataDir); File.WriteAllText(DiscordIdPath, id.Trim()); } catch { } }

    private static string AccentPath => Path.Combine(DataDir, "accent.txt");
    public static string GetAccent() { try { return File.Exists(AccentPath) ? File.ReadAllText(AccentPath).Trim() : ""; } catch { return ""; } }
    public static void SetAccent(string hex) { try { Directory.CreateDirectory(DataDir); File.WriteAllText(AccentPath, hex.Trim()); } catch { } }

    private static string ThemePath => Path.Combine(DataDir, "theme.txt");
    public static string GetThemeMode() { try { return File.Exists(ThemePath) ? File.ReadAllText(ThemePath).Trim() : ""; } catch { return ""; } }
    public static void SetThemeMode(string m) { try { Directory.CreateDirectory(DataDir); File.WriteAllText(ThemePath, m.Trim()); } catch { } }

    // Returns the latest release tag (e.g. "v2.3") from GitHub, or "" on any failure.
    public static async System.Threading.Tasks.Task<string> LatestVersionTag()
    {
        try
        {
            using var http = new System.Net.Http.HttpClient { Timeout = System.TimeSpan.FromSeconds(8) };
            http.DefaultRequestHeaders.UserAgent.ParseAdd("VoidTweaks-UpdateCheck");
            var json = await http.GetStringAsync("https://api.github.com/repos/VoidUserFR/VoidTweaks-Windows/releases/latest");
            using var doc = JsonDocument.Parse(json);
            return doc.RootElement.GetProperty("tag_name").GetString() ?? "";
        }
        catch { return ""; }
    }

    public static bool FirstRun()
    {
        var marker = Path.Combine(DataDir, "first-run.done");
        if (File.Exists(marker)) return false;
        try { Directory.CreateDirectory(DataDir); File.WriteAllText(marker, System.DateTime.Now.ToString("o")); } catch { }
        return true;
    }
    public static string SpecInfo()
    {
        var s = "$c=Get-CimInstance Win32_Processor | Select-Object -First 1; "
              + "$r=Get-CimInstance Win32_PhysicalMemory; $tot=[math]::Round((($r|Measure-Object Capacity -Sum).Sum)/1GB,0); $spd=($r|Measure-Object Speed -Maximum).Maximum; "
              + "$g=(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -and \"$($_.Status)\" -eq 'OK' -and $_.Name -notmatch 'Meta|Virtual|Basic|Remote' } | Select-Object -First 1).Name; "
              + "$bb=(Get-CimInstance Win32_BaseBoard).Product; "
              + "$o=@(); $o+=\"CPU  : $($c.Name.Trim())\"; $o+=\"       $($c.NumberOfCores) cores / $($c.NumberOfLogicalProcessors) threads, base $([math]::Round($c.MaxClockSpeed/1000,1)) GHz\"; "
              + "$o+=\"GPU  : $g\"; $o+=\"RAM  : $tot GB @ $spd MT/s\"; if($bb){$o+=\"Board: $bb\"}; $o -join \"`r`n\"";
        return RunOne(s);
    }

    private static string? ReadReg(string keyPath, string name)
    {
        try
        {
            int i = keyPath.IndexOf('\\');
            if (i < 0) return null;
            string root = keyPath.Substring(0, i).ToUpperInvariant();
            string sub = keyPath.Substring(i + 1);
            Microsoft.Win32.RegistryKey baseKey = root switch
            {
                "HKLM" or "HKEY_LOCAL_MACHINE" => Microsoft.Win32.Registry.LocalMachine,
                "HKCU" or "HKEY_CURRENT_USER" => Microsoft.Win32.Registry.CurrentUser,
                _ => Microsoft.Win32.Registry.CurrentUser
            };
            using var k = baseKey.OpenSubKey(sub);
            return k?.GetValue(name)?.ToString();
        }
        catch { return null; }
    }
}
