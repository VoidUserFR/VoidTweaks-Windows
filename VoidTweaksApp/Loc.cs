using System.IO;
using System.Text.Json;

namespace VoidTweaks;

// Tiny localization layer. Strings live in i18n.json (one object per language),
// so the community can translate by editing that file. Falls back to English,
// then to the key itself.
public static class Loc
{
    private static Dictionary<string, Dictionary<string, string>> _data = new();
    private static string _lang = "en";

    public static readonly string[] Available = { "en", "pt", "ru", "fr", "de", "es", "zh", "it", "ja" };
    public static readonly Dictionary<string, string> Names = new()
    {
        ["en"] = "English", ["pt"] = "Português", ["ru"] = "Русский", ["fr"] = "Français",
        ["de"] = "Deutsch", ["es"] = "Español", ["zh"] = "中文", ["it"] = "Italiano", ["ja"] = "日本語"
    };

    public static string Lang
    {
        get => _lang;
        set { _lang = Available.Contains(value) ? value : "en"; try { Directory.CreateDirectory(Path.GetDirectoryName(LangPath)!); File.WriteAllText(LangPath, _lang); } catch { } }
    }

    private static string LangPath => Path.Combine(System.Environment.GetFolderPath(System.Environment.SpecialFolder.LocalApplicationData), "VoidTweaks", "lang.txt");

    public static void Init()
    {
        try
        {
            var p = Path.Combine(AppContext.BaseDirectory, "i18n.json");
            if (File.Exists(p)) _data = JsonSerializer.Deserialize<Dictionary<string, Dictionary<string, string>>>(File.ReadAllText(p)) ?? new();
        }
        catch { }
        try { if (File.Exists(LangPath)) { var l = File.ReadAllText(LangPath).Trim(); if (Available.Contains(l)) _lang = l; } } catch { }
    }

    public static string T(string key, string fallback = "")
    {
        if (_data.TryGetValue(_lang, out var m) && m.TryGetValue(key, out var v) && !string.IsNullOrEmpty(v)) return v;
        if (_data.TryGetValue("en", out var e) && e.TryGetValue(key, out var ev) && !string.IsNullOrEmpty(ev)) return ev;
        return string.IsNullOrEmpty(fallback) ? key : fallback;
    }
}
