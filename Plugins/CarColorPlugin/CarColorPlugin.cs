using System.Drawing;
using AssettoServer.Network.ClientMessages;
using AssettoServer.Network.Tcp;
using AssettoServer.Server;
using Microsoft.Extensions.Hosting;
using Serilog;

namespace CarColorPlugin;

public class CarColorPlugin : IHostedService
{
    private readonly CarColorConfiguration _config;
    private readonly EntryCarManager _entryCarManager;
    private readonly object _lock = new();
    private readonly Dictionary<byte, Color> _playerColors = new();
    private readonly Dictionary<byte, DateTime> _lastColorChange = new();

    public CarColorPlugin(CarColorConfiguration config,
        EntryCarManager entryCarManager,
        CSPClientMessageTypeManager cspClientMessageTypeManager)
    {
        _config = config;
        _entryCarManager = entryCarManager;

        cspClientMessageTypeManager.RegisterOnlineEvent<CarColorChangePacket>(OnColorChangeReceived);
        _entryCarManager.ClientConnected += OnClientConnected;
        _entryCarManager.ClientDisconnected += OnClientDisconnected;
    }

    private void OnClientConnected(ACTcpClient sender, EventArgs args)
    {
        sender.FirstUpdateSent += OnFirstUpdateSent;
    }

    private void OnFirstUpdateSent(ACTcpClient sender, EventArgs args)
    {
        List<KeyValuePair<byte, Color>> colors;
        lock (_lock)
        {
            colors = _playerColors.ToList();
        }

        foreach (var (sessionId, color) in colors)
        {
            if (sessionId == sender.SessionId) continue;
            sender.SendPacket(new CarColorUpdatePacket { SessionId = sessionId, Color = color });
        }
    }

    private void OnClientDisconnected(ACTcpClient sender, EventArgs args)
    {
        lock (_lock)
        {
            _playerColors.Remove(sender.SessionId);
            _lastColorChange.Remove(sender.SessionId);
        }
    }

    private void OnColorChangeReceived(ACTcpClient client, CarColorChangePacket packet)
    {
        var now = DateTime.UtcNow;

        lock (_lock)
        {
            if (_lastColorChange.TryGetValue(client.SessionId, out var lastChange)
                && (now - lastChange).TotalSeconds < _config.ChangeCooldownSeconds)
            {
                return;
            }

            _lastColorChange[client.SessionId] = now;
            _playerColors[client.SessionId] = packet.Color;
        }

        Log.Information("{ClientName} ({SessionId}) changed car color to {Color}", client.Name, client.SessionId, packet.Color);

        _entryCarManager.BroadcastPacket(new CarColorUpdatePacket
        {
            SessionId = client.SessionId,
            Color = packet.Color
        }, client);
    }

    public Task StartAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}

[OnlineEvent(Key = "AS_CarColor")]
public class CarColorChangePacket : OnlineEvent<CarColorChangePacket>
{
    [OnlineEventField(Name = "color")]
    public Color Color;
}

[OnlineEvent(Key = "AS_CarColorUpdate")]
public class CarColorUpdatePacket : OnlineEvent<CarColorUpdatePacket>
{
    [OnlineEventField(Name = "color")]
    public Color Color;
}