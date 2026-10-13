using System.Globalization;
using System.Reflection;
using AssettoServer.Network.ClientMessages;
using AssettoServer.Network.Tcp;
using AssettoServer.Server;
using AssettoServer.Server.Configuration;
using Microsoft.Extensions.Hosting;
using Serilog;

namespace CarColorPlugin;

public class CarColorPlugin : IHostedService
{
    private readonly CarColorConfiguration _config;
    private readonly EntryCarManager _entryCarManager;
    private readonly CSPServerScriptProvider _scriptProvider;
    private readonly object _lock = new();
    private readonly Dictionary<byte, CarColorState> _playerColors = new();

    public CarColorPlugin(CarColorConfiguration config,
        EntryCarManager entryCarManager,
        CSPServerScriptProvider scriptProvider,
        ACServerConfiguration serverConfig)
    {
        _config = config;
        _entryCarManager = entryCarManager;
        _scriptProvider = scriptProvider;

        if (!serverConfig.Extra.EnableClientMessages)
        {
            throw new ConfigurationException("EnableClientMessages must be true for CarColorPlugin");
        }

        _scriptProvider.AddScript(
            File.ReadAllText(Path.Join(Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location), "lua", "carcolor.lua")),
            "carcolor.lua",
            new Dictionary<string, object>
            {
                ["changeCooldownSeconds"] = _config.ChangeCooldownSeconds.ToString(CultureInfo.InvariantCulture),
                ["maxHistory"] = _config.MaxHistory.ToString(CultureInfo.InvariantCulture),
                ["maxFavourites"] = _config.MaxFavourites.ToString(CultureInfo.InvariantCulture),
                ["presets"] = string.Join(",", _config.Presets),
                ["bodyMaterialNames"] = string.Join(",", _config.BodyMaterialNames),
                ["caliperMaterialNames"] = string.Join(",", _config.CaliperMaterialNames)
            });

        _entryCarManager.ClientConnected += OnClientConnected;
        _entryCarManager.ClientDisconnected += OnClientDisconnected;
    }

    private void OnClientConnected(ACTcpClient sender, EventArgs args)
    {
        sender.FirstUpdateSent += OnFirstUpdateSent;
    }

    private void OnFirstUpdateSent(ACTcpClient sender, EventArgs args)
    {
        List<CarColorState> colors;
        lock (_lock)
        {
            colors = _playerColors.Values.ToList();
        }

        foreach (var state in colors)
        {
            if (state.SessionId == sender.SessionId) continue;
            sender.SendPacket(new CarColorUpdatePacket
            {
                SessionId = state.SessionId,
                Color = state.Color,
                Metallic = state.Metallic,
                Roughness = state.Roughness,
                CaliperColor = state.CaliperColor,
                HasCaliper = state.HasCaliper
            });
        }
    }

    private void OnClientDisconnected(ACTcpClient sender, EventArgs args)
    {
        lock (_lock)
        {
            _playerColors.Remove(sender.SessionId);
        }
    }

    private void OnColorChangeReceived(ACTcpClient client, CarColorChangePacket packet)
    {
        var now = DateTime.UtcNow;

        // Validate and clamp values
        var metallic = float.IsNaN(packet.Metallic) ? 0.0f : Math.Clamp(packet.Metallic, 0.0f, 1.0f);
        var roughness = float.IsNaN(packet.Roughness) ? 0.0f : Math.Clamp(packet.Roughness, 0.0f, 1.0f);

        lock (_lock)
        {
            if (_playerColors.TryGetValue(client.SessionId, out var lastChange)
                && (now - lastChange.LastChangeTime).TotalSeconds < _config.ChangeCooldownSeconds)
            {
                return;
            }

            _playerColors[client.SessionId] = new CarColorState
            {
                SessionId = client.SessionId,
                Color = packet.Color,
                Metallic = metallic,
                Roughness = roughness,
                CaliperColor = packet.CaliperColor,
                HasCaliper = packet.HasCaliper,
                LastChangeTime = now
            };
        }

        Log.Information("{ClientName} ({SessionId}) changed car color to {Color} (Metallic: {Metallic}, Roughness: {Roughness}, Caliper: {Caliper})",
            client.Name, client.SessionId, packet.Color, metallic, roughness, packet.CaliperColor);

        _entryCarManager.BroadcastPacket(new CarColorUpdatePacket
        {
            SessionId = client.SessionId,
            Color = packet.Color,
            Metallic = metallic,
            Roughness = roughness,
            CaliperColor = packet.CaliperColor,
            HasCaliper = packet.HasCaliper
        }, client);
    }

    public Task StartAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}

public class CarColorState
{
    public byte SessionId { get; set; }
    public System.Drawing.Color Color { get; set; }
    public float Metallic { get; set; }
    public float Roughness { get; set; }
    public System.Drawing.Color CaliperColor { get; set; }
    public bool HasCaliper { get; set; }
    public DateTime LastChangeTime { get; set; }
}

[OnlineEvent(Key = "AS_CarColor")]
public class CarColorChangePacket : OnlineEvent<CarColorChangePacket>
{
    [OnlineEventField(Name = "color")]
    public System.Drawing.Color Color;

    [OnlineEventField(Name = "metallic")]
    public float Metallic;

    [OnlineEventField(Name = "roughness")]
    public float Roughness;

    [OnlineEventField(Name = "caliperColor")]
    public System.Drawing.Color CaliperColor;

    [OnlineEventField(Name = "hasCaliper")]
    public bool HasCaliper;
}

[OnlineEvent(Key = "AS_CarColorUpdate")]
public class CarColorUpdatePacket : OnlineEvent<CarColorUpdatePacket>
{
    [OnlineEventField(Name = "sessionId")]
    public byte SessionId;

    [OnlineEventField(Name = "color")]
    public System.Drawing.Color Color;

    [OnlineEventField(Name = "metallic")]
    public float Metallic;

    [OnlineEventField(Name = "roughness")]
    public float Roughness;

    [OnlineEventField(Name = "caliperColor")]
    public System.Drawing.Color CaliperColor;

    [OnlineEventField(Name = "hasCaliper")]
    public bool HasCaliper;
}
