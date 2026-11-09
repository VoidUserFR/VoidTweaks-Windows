using System.IO.Pipes;
using System.Text;
using System.Text.Json;

namespace VoidTweaks;

// Minimal Discord Rich Presence client over the local IPC named pipe
// (\\.\pipe\discord-ipc-N). No external library — just the documented frame
// protocol: int32 opcode + int32 length + UTF-8 JSON, little-endian.
public sealed class DiscordRpc : IDisposable
{
    private NamedPipeClientStream? _pipe;
    private readonly string _clientId;
    public bool Connected => _pipe?.IsConnected == true;

    public DiscordRpc(string clientId) { _clientId = clientId; }

    public bool Connect()
    {
        for (int i = 0; i < 10; i++)
        {
            try
            {
                var p = new NamedPipeClientStream(".", $"discord-ipc-{i}", PipeDirection.InOut, PipeOptions.Asynchronous);
                p.Connect(600);
                _pipe = p;
                Send(0, JsonSerializer.Serialize(new { v = 1, client_id = _clientId })); // handshake
                System.Threading.Tasks.Task.Run(ReadFrame).Wait(1500); // READY dispatch, but never block forever
                return true;
            }
            catch { try { _pipe?.Dispose(); } catch { } _pipe = null; }
        }
        return false;
    }

    public void SetActivity(string details, string state)
    {
        if (!Connected) return;
        var payload = new
        {
            cmd = "SET_ACTIVITY",
            args = new
            {
                pid = System.Environment.ProcessId,
                activity = new
                {
                    details,
                    state,
                    timestamps = new { start = System.DateTimeOffset.UtcNow.ToUnixTimeSeconds() },
                    assets = new { large_image = "voidtweaks", large_text = "VoidTweaks" }
                }
            },
            nonce = System.Guid.NewGuid().ToString()
        };
        try { Send(1, JsonSerializer.Serialize(payload)); ReadFrame(); } catch { }
    }

    public void Clear()
    {
        if (!Connected) return;
        var payload = new { cmd = "SET_ACTIVITY", args = new { pid = System.Environment.ProcessId, activity = (object?)null }, nonce = System.Guid.NewGuid().ToString() };
        try { Send(1, JsonSerializer.Serialize(payload)); } catch { }  // fire-and-forget; don't block the UI thread on a reply
    }

    private void Send(int opcode, string json)
    {
        if (_pipe == null) return;
        var data = Encoding.UTF8.GetBytes(json);
        var buf = new byte[8 + data.Length];
        System.BitConverter.GetBytes(opcode).CopyTo(buf, 0);
        System.BitConverter.GetBytes(data.Length).CopyTo(buf, 4);
        data.CopyTo(buf, 8);
        _pipe.Write(buf, 0, buf.Length);
        _pipe.Flush();
    }

    private void ReadFrame()
    {
        if (_pipe == null) return;
        var header = new byte[8];
        try { _pipe.ReadExactly(header, 0, 8); } catch { return; }
        int len = System.BitConverter.ToInt32(header, 4);
        if (len > 0 && len < 1_000_000) { var b = new byte[len]; try { _pipe.ReadExactly(b, 0, len); } catch { } }
    }

    public void Dispose()
    {
        try { Clear(); } catch { }
        try { _pipe?.Dispose(); } catch { }
        _pipe = null;
    }
}
