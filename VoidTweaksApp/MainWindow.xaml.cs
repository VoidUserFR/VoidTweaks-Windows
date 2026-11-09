using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;
using System.Windows.Threading;

namespace VoidTweaks;

public partial class MainWindow : Wpf.Ui.Controls.FluentWindow
{
    private readonly Catalog _cat;
    private long _pi, _pk, _pu;
    private string _sel = "";
    private string _search = "";
    private List<string> _undo = new();
    private readonly Dictionary<string, (Border box, TextBlock label)> _nav = new();
    private int _cpuPct, _ramPct;
    private System.Action? _liveHook;
    private DiscordRpc? _rpc;
    private string _appCat = "Browsers";
    private static readonly string[] AppCats = { "Browsers", "Gaming", "Media", "Dev", "Utilities" };
    private static bool _compact;
    private string _netRegion = "Europe";
    private static readonly string[] NetRegions = { "Europe", "Americas", "Asia" };

    private static readonly Dictionary<string, string> IconGeo = new()
    {
        ["All"] = "M4 4h7v7H4z M13 4h7v7h-7z M4 13h7v7H4z M13 13h7v7h-7z",
        ["Needs attention"] = "M12 3 2 20h20z M12 10v4 M12 16.8v0.6",
        ["Presets"] = "M6 3h12v18l-6-4-6 4z",
        ["Startup"] = "M12 3v9 M8 6a7 7 0 1 0 8 0",
        ["Health"] = "M3 12h4l2 5 4-12 2 7h6",
        ["Processes"] = "M4 18V9 M9 18V5 M14 18v-7 M19 18v-4",
        ["Apps"] = "M12 3v10 M8 11l4 4 4-4 M4 19h16",
        ["Settings"] = "M12 8.8a3.2 3.2 0 1 1 0 6.4 3.2 3.2 0 0 1 0-6.4z M12 2v3 M12 19v3 M2 12h3 M19 12h3 M5 5l2 2 M17 17l2 2 M19 5l-2 2 M7 17l-2 2",
        ["Performance"] = "M13 2 4 14h6l-1 8 9-12h-6z",
        ["Gaming"] = "M7 11h4 M9 9v4 M4 16l2-7a3 3 0 0 1 3-2h6a3 3 0 0 1 3 2l2 7a2.5 2.5 0 0 1-4.6 1.3L17 15H7l-.4 1.3A2.5 2.5 0 0 1 4 16z",
        ["Privacy"] = "M12 3 5 6v6c0 4 3 6.5 7 9 4-2.5 7-5 7-9V6z",
        ["Network"] = "M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0z M3 12h18 M12 3c3 3 3 15 0 18 M12 3c-3 3-3 15 0 18",
        ["Visual"] = "M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0z",
        ["Explorer"] = "M3 7h6l2 2h10v10H3z",
        ["Advanced"] = "M4 7h10 M18 7h2 M4 17h2 M10 17h10 M14 4v6 M8 14v6",
        ["Services"] = "M3 4h18v6H3z M3 14h18v6H3z",
        ["AI & Bloat"] = "M7 7h10v10H7z M9 2v3 M15 2v3 M9 19v3 M15 19v3 M2 9h3 M2 15h3 M19 9h3 M19 15h3",
        ["Debloat"] = "M4 7h16 M9 7V5h6v2 M6 7l1 13h10l1-13",
        ["Fixes"] = "M14 7a4 4 0 0 1-5 5l-5 5 2 2 5-5a4 4 0 0 0 5-5z",
        ["Updates"] = "M20 11a8 8 0 1 0-1 5 M20 5v6h-6",
        ["Maintenance"] = "M6 3l3 3-3 3-3-3z M14 6l6 6-3 3-6-6z M14 12 4 22",
        ["Home"] = "M3 11l9-7 9 7 M5 10v9h5v-6h4v6h5v-9",
        ["Networking"] = "M12 19h.01 M8.5 15.5a5 5 0 0 1 7 0 M5 12a10 10 0 0 1 14 0 M2 8.5a15 15 0 0 1 20 0",
        ["Overclock"] = "M12 13a1.6 1.6 0 1 0 0-3.2 1.6 1.6 0 0 0 0 3.2z M12 11.4 16 8 M4 18a9 9 0 1 1 16 0",
        ["Game profiles"] = "M7 11h4 M9 9v4 M4 16l2-7a3 3 0 0 1 3-2h6a3 3 0 0 1 3 2l2 7a2.5 2.5 0 0 1-4.6 1.3L17 15H7l-.4 1.3A2.5 2.5 0 0 1 4 16z",
        ["Cleanup"] = "M12 3l1.6 4 4 1.6-4 1.6L12 14l-1.6-3.8-4-1.6 4-1.6z M6 16l.8 2 2 .8-2 .8L6 22l-.8-2.4-2-.8 2-.8z",
        ["Security"] = "M12 3 5 6v6c0 4 3 6.5 7 9 4-2.5 7-5 7-9V6z M9 12l2 2 4-4",
    };
    private static readonly Dictionary<string, string> CatHex = new()
    {
        ["All"] = "#ECECF1", ["Needs attention"] = "#EF6A60", ["Presets"] = "#8B7CF0", ["Startup"] = "#E5AA3D",
        ["Health"] = "#4CC38A", ["Processes"] = "#9B8CFF", ["Apps"] = "#4CC38A", ["Settings"] = "#9A9AA6", ["Performance"] = "#8B7CF0",
        ["Gaming"] = "#EF6A60", ["Privacy"] = "#4CC38A", ["Network"] = "#5B9BFF", ["Visual"] = "#E5AA3D",
        ["Explorer"] = "#F2C14E", ["Advanced"] = "#B084F5", ["Services"] = "#C98FFF", ["AI & Bloat"] = "#FF8FB1",
        ["Debloat"] = "#9AA0AD", ["Fixes"] = "#5AC8FA", ["Updates"] = "#5B9BFF", ["Maintenance"] = "#5FD0C5",
        ["Home"] = "#35B9AD", ["Networking"] = "#5B9BFF", ["Overclock"] = "#EF6A60", ["Game profiles"] = "#EF6A60",
        ["Cleanup"] = "#5FD0C5", ["Security"] = "#4CC38A",
    };

    public MainWindow()
    {
        InitializeComponent();
        _cat = Engine.Load();
        if (!IsAdmin()) AdminBar.Visibility = Visibility.Visible;
        BuildNav();
        UpdateStatic();
        UpdateLive();
        var timer = new DispatcherTimer { Interval = System.TimeSpan.FromMilliseconds(1500) };
        timer.Tick += (_, _) => UpdateLive();
        timer.Start();
        Log($"VoidTweaks (C# / WPF-UI Fluent) — {_cat.Tweaks.Count} tweaks loaded.");
        Loaded += (_, _) => { if (Engine.FirstRun()) FirstRunTour(); };
        var did = Engine.GetDiscordId();
        if (!string.IsNullOrWhiteSpace(did)) System.Threading.Tasks.Task.Run(() => StartRpc(did));
    }

    private void StartRpc(string id)
    {
        try
        {
            _rpc?.Dispose();
            var r = new DiscordRpc(id);
            if (r.Connect()) { r.SetActivity("Tuning Windows", "Open · reversible · local"); _rpc = r; Dispatcher.Invoke(() => Log("Discord Rich Presence: connected.")); }
            else Dispatcher.Invoke(() => Log("Discord Rich Presence: Discord isn't running or couldn't be reached."));
        }
        catch { }
    }
    private void StopRpc() { try { _rpc?.Dispose(); } catch { } _rpc = null; }
    protected override void OnClosed(System.EventArgs e) { StopRpc(); base.OnClosed(e); }

    private void FirstRunTour()
    {
        System.Windows.MessageBox.Show(this,
            "Welcome to VoidTweaks — open, transparent and fully reversible.\n\n"
          + "• Home  — live CPU/RAM usage + smart recommendations.\n"
          + "• Tweaks are grouped by purpose. Each card glows GREEN when applied, RED when not — just flip the toggle.\n"
          + "• Presets & Game profiles  — apply a curated set in one click (and save your own).\n"
          + "• Networking / Overclock  — test your PC and get advice (no risky auto-changes).\n\n"
          + "Everything can be reverted, and nothing leaves your PC. Tip: keep “Restore point first” ticked.",
            "VoidTweaks — quick tour", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Information);
    }

    // ---------------- navigation ----------------
    private void BuildNav()
    {
        NavPanel.Children.Clear();
        _nav.Clear();
        AddGroup("OVERVIEW");
        foreach (var n in new[] { "Home", "Networking", "Health" }) AddItem(n);
        AddGroup("MENU");
        foreach (var n in new[] { "All", "Needs attention", "Cleanup", "Security", "Presets", "Startup", "Processes" }) AddItem(n);
        AddGroup("INSTALL & TUNE");
        foreach (var n in new[] { "Apps", "Game profiles", "Overclock" }) AddItem(n);
        AddGroup("TWEAKS");
        foreach (var c in _cat.Categories) AddItem(c);
        AddGroup("APP");
        AddItem("Settings");
        Select("Home");
    }

    private void AddGroup(string text) =>
        NavPanel.Children.Add(new TextBlock { Text = text, FontSize = 10, FontWeight = FontWeights.Bold, Opacity = 0.4, Margin = new Thickness(8, 12, 0, 3) });

    private void AddItem(string name)
    {
        var sp = new StackPanel { Orientation = Orientation.Horizontal };
        sp.Children.Add(NavIcon(name));
        var label = new TextBlock { Text = name, VerticalAlignment = VerticalAlignment.Center, FontSize = 13.5 };
        sp.Children.Add(label);
        var box = new Border { CornerRadius = new CornerRadius(8), Padding = new Thickness(11, 9, 11, 9), Margin = new Thickness(0, 1, 0, 1), Background = Brushes.Transparent, Child = sp, Cursor = System.Windows.Input.Cursors.Hand };
        box.MouseLeftButtonUp += (_, _) => Select(name);
        box.MouseEnter += (_, _) => { if (_sel != name) box.Background = new SolidColorBrush(Color.FromArgb(22, 255, 255, 255)); };
        box.MouseLeave += (_, _) => { if (_sel != name) box.Background = Brushes.Transparent; };
        _nav[name] = (box, label);
        NavPanel.Children.Add(box);
    }

    private void Select(string name)
    {
        _sel = name;
        var accent = (Color)ColorConverter.ConvertFromString("#8B7CF0");
        foreach (var kv in _nav)
        {
            bool on = kv.Key == name;
            kv.Value.box.Background = on ? new SolidColorBrush(Color.FromArgb(38, accent.R, accent.G, accent.B)) : Brushes.Transparent;
            kv.Value.label.FontWeight = on ? FontWeights.SemiBold : FontWeights.Normal;
        }
        Render();
    }

    private void SetHeaderIcon(string name)
    {
        if (HeaderIcon == null) return;
        var hex = CatHex.TryGetValue(name, out var h) ? h : "#8B7CF0";
        try { HeaderIcon.Child = new System.Windows.Shapes.Path { Data = Geometry.Parse(IconGeo[name]), Stroke = new SolidColorBrush((Color)ColorConverter.ConvertFromString(hex)), StrokeThickness = 2, StrokeStartLineCap = PenLineCap.Round, StrokeEndLineCap = PenLineCap.Round, StrokeLineJoin = PenLineJoin.Round }; }
        catch { HeaderIcon.Child = null; }
    }

    private void Render()
    {
        _liveHook = null;
        SetHeaderIcon(_sel);
        switch (_sel)
        {
            case "Home": ShowHome(); break;
            case "Networking": ShowNetwork(); break;
            case "Overclock": ShowOverclock(); break;
            case "Game profiles": ShowGameProfiles(); break;
            case "Cleanup": ShowCleanup(); break;
            case "Security": ShowSecurity(); break;
            case "Processes": ShowProcesses(); break;
            case "Apps": ShowApps(); break;
            case "Presets": ShowPresets(); break;
            case "Startup": ShowStartup(); break;
            case "Health": ShowHealth(); break;
            case "Settings": ShowSettings(); break;
            case "All": ShowTweakList("All tweaks", Filter(_cat.Tweaks)); break;
            case "Needs attention": ShowTweakList("Needs attention", _cat.Tweaks.Where(Engine.IsIssue).ToList()); break;
            default: ShowTweakList(_sel, Filter(_cat.Tweaks.Where(t => t.Category == _sel))); break;
        }
    }

    private List<Tweak> Filter(IEnumerable<Tweak> src)
    {
        if (string.IsNullOrWhiteSpace(_search)) return src.ToList();
        var s = _search.ToLowerInvariant();
        return src.Where(t => t.Name.ToLowerInvariant().Contains(s) || t.Description.ToLowerInvariant().Contains(s) || t.Id.ToLowerInvariant().Contains(s)).ToList();
    }

    private List<Tweak> CurrentTweaks() => _sel switch
    {
        "All" => Filter(_cat.Tweaks),
        "Needs attention" => _cat.Tweaks.Where(Engine.IsIssue).ToList(),
        _ when _cat.Categories.Contains(_sel) => Filter(_cat.Tweaks.Where(t => t.Category == _sel)),
        _ => new()
    };

    private void SearchBox_TextChanged(object sender, TextChangedEventArgs e) { _search = SearchBox.Text; if (_sel == "All" || _cat.Categories.Contains(_sel)) Render(); }

    private static FrameworkElement NavIcon(string name)
    {
        var vb = new Viewbox { Width = 18, Height = 18, Margin = new Thickness(0, 0, 11, 0), VerticalAlignment = VerticalAlignment.Center };
        var hex = CatHex.TryGetValue(name, out var h) ? h : "#9A9AA6";
        var brush = new SolidColorBrush((Color)ColorConverter.ConvertFromString(hex));
        try
        {
            vb.Child = new System.Windows.Shapes.Path { Data = Geometry.Parse(IconGeo[name]), Stroke = brush, StrokeThickness = 2, StrokeStartLineCap = PenLineCap.Round, StrokeEndLineCap = PenLineCap.Round, StrokeLineJoin = PenLineJoin.Round };
        }
        catch { vb.Child = new Ellipse { Width = 9, Height = 9, Fill = brush }; }
        return vb;
    }

    // ---------------- tweak list ----------------
    private void ShowTweakList(string title, List<Tweak> items)
    {
        int applied = items.Count(t => Engine.State(t) == "applied");
        HeaderTitle.Text = title;
        HeaderSub.Text = $"{items.Count} tweak(s) · {applied} applied";
        TweakList.Items.Clear();
        if (items.Count == 0) { TweakList.Items.Add(new TextBlock { Text = "Nothing here.", Opacity = 0.5, Margin = new Thickness(2, 12, 0, 0) }); return; }
        foreach (var tw in items) TweakList.Items.Add(BuildCard(tw));
    }

    private Border BuildCard(Tweak tw)
    {
        var state = Engine.State(tw);
        bool toggleable = tw.Reversible && tw.Revert.Count > 0;
        Color glow = state switch
        {
            "applied" => C(0x4C, 0xC3, 0x8A),   // green glow = applied
            "custom" => C(0xE5, 0xAA, 0x3D),
            "action" => C(0x5B, 0x9B, 0xFF),
            "default" => C(0xEF, 0x6A, 0x60),   // red glow = not applied
            _ => C(0x6A, 0x6A, 0x77)
        };

        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var catHex = CatHex.TryGetValue(tw.Category, out var ch) ? ch : "#8B7CF0";
        var cc = (Color)ColorConverter.ConvertFromString(catHex);
        var tile = new Border { Width = 46, Height = 46, CornerRadius = new CornerRadius(12), Background = new SolidColorBrush(Color.FromArgb(38, cc.R, cc.G, cc.B)), Margin = new Thickness(0, 1, 16, 0), VerticalAlignment = VerticalAlignment.Top, Child = IconFor(tw.Category, 24) };
        Grid.SetColumn(tile, 0); grid.Children.Add(tile);

        var left = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        left.Children.Add(new TextBlock { Text = tw.Name, FontSize = 16.5, FontWeight = FontWeights.SemiBold });
        left.Children.Add(new TextBlock { Text = tw.Description, Opacity = 0.62, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 7, 14, 0), FontSize = 12.5 });
        var tags = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 9, 0, 0) };
        tags.Children.Add(Badge(tw.Risk + " risk", RiskColor(tw.Risk)));
        if (tw.RequiresAdmin) tags.Children.Add(Badge("ADMIN", C(0xE5, 0xAA, 0x3D)));
        if (tw.NeedsRestart) tags.Children.Add(Badge("REBOOT", C(0x5B, 0x9B, 0xFF)));
        left.Children.Add(tags);
        Grid.SetColumn(left, 1); grid.Children.Add(left);

        var right = new StackPanel { VerticalAlignment = VerticalAlignment.Center, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(14, 0, 0, 0) };
        right.Children.Add(Pill(state));
        if (toggleable)
        {
            var ts = new Wpf.Ui.Controls.ToggleSwitch { IsChecked = state == "applied", Margin = new Thickness(0, 12, 0, 0), HorizontalAlignment = HorizontalAlignment.Right };
            if (tw.RequiresAdmin && !IsAdmin()) { ts.IsEnabled = false; ts.ToolTip = "Needs administrator"; }
            bool init = true;
            ts.Checked += (_, _) => { if (init) return; if (_busy) { Log("Busy — wait for the current action to finish."); Render(); return; } RunMany(new[] { tw }, false, "apply: " + tw.Name); };
            ts.Unchecked += (_, _) => { if (init) return; if (_busy) { Log("Busy — wait for the current action to finish."); Render(); return; } RunMany(new[] { tw }, true, "revert: " + tw.Name); };
            init = false;
            right.Children.Add(ts);
        }
        else
        {
            var apply = new Wpf.Ui.Controls.Button { Content = "Apply", Appearance = Wpf.Ui.Controls.ControlAppearance.Primary, Width = 92, Margin = new Thickness(0, 12, 0, 0), HorizontalAlignment = HorizontalAlignment.Right };
            if (tw.RequiresAdmin && !IsAdmin()) { apply.IsEnabled = false; apply.ToolTip = "Needs administrator"; }
            apply.Click += (_, _) => { apply.Content = "Running…"; apply.IsEnabled = false; RunMany(new[] { tw }, false, "run: " + tw.Name); };
            right.Children.Add(apply);
        }
        Grid.SetColumn(right, 2); grid.Children.Add(right);

        return GlowCard(grid, glow);
    }

    private static FrameworkElement IconFor(string name, double size)
    {
        var vb = new Viewbox { Width = size, Height = size, VerticalAlignment = VerticalAlignment.Center, HorizontalAlignment = HorizontalAlignment.Center };
        var hex = CatHex.TryGetValue(name, out var h) ? h : "#9A9AA6";
        var brush = new SolidColorBrush((Color)ColorConverter.ConvertFromString(hex));
        try { vb.Child = new System.Windows.Shapes.Path { Data = Geometry.Parse(IconGeo[name]), Stroke = brush, StrokeThickness = 2, StrokeStartLineCap = PenLineCap.Round, StrokeEndLineCap = PenLineCap.Round, StrokeLineJoin = PenLineJoin.Round }; }
        catch { vb.Child = new Ellipse { Width = 10, Height = 10, Fill = brush }; }
        return vb;
    }

    private static Border GlowCard(UIElement child, Color glow)
    {
        var baseBg = Color.FromArgb(30, 255, 255, 255);
        var hoverBg = Color.FromArgb(48, 255, 255, 255);
        var b = new Border
        {
            Background = new SolidColorBrush(baseBg),
            BorderBrush = new SolidColorBrush(Color.FromArgb(150, glow.R, glow.G, glow.B)),
            BorderThickness = new Thickness(1.3),
            CornerRadius = new CornerRadius(14),
            Padding = new Thickness(_compact ? 13 : 18),
            Margin = new Thickness(0, 0, 0, _compact ? 9 : 13),
            Child = child,
            Effect = new System.Windows.Media.Effects.DropShadowEffect { Color = glow, BlurRadius = 18, ShadowDepth = 0, Opacity = 0.5 }
        };
        b.MouseEnter += (_, _) => b.Background = new SolidColorBrush(hoverBg);
        b.MouseLeave += (_, _) => b.Background = new SolidColorBrush(baseBg);
        return b;
    }

    // ---------------- home ----------------
    private void ShowHome()
    {
        HeaderTitle.Text = "Home";
        HeaderSub.Text = "Live system usage and what's worth doing next";
        TweakList.Items.Clear();

        var row = new Grid { Margin = new Thickness(0, 0, 0, 2) };
        for (int i = 0; i < 3; i++) row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        var cpuCard = GaugeCard("CPU", out var cpuBar, out var cpuTxt); cpuCard.Margin = new Thickness(0, 0, 10, 0);
        var ramCard = GaugeCard("MEMORY", out var ramBar, out var ramTxt); ramCard.Margin = new Thickness(0, 0, 10, 0);
        var gpuCard = InfoCard("GPU", GpuText.Text);
        Grid.SetColumn(cpuCard, 0); Grid.SetColumn(ramCard, 1); Grid.SetColumn(gpuCard, 2);
        row.Children.Add(cpuCard); row.Children.Add(ramCard); row.Children.Add(gpuCard);
        TweakList.Items.Add(row);

        _liveHook = () =>
        {
            cpuBar.Value = _cpuPct; cpuTxt.Text = _cpuPct + "%"; cpuBar.Foreground = UsageGrad(_cpuPct);
            ramBar.Value = _ramPct; ramTxt.Text = _ramPct + "%"; ramBar.Foreground = UsageGrad(_ramPct);
        };
        _liveHook();

        var recs = BuildRecommendations();
        var panel = new StackPanel { Margin = new Thickness(0, 12, 0, 0) };
        panel.Children.Add(new TextBlock { Text = "Recommendations", FontSize = 16.5, FontWeight = FontWeights.SemiBold, Margin = new Thickness(2, 0, 0, 10) });
        if (recs.Count == 0) panel.Children.Add(new TextBlock { Text = "All good — nothing urgent right now. Nice.", Opacity = 0.6, Margin = new Thickness(2, 0, 0, 0) });
        foreach (var r in recs) panel.Children.Add(RecCard(r));
        TweakList.Items.Add(panel);
    }

    private record Rec(string Title, string Detail, string Go, Color Col);
    private List<Rec> BuildRecommendations()
    {
        var l = new List<Rec>();
        int issues = _cat.Tweaks.Count(Engine.IsIssue);
        if (issues > 0) l.Add(new Rec($"{issues} tweak(s) need attention", "Recommended tweaks aren't applied yet.", "Needs attention", C(0xEF, 0x6A, 0x60)));
        if (_cat.Tweaks.Count(t => Engine.State(t) == "applied") == 0) l.Add(new Rec("No tweaks applied yet", "Pick a preset (Gaming / Performance) to start fast.", "Presets", C(0x8B, 0x7C, 0xF0)));
        if (_ramPct >= 85) l.Add(new Rec("Memory is under pressure", $"RAM at {_ramPct}%. Hit ⚡ Boost to free standby + working sets.", "", C(0xE5, 0xAA, 0x3D)));
        bool wuBad = _cat.Tweaks.Any(t => (t.Id == "fix-wu-service" || t.Id == "fix-wu-policy") && Engine.IsIssue(t));
        if (wuBad) l.Add(new Rec("Windows Update blocked", "A service or policy is stopping updates — see Fixes.", "Fixes", C(0xEF, 0x6A, 0x60)));
        try { int su = Engine.StartupItems().Count(i => i.Enabled); if (su > 8) l.Add(new Rec($"{su} startup apps", "Lots of apps launch at boot — trim them.", "Startup", C(0xE5, 0xAA, 0x3D))); } catch { }
        try { int uz = Engine.Processes().Count(p => p.Type == "useless"); if (uz > 0) l.Add(new Rec($"{uz} useless process(es)", "Background hogs you can safely end.", "Processes", C(0x5B, 0x9B, 0xFF))); } catch { }
        return l;
    }
    private Border RecCard(Rec r)
    {
        var grid = TwoCol();
        var left = new StackPanel();
        var head = new StackPanel { Orientation = Orientation.Horizontal };
        head.Children.Add(new Border { Width = 9, Height = 9, CornerRadius = new CornerRadius(5), Background = new SolidColorBrush(r.Col), Margin = new Thickness(0, 0, 9, 0), VerticalAlignment = VerticalAlignment.Center });
        head.Children.Add(new TextBlock { Text = r.Title, FontSize = 14.5, FontWeight = FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center });
        left.Children.Add(head);
        left.Children.Add(new TextBlock { Text = r.Detail, Opacity = 0.62, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(18, 6, 14, 0), FontSize = 12.5 });
        Grid.SetColumn(left, 0); grid.Children.Add(left);
        if (!string.IsNullOrEmpty(r.Go))
        {
            var b = new Wpf.Ui.Controls.Button { Content = "Open →", Appearance = Wpf.Ui.Controls.ControlAppearance.Secondary, VerticalAlignment = VerticalAlignment.Center };
            var go = r.Go; b.Click += (_, _) => Select(go);
            Grid.SetColumn(b, 1); grid.Children.Add(b);
        }
        return Card(grid);
    }
    private Border GaugeCard(string label, out ProgressBar bar, out TextBlock val)
    {
        var sp = new StackPanel();
        sp.Children.Add(new TextBlock { Text = label, FontSize = 11, FontWeight = FontWeights.SemiBold, Opacity = 0.55 });
        val = new TextBlock { Text = "—", FontSize = 30, FontWeight = FontWeights.Bold, Margin = new Thickness(0, 3, 0, 9) };
        sp.Children.Add(val);
        bar = new ProgressBar { Minimum = 0, Maximum = 100, Height = 10, Value = 0 };
        sp.Children.Add(bar);
        return Card(sp);
    }
    private static Border InfoCard(string label, string value)
    {
        var sp = new StackPanel();
        sp.Children.Add(new TextBlock { Text = label, FontSize = 11, FontWeight = FontWeights.SemiBold, Opacity = 0.55 });
        sp.Children.Add(new TextBlock { Text = string.IsNullOrWhiteSpace(value) ? "—" : value, FontSize = 14, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 10, 0, 0), TextWrapping = TextWrapping.Wrap });
        return Card(sp);
    }
    private static LinearGradientBrush UsageGrad(int p) => p >= 85 ? Grad("#EF6A60", "#E5AA3D") : p >= 65 ? Grad("#E5AA3D", "#8B7CF0") : Grad("#35B9AD", "#8B7CF0");

    // ---------------- networking ----------------
    private void ShowNetwork()
    {
        HeaderTitle.Text = "Networking";
        HeaderSub.Text = "Test your connection, benchmark DNS, then apply the right tweaks";
        TweakList.Items.Clear();

        var info = Section("Your connection", "Live adapter and Wi‑Fi link details.");
        var infoTxt = new TextBlock { Text = "Reading…", Opacity = 0.72, FontSize = 12.5, TextWrapping = TextWrapping.Wrap, FontFamily = new FontFamily("Cascadia Mono, Consolas") };
        info.Children.Add(infoTxt);
        TweakList.Items.Add(Card(info));
        RunAsync(Engine.NetInfo, infoTxt);

        var test = Section("Connection test", "Ping + download speed (Cloudflare) and a DNS resolver benchmark. Read‑only — changes nothing.");
        var btns = new StackPanel { Orientation = Orientation.Horizontal };
        var resTxt = new TextBlock { Text = "", Opacity = 0.82, FontSize = 12.5, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 11, 0, 0), FontFamily = new FontFamily("Cascadia Mono, Consolas") };
        var b1 = Btn("Run speed + ping", () => RunAsync(Engine.NetTest, resTxt)); b1.Appearance = Wpf.Ui.Controls.ControlAppearance.Primary; b1.Margin = new Thickness(0, 0, 8, 0);
        var b2 = Btn("DNS benchmark", () => RunAsync(Engine.DnsBench, resTxt));
        btns.Children.Add(b1); btns.Children.Add(b2);
        test.Children.Add(btns); test.Children.Add(resTxt);
        TweakList.Items.Add(Card(test));

        var (title, sub, tips) = RegionAdvice(_netRegion);
        var rec = Section(title, sub);
        var regrow = new WrapPanel { Margin = new Thickness(0, 0, 0, 10) };
        foreach (var r in NetRegions)
        {
            bool on = r == _netRegion;
            var rb = new Wpf.Ui.Controls.Button { Content = r, Appearance = on ? Wpf.Ui.Controls.ControlAppearance.Primary : Wpf.Ui.Controls.ControlAppearance.Secondary, Margin = new Thickness(0, 0, 8, 0) };
            var rr = r; rb.Click += (_, _) => { _netRegion = rr; ShowNetwork(); };
            regrow.Children.Add(rb);
        }
        rec.Children.Add(regrow);
        foreach (var s in tips) rec.Children.Add(new TextBlock { Text = s, Opacity = 0.72, TextWrapping = TextWrapping.Wrap, FontSize = 12.5, Margin = new Thickness(0, 0, 0, 8) });
        var go = Btn("Open Network tweaks →", () => Select("Network")); go.Appearance = Wpf.Ui.Controls.ControlAppearance.Secondary;
        rec.Children.Add(go);
        TweakList.Items.Add(Card(rec));
    }

    private static (string title, string sub, string[] tips) RegionAdvice(string region) => region switch
    {
        "Americas" => ("Best settings — Americas", "US · Canada · LATAM (Comcast · Spectrum · AT&T · Claro…).", new[]
        {
            "•  DNS:  Cloudflare 1.1.1.1 and Google 8.8.8.8 are both widely peered across North & South America — benchmark to see which wins on your line. Quad9 9.9.9.9 adds malware filtering.",
            "•  Wi‑Fi band:  prefer 5 GHz (channels 36 / 40 / 44 / 48). In the US/Canada 2.4 GHz is limited to channels 1–11 — stick to 1, 6 or 11.",
            "•  Router:  enable WPA3 (or WPA2‑AES), update firmware, disable 'band steering' if devices drop to 2.4 GHz.",
            "•  Latency:  apply the Network tweaks (Nagle off, TCP auto‑tuning normal, DNS cache) for lower ping to NA / LATAM servers."
        }),
        "Asia" => ("Best settings — Asia", "JP · KR · SG · IN · SEA (NTT · SK · Singtel · Jio…).", new[]
        {
            "•  DNS:  Cloudflare 1.1.1.1 has strong presence in Singapore, Tokyo & Hong Kong; Google 8.8.8.8 is a solid backup. In some countries your ISP's own resolver is fastest — run the benchmark to be sure.",
            "•  Wi‑Fi band:  prefer 5 GHz (channels 36 / 40 / 44 / 48). 2.4 GHz allows channels 1–13 in most of Asia — use 1, 6 or 11 to avoid overlap.",
            "•  Router:  enable WPA3 (or WPA2‑AES), keep firmware updated, disable 'band steering' if needed.",
            "•  Latency:  apply the Network tweaks for lower ping — a nearby city server usually beats a 'global' one."
        }),
        _ => ("Best settings — Europe / Portugal", "PT · EU (MEO · NOS · Vodafone…).", new[]
        {
            "•  DNS:  Cloudflare 1.1.1.1 / 1.0.0.1 — strong peering in Lisbon & Porto, usually the lowest latency here. Quad9 9.9.9.9 if you want malware filtering. Run the benchmark to confirm the fastest on your line.",
            "•  Wi‑Fi band:  prefer 5 GHz for speed (channels 36 / 40 / 44 / 48). Keep 2.4 GHz on channel 1, 6 or 11 only — longer range but slower and crowded.",
            "•  Router:  enable WPA3 (or WPA2‑AES), keep firmware updated, and turn off 'band steering' if devices keep dropping to 2.4 GHz.",
            "•  Latency:  apply the Network tweaks (disable Nagle, TCP auto‑tuning = normal, DNS cache on) for lower in‑game ping."
        }),
    };

    private void RunAsync(System.Func<string> work, TextBlock target)
    {
        target.Text = "Running…";
        System.Threading.Tasks.Task.Run(() =>
        {
            string r; try { r = work(); } catch (System.Exception ex) { r = "Error: " + ex.Message; }
            Dispatcher.Invoke(() => { target.Text = string.IsNullOrWhiteSpace(r) ? "(no output)" : r; Log(r); });
        });
    }

    // ---------------- presets ----------------
    private void ShowPresets()
    {
        HeaderTitle.Text = "Presets";
        int appliedN = _cat.Tweaks.Count(t => Engine.State(t) == "applied");
        HeaderSub.Text = $"You currently have {appliedN} tweak(s) applied.";
        TweakList.Items.Clear();

        // toolbar: save current / export / import
        var tools = Section("Your profile", "Save the tweaks you have applied now as a reusable preset, or back it up to a file.");
        var trow = new WrapPanel();
        var save = Btn("Save current as preset…", SaveCurrentPreset); save.Appearance = Wpf.Ui.Controls.ControlAppearance.Primary; save.Margin = new Thickness(0, 0, 8, 6);
        var exp = Btn("Export…", ExportProfile); exp.Margin = new Thickness(0, 0, 8, 6);
        var imp = Btn("Import…", ImportProfile);
        trow.Children.Add(save); trow.Children.Add(exp); trow.Children.Add(imp);
        tools.Children.Add(trow);
        TweakList.Items.Add(Card(tools));

        var user = Engine.LoadUserPresets();
        foreach (var p in Engine.LoadPresets()) TweakList.Items.Add(PresetCard(p, false));
        if (user.Count > 0)
        {
            TweakList.Items.Add(new TextBlock { Text = "YOUR PRESETS", FontSize = 10, FontWeight = FontWeights.Bold, Opacity = 0.4, Margin = new Thickness(2, 10, 0, 6) });
            foreach (var p in user) TweakList.Items.Add(PresetCard(p, true));
        }
    }

    private Border PresetCard(Preset p, bool editable)
    {
        var pp = p;
        var grid = TwoCol();
        var left = new StackPanel();
        left.Children.Add(new TextBlock { Text = p.Name, FontSize = 15, FontWeight = FontWeights.SemiBold });
        if (!string.IsNullOrWhiteSpace(p.Description))
            left.Children.Add(new TextBlock { Text = p.Description, Opacity = 0.65, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 7, 14, 0), FontSize = 12.5 });
        if (p.Mode != "revert-all" && p.Apply.Count > 0)
        {
            int ap = p.Apply.Count(id => _cat.Tweaks.FirstOrDefault(t => t.Id == id) is { } t && Engine.State(t) == "applied");
            left.Children.Add(new TextBlock { Text = ap == p.Apply.Count ? "● Active — all applied" : $"{ap} / {p.Apply.Count} applied", Foreground = new SolidColorBrush(ap == p.Apply.Count ? C(0x4C, 0xC3, 0x8A) : C(0x9A, 0x9A, 0xA6)), FontSize = 12, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 8, 0, 0) });
        }
        Grid.SetColumn(left, 0); grid.Children.Add(left);

        var right = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        var apply = new Wpf.Ui.Controls.Button { Content = "Apply", Appearance = Wpf.Ui.Controls.ControlAppearance.Primary, Width = 92, HorizontalAlignment = HorizontalAlignment.Right };
        apply.Click += (_, _) => ApplyPreset(pp);
        right.Children.Add(apply);
        if (editable)
        {
            var erow = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 8, 0, 0), HorizontalAlignment = HorizontalAlignment.Right };
            var ren = new Wpf.Ui.Controls.Button { Content = "Rename", Appearance = Wpf.Ui.Controls.ControlAppearance.Secondary, Margin = new Thickness(0, 0, 8, 0) };
            ren.Click += (_, _) => RenamePreset(pp);
            var del = new Wpf.Ui.Controls.Button { Content = "Delete", Appearance = Wpf.Ui.Controls.ControlAppearance.Danger };
            del.Click += (_, _) => DeletePreset(pp);
            erow.Children.Add(ren); erow.Children.Add(del);
            right.Children.Add(erow);
        }
        Grid.SetColumn(right, 1); grid.Children.Add(right);
        return Card(grid);
    }

    private void SaveCurrentPreset()
    {
        var ids = _cat.Tweaks.Where(t => Engine.State(t) == "applied").Select(t => t.Id).ToList();
        if (ids.Count == 0) { Log("Nothing applied to save."); return; }
        var name = Prompt("Name this preset", $"My preset ({System.DateTime.Now:MMM d})");
        if (string.IsNullOrWhiteSpace(name)) return;
        var list = Engine.LoadUserPresets();
        list.RemoveAll(x => x.Name == name);
        list.Add(new Preset { Name = name, Description = $"{ids.Count} tweak(s), saved {System.DateTime.Now:MMM d, HH:mm}", Apply = ids });
        Engine.SaveUserPresets(list);
        Log($"Saved preset '{name}' ({ids.Count} tweaks).");
        ShowPresets();
    }
    private void RenamePreset(Preset p)
    {
        var name = Prompt("Rename preset", p.Name);
        if (string.IsNullOrWhiteSpace(name) || name == p.Name) return;
        var list = Engine.LoadUserPresets();
        var m = list.FirstOrDefault(x => x.Name == p.Name); if (m != null) m.Name = name;
        Engine.SaveUserPresets(list); ShowPresets();
    }
    private void DeletePreset(Preset p)
    {
        if (System.Windows.MessageBox.Show(this, $"Delete preset '{p.Name}'?", "VoidTweaks", System.Windows.MessageBoxButton.YesNo, System.Windows.MessageBoxImage.Question) != System.Windows.MessageBoxResult.Yes) return;
        var list = Engine.LoadUserPresets(); list.RemoveAll(x => x.Name == p.Name);
        Engine.SaveUserPresets(list); Log($"Deleted preset '{p.Name}'."); ShowPresets();
    }
    private void ExportProfile()
    {
        var dlg = new Microsoft.Win32.SaveFileDialog { FileName = "voidtweaks-profile.json", Filter = "JSON profile (*.json)|*.json", DefaultExt = ".json" };
        if (dlg.ShowDialog(this) != true) return;
        var ids = _cat.Tweaks.Where(t => Engine.State(t) == "applied").Select(t => t.Id);
        Log(Engine.ExportProfile(ids, dlg.FileName));
    }
    private void ImportProfile()
    {
        var dlg = new Microsoft.Win32.OpenFileDialog { Filter = "JSON profile (*.json)|*.json", DefaultExt = ".json" };
        if (dlg.ShowDialog(this) != true) return;
        var ids = Engine.ImportProfile(dlg.FileName);
        if (ids.Count == 0) { Log("Import: no tweaks found in that file."); return; }
        var set = _cat.Tweaks.Where(t => ids.Contains(t.Id));
        RunMany(set, false, "import profile");
    }

    private string? Prompt(string title, string def = "")
    {
        var win = new Window { Title = "VoidTweaks", Width = 400, Height = 168, WindowStartupLocation = WindowStartupLocation.CenterOwner, ResizeMode = ResizeMode.NoResize, WindowStyle = WindowStyle.ToolWindow, Owner = this };
        var sp = new StackPanel { Margin = new Thickness(18) };
        sp.Children.Add(new TextBlock { Text = title, Margin = new Thickness(0, 0, 0, 9), FontSize = 13.5 });
        var tb = new System.Windows.Controls.TextBox { Text = def, Margin = new Thickness(0, 0, 0, 14), FontSize = 13, Padding = new Thickness(6, 4, 6, 4) };
        tb.SelectAll();
        var row = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
        var ok = new System.Windows.Controls.Button { Content = "OK", Width = 76, Margin = new Thickness(0, 0, 8, 0), IsDefault = true };
        var cancel = new System.Windows.Controls.Button { Content = "Cancel", Width = 76, IsCancel = true };
        row.Children.Add(ok); row.Children.Add(cancel);
        sp.Children.Add(tb); sp.Children.Add(row);
        win.Content = sp;
        string? result = null;
        ok.Click += (_, _) => { result = tb.Text; win.DialogResult = true; };
        tb.Focus();
        return win.ShowDialog() == true ? result : null;
    }

    private void ApplyPreset(Preset p)
    {
        if (p.Mode == "revert-all") { RunMany(_cat.Tweaks.Where(t => t.Reversible && t.Revert.Count > 0), true, "preset: " + p.Name); return; }
        RunMany(_cat.Tweaks.Where(t => p.Apply.Contains(t.Id)), false, "preset: " + p.Name);
    }

    // ---------------- startup ----------------
    private void ShowStartup()
    {
        var items = Engine.StartupItems();
        HeaderTitle.Text = "Startup apps";
        HeaderSub.Text = $"{items.Count} item(s), {items.Count(i => i.Enabled)} enabled — disabling is reversible";
        TweakList.Items.Clear();
        foreach (var it in items)
        {
            var rec = it;
            var grid = TwoCol();
            var left = new StackPanel();
            var row = new StackPanel { Orientation = Orientation.Horizontal };
            row.Children.Add(new TextBlock { Text = it.Name, FontSize = 15, FontWeight = FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 10, 0) });
            row.Children.Add(Badge(it.Source, C(0x5B, 0x9B, 0xFF)));
            if (it.Admin) row.Children.Add(Badge("ADMIN", C(0xE5, 0xAA, 0x3D)));
            left.Children.Add(row);
            left.Children.Add(new TextBlock { Text = it.Cmd, Opacity = 0.55, TextWrapping = TextWrapping.Wrap, MaxHeight = 32, Margin = new Thickness(0, 7, 14, 0), FontSize = 11.5 });
            Grid.SetColumn(left, 0); grid.Children.Add(left);
            var right = new StackPanel { HorizontalAlignment = HorizontalAlignment.Right };
            right.Children.Add(PillBox(it.Enabled ? "Enabled" : "Disabled", it.Enabled ? C(0x4C, 0xC3, 0x8A) : C(0x9A, 0x9A, 0xA6)));
            var btn = new Wpf.Ui.Controls.Button { Content = it.Enabled ? "Disable" : "Enable", Appearance = it.Enabled ? Wpf.Ui.Controls.ControlAppearance.Secondary : Wpf.Ui.Controls.ControlAppearance.Success, Width = 90, Margin = new Thickness(0, 11, 0, 0), HorizontalAlignment = HorizontalAlignment.Right };
            if (it.Admin && !IsAdmin()) { btn.IsEnabled = false; btn.ToolTip = "Needs administrator"; }
            btn.Click += (_, _) => { if (rec.Enabled) Engine.DisableStartup(rec); else Engine.EnableStartup(rec); Log($"Startup: {(rec.Enabled ? "disabled" : "enabled")} '{rec.Name}'."); ShowStartup(); };
            right.Children.Add(btn);
            Grid.SetColumn(right, 1); grid.Children.Add(right);
            TweakList.Items.Add(Card(grid));
        }
    }

    // ---------------- health ----------------
    private void ShowHealth()
    {
        HeaderTitle.Text = "Health check";
        HeaderSub.Text = "Your system, and what's worth looking at";
        TweakList.Items.Clear();
        var specs = new StackPanel();
        specs.Children.Add(new TextBlock { Text = "Your system", FontSize = 15, FontWeight = FontWeights.SemiBold });
        var cpu = Engine.RunOne("(Get-CimInstance Win32_Processor | Select-Object -First 1).Name");
        var media = Engine.RunOne("(Get-Partition -DriveLetter ($env:SystemDrive[0]) | Get-Disk | Get-PhysicalDisk).MediaType");
        specs.Children.Add(new TextBlock { Text = $"{cpu}\n{GpuText.Text}  ·  {OsText.Text}\nSystem drive: {media}\n{DiskText.Text}", Opacity = 0.7, Margin = new Thickness(0, 7, 0, 0), FontSize = 12.5 });
        TweakList.Items.Add(Card(specs));

        void Check(string title, bool bad, string detail) =>
            TweakList.Items.Add(Card(Row(PillBox(bad ? "Attention" : "OK", bad ? C(0xE5, 0xAA, 0x3D) : C(0x4C, 0xC3, 0x8A)), title, detail)));

        bool wuBad = _cat.Tweaks.Any(t => (t.Id == "fix-wu-service" || t.Id == "fix-wu-policy") && Engine.IsIssue(t));
        Check("Windows Update", wuBad, wuBad ? "A service or policy is blocking updates — see Fixes." : "Update services look healthy.");
        int startupN = Engine.StartupItems().Count(i => i.Enabled);
        Check("Startup apps", startupN > 8, $"{startupN} apps launch at boot.");
        bool hdd = media.Equals("HDD", StringComparison.OrdinalIgnoreCase);
        if (hdd) Check("Hard drive (HDD)", true, "On an HDD, keep SysMain on. An SSD is the biggest speed-up.");
    }

    private static Border Row(UIElement pill, string title, string detail)
    {
        var sp = new StackPanel();
        var r = new StackPanel { Orientation = Orientation.Horizontal };
        if (pill is FrameworkElement fe) fe.Margin = new Thickness(0, 0, 10, 0);
        r.Children.Add(pill);
        r.Children.Add(new TextBlock { Text = title, FontSize = 15, FontWeight = FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center });
        sp.Children.Add(r);
        sp.Children.Add(new TextBlock { Text = detail, Opacity = 0.65, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 7, 0, 0), FontSize = 12.5 });
        return sp.Children.Count == 0 ? new Border() : WrapCard(sp);
    }
    private static Border WrapCard(UIElement e) => Card(e);

    // ---------------- settings ----------------
    private static StackPanel Section(string title, string desc)
    {
        var sp = new StackPanel();
        sp.Children.Add(new TextBlock { Text = title, FontSize = 15, FontWeight = FontWeights.SemiBold });
        sp.Children.Add(new TextBlock { Text = desc, Opacity = 0.65, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 6, 0, 10), FontSize = 12.5 });
        return sp;
    }
    private static Wpf.Ui.Controls.Button Btn(string text, System.Action onClick)
    {
        var b = new Wpf.Ui.Controls.Button { Content = text };
        b.Click += (_, _) => onClick();
        return b;
    }

    private void ShowSettings()
    {
        HeaderTitle.Text = "Settings";
        HeaderSub.Text = "Appearance — make it yours";
        TweakList.Items.Clear();

        var t = Section("Theme", "Dark or light base.");
        var trow = new StackPanel { Orientation = Orientation.Horizontal };
        var dark = Btn("Dark", () => Wpf.Ui.Appearance.ApplicationThemeManager.Apply(Wpf.Ui.Appearance.ApplicationTheme.Dark)); dark.Width = 100; dark.Margin = new Thickness(0, 0, 8, 0);
        var light = Btn("Light", () => Wpf.Ui.Appearance.ApplicationThemeManager.Apply(Wpf.Ui.Appearance.ApplicationTheme.Light)); light.Width = 100;
        trow.Children.Add(dark); trow.Children.Add(light); t.Children.Add(trow);
        TweakList.Items.Add(Card(t));

        var a = Section("Accent colour", "Pick the highlight colour used across the app.");
        var arow = new StackPanel { Orientation = Orientation.Horizontal };
        foreach (var hex in new[] { "#8B7CF0", "#5B9BFF", "#35B9AD", "#4CC38A", "#E5AA3D", "#EF6A60", "#FF8FB1" })
        {
            var col = (Color)ColorConverter.ConvertFromString(hex);
            var sw = new Border { Width = 30, Height = 30, CornerRadius = new CornerRadius(15), Background = new SolidColorBrush(col), Margin = new Thickness(0, 0, 8, 0), Cursor = System.Windows.Input.Cursors.Hand, BorderBrush = new SolidColorBrush(Color.FromArgb(60, 255, 255, 255)), BorderThickness = new Thickness(1) };
            sw.MouseLeftButtonUp += (_, _) => { try { var theme = Wpf.Ui.Appearance.ApplicationThemeManager.GetAppTheme(); Wpf.Ui.Appearance.ApplicationAccentColorManager.Apply(col, theme); Wpf.Ui.Appearance.ApplicationThemeManager.Apply(theme); Render(); } catch { } };
            arow.Children.Add(sw);
        }
        a.Children.Add(arow);
        TweakList.Items.Add(Card(a));

        var d = Section("Density", "Comfortable has roomier cards; Compact fits more on screen.");
        var drow = new StackPanel { Orientation = Orientation.Horizontal };
        var comfy = Btn("Comfortable", () => { _compact = false; Render(); }); comfy.Width = 110; comfy.Margin = new Thickness(0, 0, 8, 0);
        var compact = Btn("Compact", () => { _compact = true; Render(); }); compact.Width = 110;
        drow.Children.Add(comfy); drow.Children.Add(compact); d.Children.Add(drow);
        TweakList.Items.Add(Card(d));

        var b = Section("Window material", "Mica is the Windows 11 look; Acrylic is blurrier; None is solid.");
        var brow = new StackPanel { Orientation = Orientation.Horizontal };
        foreach (var (lbl, bt) in new (string, Wpf.Ui.Controls.WindowBackdropType)[] { ("Mica", Wpf.Ui.Controls.WindowBackdropType.Mica), ("Acrylic", Wpf.Ui.Controls.WindowBackdropType.Acrylic), ("Tabbed", Wpf.Ui.Controls.WindowBackdropType.Tabbed), ("None", Wpf.Ui.Controls.WindowBackdropType.None) })
        {
            var btn = Btn(lbl, () => { try { WindowBackdropType = bt; } catch { } }); btn.Width = 90; btn.Margin = new Thickness(0, 0, 8, 0); brow.Children.Add(btn);
        }
        b.Children.Add(brow);
        TweakList.Items.Add(Card(b));

        var m = Section("Scheduled maintenance", "Create a weekly task (Sundays, noon) that flushes DNS and clears temp files.");
        var mb = Btn("Create weekly task", () => { Log("=== schedule maintenance ==="); Log(Engine.ScheduleMaintenance()); }); mb.Appearance = Wpf.Ui.Controls.ControlAppearance.Primary;
        m.Children.Add(mb);
        TweakList.Items.Add(Card(m));

        var dc = Section("Discord Rich Presence", "Show “Playing VoidTweaks” on your Discord profile. Make a free app at discord.com/developers → New Application, copy its Application ID here, then Enable. (For the logo, upload an art asset named 'voidtweaks' in that app.)");
        var dtb = new Wpf.Ui.Controls.TextBox { PlaceholderText = "Discord Application (Client) ID", Text = Engine.GetDiscordId(), Margin = new Thickness(0, 0, 0, 10) };
        var dcrow = new StackPanel { Orientation = Orientation.Horizontal };
        var den = Btn("Enable", () => { var id = (dtb.Text ?? "").Trim(); if (id.Length < 10 || !id.All(char.IsDigit)) { Log("Enter a valid numeric Discord Application ID first."); return; } Engine.SetDiscordId(id); Log("Discord: connecting…"); System.Threading.Tasks.Task.Run(() => StartRpc(id)); }); den.Appearance = Wpf.Ui.Controls.ControlAppearance.Primary; den.Margin = new Thickness(0, 0, 8, 0);
        var ddis = Btn("Disable", () => { Engine.SetDiscordId(""); StopRpc(); Log("Discord Rich Presence: off."); });
        dcrow.Children.Add(den); dcrow.Children.Add(ddis);
        dc.Children.Add(dtb); dc.Children.Add(dcrow);
        TweakList.Items.Add(Card(dc));

        var ab = Section("About", $"VoidTweaks — compiled C# / WPF-UI app. {_cat.Tweaks.Count} tweaks across {_cat.Categories.Count} categories. No telemetry, no paywall.");
        TweakList.Items.Add(Card(ab));
    }

    // ---------------- apps (winget) ----------------
    private void ShowApps()
    {
        HeaderTitle.Text = "Install apps";
        HeaderSub.Text = "Popular apps via winget, grouped by type — one click each. (The window pauses while an install runs.)";
        TweakList.Items.Clear();
        var top = Section("Update everything", "Upgrade all installed apps via winget.");
        var ua = Btn("Update all", () => { Log("=== winget upgrade --all ==="); Log(Engine.UpdateAllApps()); }); ua.Appearance = Wpf.Ui.Controls.ControlAppearance.Primary;
        top.Children.Add(ua);
        TweakList.Items.Add(Card(top));

        var seg = new WrapPanel { Margin = new Thickness(2, 2, 0, 12) };
        foreach (var cat in AppCats)
        {
            bool on = cat == _appCat;
            var b = new Wpf.Ui.Controls.Button { Content = cat, Appearance = on ? Wpf.Ui.Controls.ControlAppearance.Primary : Wpf.Ui.Controls.ControlAppearance.Secondary, Margin = new Thickness(0, 0, 8, 6) };
            var c = cat; b.Click += (_, _) => { _appCat = c; ShowApps(); };
            seg.Children.Add(b);
        }
        TweakList.Items.Add(seg);

        foreach (var app in Engine.Apps.Where(a => a.Cat == _appCat))
        {
            var a = app;
            var grid = TwoCol();
            var left = new StackPanel();
            left.Children.Add(new TextBlock { Text = a.Name, FontSize = 15, FontWeight = FontWeights.SemiBold });
            left.Children.Add(new TextBlock { Text = a.Id, Opacity = 0.4, FontSize = 10.5, Margin = new Thickness(0, 6, 0, 0), FontFamily = new FontFamily("Cascadia Mono, Consolas") });
            Grid.SetColumn(left, 0); grid.Children.Add(left);
            var btn = new Wpf.Ui.Controls.Button { Content = "Install", Appearance = Wpf.Ui.Controls.ControlAppearance.Success, Width = 92, VerticalAlignment = VerticalAlignment.Center };
            btn.Click += (_, _) => { btn.Content = "Installing…"; btn.IsEnabled = false; Log($"=== install {a.Name} ==="); Log(Engine.InstallApp(a.Id)); btn.Content = "Install"; btn.IsEnabled = true; };
            Grid.SetColumn(btn, 1); grid.Children.Add(btn);
            TweakList.Items.Add(Card(grid));
        }
    }

    // ---------------- overclocking ----------------
    private void ShowOverclock()
    {
        HeaderTitle.Text = "Overclock";
        HeaderSub.Text = "Benchmark your PC and get safe, spec‑aware tuning advice";
        TweakList.Items.Clear();

        var warn = new Border
        {
            Background = new SolidColorBrush(Color.FromArgb(40, 0xEF, 0x6A, 0x60)),
            BorderBrush = new SolidColorBrush(Color.FromArgb(120, 0xEF, 0x6A, 0x60)),
            BorderThickness = new Thickness(1), CornerRadius = new CornerRadius(12), Padding = new Thickness(16), Margin = new Thickness(0, 0, 0, 12),
            Child = new TextBlock { Text = "⚠  VoidTweaks never changes clocks or voltages for you. Overclocking is done in BIOS/UEFI and GPU tools, at your own risk — this tab only benchmarks and recommends safe starting points.", Foreground = new SolidColorBrush(C(0xF2, 0xB0, 0xAA)), TextWrapping = TextWrapping.Wrap, FontSize = 12.5 }
        };
        TweakList.Items.Add(warn);

        var sp = Section("Your hardware", "Detected specs — the advice below adapts to these.");
        var specTxt = new TextBlock { Text = "Reading…", Opacity = 0.78, FontSize = 12.5, TextWrapping = TextWrapping.Wrap, FontFamily = new FontFamily("Cascadia Mono, Consolas") };
        sp.Children.Add(specTxt);
        TweakList.Items.Add(Card(sp));

        var bench = Section("Benchmark", "Read‑only: times CPU math, a RAM copy and a disk write/read. Run it before and after tuning to compare.");
        var benchTxt = new TextBlock { Text = "", Opacity = 0.82, FontSize = 12.5, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 11, 0, 0), FontFamily = new FontFamily("Cascadia Mono, Consolas") };
        var rb = Btn("Run benchmark", () => RunAsync(Engine.Benchmark, benchTxt)); rb.Appearance = Wpf.Ui.Controls.ControlAppearance.Primary;
        bench.Children.Add(rb); bench.Children.Add(benchTxt);
        TweakList.Items.Add(Card(bench));

        // spec-aware advice (filled once specs arrive)
        var adviceHost = new StackPanel();
        TweakList.Items.Add(adviceHost);
        System.Threading.Tasks.Task.Run(() =>
        {
            string specs; try { specs = Engine.SpecInfo(); } catch { specs = ""; }
            Dispatcher.Invoke(() =>
            {
                specTxt.Text = string.IsNullOrWhiteSpace(specs) ? "(could not read specs)" : specs;
                bool amd = specs.Contains("AMD", System.StringComparison.OrdinalIgnoreCase) || specs.Contains("Ryzen", System.StringComparison.OrdinalIgnoreCase);
                bool intel = specs.Contains("Intel", System.StringComparison.OrdinalIgnoreCase);
                var tips = new List<string>
                {
                    "1.  RAM — the biggest free win. Reboot into BIOS and enable " + (amd ? "EXPO / DOCP" : intel ? "XMP" : "XMP (Intel) / EXPO (AMD)") + " so your RAM runs at its rated speed shown above instead of a slow default (e.g. 2133/4800 MT/s).",
                    amd
                        ? "2.  CPU (AMD Ryzen): enable PBO (Precision Boost Overdrive) in BIOS for a small automatic boost. Curve Optimizer around −15 to −30 gives cooler, higher clocks with no manual voltage. No fixed all‑core OC needed on modern Ryzen."
                        : intel
                            ? "2.  CPU (Intel): stay near stock on 12th–14th gen. In BIOS enable 'Intel Default Settings' / a sane power limit (PL1=PL2) for stability; manual all‑core OC adds heat for little gaming gain."
                            : "2.  CPU: enable your board's auto‑boost (PBO on AMD, stock power limits on Intel). Avoid manual all‑core voltage OC unless you know the chip.",
                    "3.  GPU: use MSI Afterburner. Safe starting point — core +100 MHz, memory +500 MHz, raise the power limit, set a fan curve. Stress‑test with a game or Unigine Heaven; back off 25 MHz if you see artifacts or a crash.",
                    "4.  Temps: watch with HWiNFO. Keep CPU under ~90 °C and GPU under ~85 °C under load — if you're hotter, improve airflow before pushing clocks."
                };
                var adv = Section("Recommended tuning", "Do these in BIOS / GPU tools, not here. Ordered by effort vs reward.");
                foreach (var t in tips) adv.Children.Add(new TextBlock { Text = t, Opacity = 0.74, TextWrapping = TextWrapping.Wrap, FontSize = 12.5, Margin = new Thickness(0, 0, 0, 9) });
                var tools = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 2, 0, 0) };
                var ab = Btn("Install MSI Afterburner", () => InstallTool("Guru3D.Afterburner", "MSI Afterburner")); ab.Appearance = Wpf.Ui.Controls.ControlAppearance.Secondary; ab.Margin = new Thickness(0, 0, 8, 0);
                var hw = Btn("Install HWiNFO", () => InstallTool("REALiX.HWiNFO", "HWiNFO")); hw.Appearance = Wpf.Ui.Controls.ControlAppearance.Secondary;
                tools.Children.Add(ab); tools.Children.Add(hw);
                adv.Children.Add(tools);
                adviceHost.Children.Add(Card(adv));
            });
        });
    }

    private void InstallTool(string id, string name)
    {
        Log($"=== install {name} ===");
        System.Threading.Tasks.Task.Run(() => { var r = Engine.InstallApp(id); Dispatcher.Invoke(() => Log(r)); });
    }

    // ---------------- game profiles ----------------
    private record GameProfile(string Name, string Blurb, string[] Ids);
    private static readonly GameProfile[] GameProfiles =
    {
        new("Competitive FPS", "Valorant · CS2 · Apex · Fortnite — lowest input lag & latency.",
            new[] { "game-mode-on", "game-dvr-off", "game-gpu-scheduling", "game-mouse-accel-off", "game-system-responsiveness", "game-games-task", "perf-power-throttling-off", "perf-high-power-plan", "net-nagle-off", "net-throttling-off", "adv-gpu-msi-mode", "visual-animations-off" }),
        new("AAA / Open‑world", "Cyberpunk · GTA · Elden Ring — max GPU & CPU headroom.",
            new[] { "game-mode-on", "game-dvr-off", "game-gpu-scheduling", "game-system-responsiveness", "perf-ultimate-power", "perf-power-throttling-off", "visual-best-performance" }),
        new("Online multiplayer", "Warzone · LoL · Dota · Rocket League — network‑tuned.",
            new[] { "game-mode-on", "game-dvr-off", "game-system-responsiveness", "perf-high-power-plan", "net-nagle-off", "net-throttling-off", "net-autotuning-off", "net-rsc-off", "net-ecn-off", "net-heuristics-off", "net-dns-cloudflare" }),
        new("Streaming + gaming", "OBS while you play — stability over raw latency.",
            new[] { "game-mode-on", "game-gpu-scheduling", "perf-high-power-plan", "perf-power-throttling-off", "visual-transparency-off" }),
        new("Low‑end / Old PC", "Strip the eye‑candy for more FPS on weak hardware.",
            new[] { "game-mode-on", "perf-power-throttling-off", "visual-best-performance", "visual-transparency-off", "visual-animations-off", "visual-menu-delay" }),
    };

    private void ApplyProfile(GameProfile p, bool revert)
    {
        var set = _cat.Tweaks.Where(t => p.Ids.Contains(t.Id) && t.Reversible && t.Revert.Count > 0);
        RunMany(set, revert, (revert ? "revert profile: " : "apply profile: ") + p.Name);
    }

    private void ShowGameProfiles()
    {
        HeaderTitle.Text = "Game profiles";
        HeaderSub.Text = "One click applies a curated, reversible tweak set for a game type. Changes Windows settings only — not in‑game options.";
        TweakList.Items.Clear();
        foreach (var gp in GameProfiles)
        {
            var p = gp;
            int total = p.Ids.Count(id => _cat.Tweaks.Any(t => t.Id == id));
            int have = p.Ids.Count(id => _cat.Tweaks.FirstOrDefault(t => t.Id == id) is { } t && Engine.State(t) == "applied");
            bool full = total > 0 && have == total;

            var grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var cc = C(0xEF, 0x6A, 0x60);
            var tile = new Border { Width = 46, Height = 46, CornerRadius = new CornerRadius(12), Background = new SolidColorBrush(Color.FromArgb(38, cc.R, cc.G, cc.B)), Margin = new Thickness(0, 1, 16, 0), VerticalAlignment = VerticalAlignment.Top, Child = IconFor("Gaming", 24) };
            Grid.SetColumn(tile, 0); grid.Children.Add(tile);

            var left = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
            left.Children.Add(new TextBlock { Text = p.Name, FontSize = 16.5, FontWeight = FontWeights.SemiBold });
            left.Children.Add(new TextBlock { Text = p.Blurb, Opacity = 0.62, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 7, 14, 0), FontSize = 12.5 });
            left.Children.Add(new TextBlock { Text = full ? $"● Active — all {total} applied" : $"{have} / {total} applied", Foreground = new SolidColorBrush(full ? C(0x4C, 0xC3, 0x8A) : C(0x9A, 0x9A, 0xA6)), FontSize = 12, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 9, 0, 0) });
            Grid.SetColumn(left, 1); grid.Children.Add(left);

            var right = new StackPanel { VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(14, 0, 0, 0) };
            var apply = new Wpf.Ui.Controls.Button { Content = "Apply", Appearance = Wpf.Ui.Controls.ControlAppearance.Success, Width = 94 };
            if (!IsAdmin()) { apply.ToolTip = "Some tweaks need administrator"; }
            apply.Click += (_, _) => ApplyProfile(p, false);
            var rev = new Wpf.Ui.Controls.Button { Content = "Revert", Appearance = Wpf.Ui.Controls.ControlAppearance.Secondary, Width = 94, Margin = new Thickness(0, 8, 0, 0) };
            rev.Click += (_, _) => ApplyProfile(p, true);
            right.Children.Add(apply); right.Children.Add(rev);
            Grid.SetColumn(right, 2); grid.Children.Add(right);

            TweakList.Items.Add(GlowCard(grid, full ? C(0x4C, 0xC3, 0x8A) : C(0x6A, 0x6A, 0x77)));
        }
    }

    // ---------------- processes ----------------
    private void ShowProcesses()
    {
        var list = Engine.Processes();
        int useless = list.Count(p => p.Type == "useless");
        HeaderTitle.Text = "Processes";
        HeaderSub.Text = $"{list.Count} shown · {useless} useless flagged · system ones are locked";
        TweakList.Items.Clear();
        foreach (var p in list) TweakList.Items.Add(BuildProcCard(p));
    }

    private Border BuildProcCard(Engine.ProcInfo p)
    {
        var grid = TwoCol();
        var left = new StackPanel();
        var row = new StackPanel { Orientation = Orientation.Horizontal };
        row.Children.Add(new TextBlock { Text = p.Name, FontSize = 15, FontWeight = FontWeights.SemiBold, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 10, 0) });
        if (p.Count > 1) row.Children.Add(Badge($"x{p.Count}", C(0x9A, 0x9A, 0xA6)));
        if (p.Type == "system") row.Children.Add(Badge("SYSTEM", C(0x9A, 0x9A, 0xA6)));
        if (p.Type == "useless") row.Children.Add(Badge("USELESS", C(0xEF, 0x6A, 0x60)));
        left.Children.Add(row);
        left.Children.Add(new TextBlock { Text = $"{p.Mem / 1048576.0:N0} MB memory", Opacity = 0.65, Margin = new Thickness(0, 7, 14, 0), FontSize = 12.5 });
        Grid.SetColumn(left, 0); grid.Children.Add(left);
        var right = new StackPanel { HorizontalAlignment = HorizontalAlignment.Right };
        (string ptxt, Color pc) = p.Type switch
        {
            "useless" => ("Safe to end", C(0xEF, 0x6A, 0x60)),
            "system" => ("Locked", C(0x9A, 0x9A, 0xA6)),
            _ => ("Running", C(0x5B, 0x9B, 0xFF))
        };
        right.Children.Add(PillBox(ptxt, pc));
        if (p.Type != "system")
        {
            var end = new Wpf.Ui.Controls.Button { Content = "End task", Appearance = p.Type == "useless" ? Wpf.Ui.Controls.ControlAppearance.Danger : Wpf.Ui.Controls.ControlAppearance.Secondary, Width = 92, Margin = new Thickness(0, 11, 0, 0), HorizontalAlignment = HorizontalAlignment.Right };
            var name = p.Name;
            end.Click += (_, _) => { Engine.EndProcess(name); Log($"Ended '{name}'."); ShowProcesses(); };
            right.Children.Add(end);
        }
        Grid.SetColumn(right, 1); grid.Children.Add(right);
        return Card(grid);
    }

    // ---------------- cleanup (lazy mode) ----------------
    private void ShowCleanup()
    {
        HeaderTitle.Text = "Cleanup";
        HeaderSub.Text = "Lazy mode — clear junk, caches and bloat in one click. No going tweak-by-tweak.";
        TweakList.Items.Clear();

        var full = Section("Full clean  (recommended)", "Clears temp files, Windows cache, thumbnails, Store cache, empties the Recycle Bin, flushes DNS, trims your SSD and frees RAM — all the throwaway stuff, nothing personal.");
        var fb = Btn("✨  Clean everything now", () => RunCleanupSet(new[] { "clean-temp", "clean-windows-temp", "maint-clear-thumbnails", "maint-clear-store-cache", "maint-empty-recyclebin", "net-flush-dns", "maint-trim-ssd", "maint-free-ram" }, "Full clean")); fb.Appearance = Wpf.Ui.Controls.ControlAppearance.Success;
        full.Children.Add(fb);
        TweakList.Items.Add(Card(full));

        var junk = Section("Just the junk files", "Temp + Windows temp + thumbnails + Store cache + Recycle Bin. Frees disk space, touches nothing important.");
        junk.Children.Add(Btn("Clean junk files", () => RunCleanupSet(new[] { "clean-temp", "clean-windows-temp", "maint-clear-thumbnails", "maint-clear-store-cache", "maint-empty-recyclebin" }, "Clean junk")));
        TweakList.Items.Add(Card(junk));

        var bloatIds = _cat.Tweaks.Where(t => t.Category == "Debloat" || t.Category == "AI & Bloat").Select(t => t.Id).ToArray();
        var deb = Section("Remove bloatware apps", $"Uninstalls the common pre-installed junk in one go ({bloatIds.Length} items — Xbox leftovers, Teams chat, 3D Viewer, Maps, Copilot, etc.). Reversible: you can always reinstall from the Store.");
        var db = Btn("Remove all bloatware", () => RunCleanupSet(bloatIds, "Debloat")); db.Appearance = Wpf.Ui.Controls.ControlAppearance.Caution;
        deb.Children.Add(db);
        TweakList.Items.Add(Card(deb));

        var boost = Section("Just free up RAM", "Trims working sets, clears temp, flushes DNS — same as the ⚡ Boost button up top.");
        boost.Children.Add(Btn("Free RAM now", () => BoostBtn_Click(this, new RoutedEventArgs())));
        TweakList.Items.Add(Card(boost));
    }
    private void RunCleanupSet(string[] ids, string label)
    {
        var set = _cat.Tweaks.Where(t => ids.Contains(t.Id)).ToList();
        if (set.Count == 0) { Log("Nothing to run for " + label + "."); return; }
        RunMany(set, false, label);
    }

    // ---------------- security (deep scan) ----------------
    private void ShowSecurity()
    {
        HeaderTitle.Text = "Security";
        HeaderSub.Text = "Deep virus scanning with Windows' built-in engine, plus the heavier tools for when something nasty won't budge.";
        TweakList.Items.Clear();

        var upd = Section("1. Update protection first", "Grab the newest virus definitions before scanning.");
        var updTxt = new TextBlock { Text = "", Opacity = 0.8, FontSize = 12.5, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 10, 0, 0) };
        var ub = Btn("Update definitions", () => RunAsync(Engine.DefenderUpdate, updTxt)); ub.Appearance = Wpf.Ui.Controls.ControlAppearance.Primary;
        upd.Children.Add(ub); upd.Children.Add(updTxt);
        TweakList.Items.Add(Card(upd));

        var scan = Section("2. Scan this PC", "Quick checks the usual hiding spots. Full deep-scans every file — slow (30–60 min) but thorough. Both run in the background so the app stays usable.");
        var scanTxt = new TextBlock { Text = "", Opacity = 0.82, FontSize = 12.5, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 11, 0, 0), FontFamily = new FontFamily("Cascadia Mono, Consolas") };
        var srow = new WrapPanel();
        var sq = Btn("Quick scan", () => { Log("Defender quick scan started…"); scanTxt.Text = "Quick scan running…"; RunAsync(() => Engine.DefenderScan("Quick"), scanTxt); }); sq.Appearance = Wpf.Ui.Controls.ControlAppearance.Primary; sq.Margin = new Thickness(0, 0, 8, 0);
        var sf = Btn("Full deep scan", () => { Log("Defender FULL scan started — this can take a while (background)…"); scanTxt.Text = "Full scan running in the background… you'll see the result here when it finishes."; RunAsync(() => Engine.DefenderScan("Full"), scanTxt); });
        srow.Children.Add(sq); srow.Children.Add(sf);
        scan.Children.Add(srow); scan.Children.Add(scanTxt);
        TweakList.Items.Add(Card(scan));

        var off = Section("3. Offline scan  (the nuclear option)", "Reboots your PC and scans BEFORE Windows loads — catches rootkits and deep infections a normal scan can't. Save your work first!");
        var offTxt = new TextBlock { Text = "", Opacity = 0.8, FontSize = 12.5, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 10, 0, 0) };
        var ob = Btn("Run offline scan (reboots!)", () =>
        {
            if (System.Windows.MessageBox.Show(this, "This reboots your PC now and scans before Windows starts. Save everything first. Continue?", "VoidTweaks — Offline scan", System.Windows.MessageBoxButton.YesNo, System.Windows.MessageBoxImage.Warning) == System.Windows.MessageBoxResult.Yes)
            { Log("Scheduling Defender offline scan…"); RunAsync(Engine.DefenderOffline, offTxt); }
        }); ob.Appearance = Wpf.Ui.Controls.ControlAppearance.Danger;
        off.Children.Add(ob); off.Children.Add(offTxt);
        TweakList.Items.Add(Card(off));

        var tron = Section("Heavier tools — like TRON", "When something really won't leave: TRON runs a whole battery of cleaners + malware scanners automatically (the one that saved you). It's a trusted community script — open the guide, read it, then run it yourself. Or grab Malwarebytes for a strong second-opinion scan.");
        var trow = new WrapPanel();
        var mb = Btn("Install Malwarebytes", () => InstallTool("Malwarebytes.Malwarebytes", "Malwarebytes")); mb.Appearance = Wpf.Ui.Controls.ControlAppearance.Secondary; mb.Margin = new Thickness(0, 0, 8, 0);
        var tb = Btn("Open TRON guide", () => OpenUrl("https://old.reddit.com/r/TronScript/")); tb.Appearance = Wpf.Ui.Controls.ControlAppearance.Secondary;
        trow.Children.Add(mb); trow.Children.Add(tb);
        tron.Children.Add(trow);
        TweakList.Items.Add(Card(tron));
    }
    private void OpenUrl(string url)
    {
        try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); Log("Opened: " + url); } catch (System.Exception ex) { Log("Could not open link: " + ex.Message); }
    }

    // ---------------- shared ----------------
    private static Grid TwoCol()
    {
        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        return grid;
    }
    private static Border Card(UIElement child)
    {
        var b = new Border
        {
            Background = new SolidColorBrush(Color.FromArgb(28, 255, 255, 255)),
            BorderBrush = new SolidColorBrush(Color.FromArgb(26, 255, 255, 255)),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(12),
            Padding = new Thickness(_compact ? 11 : 16),
            Margin = new Thickness(0, 0, 0, _compact ? 7 : 10),
            Child = child
        };
        b.MouseEnter += (_, _) => b.Background = new SolidColorBrush(Color.FromArgb(42, 255, 255, 255));
        b.MouseLeave += (_, _) => b.Background = new SolidColorBrush(Color.FromArgb(28, 255, 255, 255));
        return b;
    }
    private static Border Badge(string text, Color c) => new()
    {
        Background = new SolidColorBrush(Color.FromArgb(34, c.R, c.G, c.B)),
        CornerRadius = new CornerRadius(5),
        Padding = new Thickness(7, 2, 7, 2),
        Margin = new Thickness(0, 0, 6, 0),
        VerticalAlignment = VerticalAlignment.Center,
        Child = new TextBlock { Text = text, Foreground = new SolidColorBrush(c), FontSize = 10, FontWeight = FontWeights.SemiBold }
    };
    private static Border PillBox(string txt, Color c) => new()
    {
        Background = new SolidColorBrush(Color.FromArgb(46, c.R, c.G, c.B)),
        CornerRadius = new CornerRadius(11),
        Padding = new Thickness(11, 4, 11, 4),
        HorizontalAlignment = HorizontalAlignment.Right,
        Child = new TextBlock { Text = txt, Foreground = new SolidColorBrush(c), FontSize = 11, FontWeight = FontWeights.SemiBold }
    };
    private static Border Pill(string state)
    {
        (string txt, Color c) = state switch
        {
            "applied" => ("Applied", C(0x4C, 0xC3, 0x8A)),
            "custom" => ("Custom value", C(0xE5, 0xAA, 0x3D)),
            "default" => ("Not applied", C(0x9A, 0x9A, 0xA6)),
            "action" => ("One-time", C(0x5B, 0x9B, 0xFF)),
            _ => ("Scan", C(0x9A, 0x9A, 0xA6))
        };
        return PillBox(txt, c);
    }
    private static Color C(byte r, byte g, byte b) => Color.FromRgb(r, g, b);
    private static Color RiskColor(string r) => r switch { "high" => C(0xEF, 0x6A, 0x60), "medium" => C(0xE5, 0xAA, 0x3D), _ => C(0x9A, 0x9A, 0xA6) };

    // ---------------- actions ----------------
    private bool _busy;
    private void SetBusy(bool b)
    {
        _busy = b;
        BoostBtn.IsEnabled = ApplyAllBtn.IsEnabled = RevertAllBtn.IsEnabled = ScanBtn.IsEnabled = !b;
        Cursor = b ? System.Windows.Input.Cursors.Wait : null;
        HeaderSub.Opacity = b ? 0.35 : 0.65;
    }

    private void RunMany(IEnumerable<Tweak> set, bool revert, string label)
    {
        if (_busy) { Log("Busy — wait for the current action to finish."); return; }
        bool dry = DryCheck.IsChecked == true;
        bool restore = RestoreCheck.IsChecked == true && IsAdmin();
        var cmds = new List<string>(); var ids = new List<string>(); int skipped = 0;
        foreach (var t in set)
        {
            if (!revert && t.RequiresAdmin && !IsAdmin()) { skipped++; continue; }
            var c = revert ? t.Revert : t.Apply;
            if (c.Count == 0) continue;
            cmds.Add($"Write-Output '--- {(revert ? "revert" : "apply")} {t.Id} ---'");
            cmds.AddRange(c);
            if (!revert && t.Reversible && t.Revert.Count > 0) ids.Add(t.Id);
        }
        if (cmds.Count == 0) { Log($"Nothing to {(revert ? "revert" : "apply")}{(skipped > 0 ? $" ({skipped} need admin)" : "")}."); return; }
        Log($"=== {label}{(dry ? " (dry run)" : "")} ===");
        if (dry) { foreach (var c in cmds) if (!c.StartsWith("Write-Output")) Log("WOULD RUN: " + c); Render(); return; }

        SetBusy(true);
        System.Threading.Tasks.Task.Run(() =>
        {
            if (!revert && restore) Engine.RestorePoint();
            var outp = Engine.RunCommands(cmds);
            Dispatcher.Invoke(() =>
            {
                Log(outp);
                if (ids.Count > 0) { _undo = ids; UndoBtn.IsEnabled = true; }
                SetBusy(false);
                Render();
            });
        });
    }

    private void BoostBtn_Click(object sender, RoutedEventArgs e)
    {
        if (_busy) return;
        bool admin = IsAdmin();
        Log("=== Boost: free RAM + clear temp + flush DNS" + (admin ? " + purge standby" : "") + " ===");
        SetBusy(true);
        System.Threading.Tasks.Task.Run(() =>
        {
            var r = Engine.Boost(admin);
            Dispatcher.Invoke(() =>
            {
                Log(r);
                SetBusy(false);
                UpdateLive();
                if (!admin && System.Windows.MessageBox.Show(this, "Also purge the standby memory list? That frees the most RAM (RAMMap-style) but needs a one-time admin prompt.", "VoidTweaks — Boost", System.Windows.MessageBoxButton.YesNo, System.Windows.MessageBoxImage.Question) == System.Windows.MessageBoxResult.Yes)
                {
                    Log("Requesting elevation to purge standby list…");
                    SetBusy(true);
                    System.Threading.Tasks.Task.Run(() => { var p = Engine.PurgeStandbyElevated(); Dispatcher.Invoke(() => { Log(p); SetBusy(false); UpdateLive(); }); });
                }
            });
        });
    }
    private void ScanBtn_Click(object sender, RoutedEventArgs e) => Render();
    private void ApplyAllBtn_Click(object sender, RoutedEventArgs e) { var s = CurrentTweaks(); if (s.Count > 0) RunMany(s, false, "apply all: " + _sel); }
    private void RevertAllBtn_Click(object sender, RoutedEventArgs e) { var s = CurrentTweaks(); if (s.Count > 0) RunMany(s, true, "revert all: " + _sel); }
    private void UndoBtn_Click(object sender, RoutedEventArgs e)
    {
        if (_undo.Count == 0) return;
        var set = _cat.Tweaks.Where(t => _undo.Contains(t.Id)).ToList();
        _undo = new(); UndoBtn.IsEnabled = false;
        RunMany(set, true, "undo");
    }
    private void ThemeBtn_Click(object sender, RoutedEventArgs e) { }

    private void Elevate_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var exe = Process.GetCurrentProcess().MainModule?.FileName;
            if (exe != null) { Process.Start(new ProcessStartInfo(exe) { UseShellExecute = true, Verb = "runas" }); System.Windows.Application.Current.Shutdown(); }
        }
        catch { }
    }

    private static bool IsAdmin()
    {
        try { using var id = System.Security.Principal.WindowsIdentity.GetCurrent(); return new System.Security.Principal.WindowsPrincipal(id).IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator); }
        catch { return false; }
    }
    private void Log(string s) { if (string.IsNullOrWhiteSpace(s)) return; LogBox.AppendText(s.TrimEnd() + "\r\n"); LogBox.ScrollToEnd(); }

    // ---------------- dashboard ----------------
    [StructLayout(LayoutKind.Sequential)]
    private struct MEMSTAT { public uint dwLength, dwMemoryLoad; public ulong total, avail, a, b, c, d, e; }
    [DllImport("kernel32.dll")] private static extern bool GlobalMemoryStatusEx(ref MEMSTAT m);
    [DllImport("kernel32.dll")] private static extern bool GetSystemTimes(out long idle, out long kernel, out long user);

    private void UpdateStatic()
    {
        try { OsText.Text = $"build {System.Environment.OSVersion.Version.Build}"; } catch { }
        try { var d = new DriveInfo(System.IO.Path.GetPathRoot(System.Environment.SystemDirectory)!); DiskText.Text = $"{d.AvailableFreeSpace / 1073741824.0:N0} GB free of {d.TotalSize / 1073741824.0:N0}"; } catch { }
        try { var g = Engine.RunOne("(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -and \"$($_.Status)\" -eq 'OK' -and $_.Name -notmatch 'Meta|Virtual|Basic|Remote' } | Select-Object -First 1).Name"); GpuText.Text = string.IsNullOrWhiteSpace(g) ? "—" : g; } catch { GpuText.Text = "—"; }
    }
    private void UpdateLive()
    {
        try
        {
            var m = new MEMSTAT { dwLength = (uint)Marshal.SizeOf<MEMSTAT>() };
            GlobalMemoryStatusEx(ref m);
            int pct = (int)m.dwMemoryLoad;
            _ramPct = pct;
            RamBar.Value = pct;
            RamBar.Foreground = pct >= 85 ? Grad("#EF6A60", "#E5AA3D") : pct >= 70 ? Grad("#E5AA3D", "#8B7CF0") : Grad("#8B7CF0", "#35B9AD");
            RamText.Text = $"{(m.total - m.avail) / 1073741824.0:F1} / {m.total / 1073741824.0:F1} GB  ({pct}%)";
        }
        catch { }
        try { _cpuPct = Cpu(); CpuText.Text = _cpuPct + "%"; } catch { }
        try { _liveHook?.Invoke(); } catch { }
    }
    private static LinearGradientBrush Grad(string a, string b)
    {
        var br = new LinearGradientBrush { StartPoint = new Point(0, 0), EndPoint = new Point(1, 0) };
        br.GradientStops.Add(new GradientStop((Color)ColorConverter.ConvertFromString(a), 0));
        br.GradientStops.Add(new GradientStop((Color)ColorConverter.ConvertFromString(b), 1));
        return br;
    }
    private int Cpu()
    {
        GetSystemTimes(out long i, out long k, out long u);
        int busy = 0;
        if (_pk != 0) { long dk = k - _pk, du = u - _pu, di = i - _pi, tot = dk + du; if (tot > 0) busy = (int)(100 * (tot - di) / tot); }
        _pi = i; _pk = k; _pu = u;
        return busy < 0 ? 0 : busy > 100 ? 100 : busy;
    }
}
