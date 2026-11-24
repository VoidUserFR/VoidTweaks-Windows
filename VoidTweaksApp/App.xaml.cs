using System;
using System.IO;
using System.Windows;

namespace VoidTweaks;

public partial class App : System.Windows.Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        // Catch anything that would otherwise close the app with no message.
        DispatcherUnhandledException += (_, ev) =>
        {
            Log("Dispatcher", ev.Exception);
            ev.Handled = true;          // keep running where we can
            Notify(ev.Exception);
        };
        AppDomain.CurrentDomain.UnhandledException += (_, ev) =>
        {
            if (ev.ExceptionObject is Exception ex) { Log("AppDomain", ex); Notify(ex); }
        };
        System.Threading.Tasks.TaskScheduler.UnobservedTaskException += (_, ev) =>
        {
            Log("Task", ev.Exception); ev.SetObserved();
        };
        base.OnStartup(e);
    }

    public static string LogDir => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "VoidTweaks");
    public static string LogPath => Path.Combine(LogDir, "crash.log");

    // Append an entry to %LocalAppData%\VoidTweaks\crash.log (best-effort, never throws).
    public static void Log(string where, Exception ex)
    {
        try
        {
            Directory.CreateDirectory(LogDir);
            var v = System.Reflection.Assembly.GetExecutingAssembly().GetName().Version?.ToString() ?? "?";
            File.AppendAllText(LogPath,
                $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] v{v}  {Environment.OSVersion}  .NET {Environment.Version}  — {where}" +
                Environment.NewLine + ex + Environment.NewLine + new string('-', 64) + Environment.NewLine);
        }
        catch { }
    }

    private static bool _notified;
    private static void Notify(Exception ex)
    {
        if (_notified) return; _notified = true;   // one dialog, not a storm
        try
        {
            MessageBox.Show(
                "VoidTweaks hit an error and some features may not work.\n\n" +
                ex.Message + "\n\nDetails were saved to:\n" + LogPath +
                "\n\nPlease attach that file to a bug report so we can fix it.",
                "VoidTweaks", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
        catch { }
    }
}
