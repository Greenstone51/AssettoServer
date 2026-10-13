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
        CSPClientMessageTypeManager cspClientMessageTypeManager,
        ACServerConfiguration serverConfig)
    {
        _config = config;
        _entryCarManager = entryCarManager;
        _scriptProvider = scriptProvider;

        if (!serverConfig.Extra.EnableClientMessages)
        {
            throw new ConfigurationException("EnableClientMessages must be true for CarColorPlugin");
        }

        // Values are quoted like in FastTravelPlugin; '#' is stripped from colors because it may be treated as a comment in the INI.
        _scriptProvider.AddScript(
            File.ReadAllText(Path.Join(Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location), "lua", "carcolor.lua")),
            "carcolor.lua",
            new Dictionary<string, object>
            {
                ["changeCooldownSeconds"] = _config.ChangeCooldownSeconds.ToString(CultureInfo.InvariantCulture),
                ["maxHistory"] = _config.MaxHistory.ToString(CultureInfo.InvariantCulture),
                ["maxFavourites"] = _config.MaxFavourites.ToString(CultureInfo.InvariantCulture),
                ["presets"] = Quote(string.Join(",", _config.Presets.Select(p => p.TrimStart('#')))),
                ["bodyMaterialNames"] = Quote(string.Join(",", _config.BodyMaterialNames)),
                ["caliperMaterialNames"] = Quote(string.Join(",", _config.CaliperMaterialNames))
            });

        cspClientMessageTypeManager.RegisterOnlineEvent<CarColorChangePacket>(OnColorChangeReceived);

        _entryCarManager.ClientConnected += OnClientConnected;
        _entryCarManager.ClientDisconnected += OnClientDisconnected;
    }

    private static string Quote(string value) => $"\"{value}\"";

    private void OnClientConnected(ACTcpClient sender, EventArgs args)
    {
        // LuaReady instead of FirstUpdateSent: the client can only receive online events once its scripts are loaded.
        sender.LuaReady += OnLuaReady;
    }

    private void OnLuaReady(ACTcpClient sender, EventArgs args)
    {
        List<CarColorState> colors;
        lock (_lock)
        {
            colors = _playerColors.Values.ToList();
        }

        foreach (var state in colors)
        {
            if (state.SessionId == sender.SessionId) continue;
            sender.SendPacket(CreateUpdate(state));
        }
    }

    private void OnClientDisconnected(ACTcpClient sender, EventArgs args)
    {
        bool removed;
        lock (_lock)
        {
            removed = _playerColors.Remove(sender.SessionId);
        }

        if (removed)
        {
            // Neither body nor caliper set = other clients reset this car to its stock skin.
            _entryCarManager.BroadcastPacket(new CarColorUpdatePacket { SessionId = sender.SessionId });
        }
    }

    private static float SanitizeFinish(float value)
    {
        // Negative (or NaN) means "finish not set / leave unchanged".
        return float.IsNaN(value) || value < 0 ? -1.0f : Math.Clamp(value, 0.0f, 1.0f);
    }

    private static CarColorUpdatePacket CreateUpdate(CarColorState state) => new()
    {
        SessionId = state.SessionId,
        HasBody = state.HasBody,
        Color = state.Color,
        HasCaliper = state.HasCaliper,
        CaliperColor = state.CaliperColor,
        Metallic = state.Metallic,
        Roughness = state.Roughness
    };

    private void OnColorChangeReceived(ACTcpClient client, CarColorChangePacket packet)
    {
        if (_config.AllowedCarModels.Count > 0 && !_config.AllowedCarModels.Contains(client.EntryCar.Model))
            return;

        var now = DateTime.UtcNow;
        var metallic = SanitizeFinish(packet.Metallic);
        var roughness = SanitizeFinish(packet.Roughness);
        // A finish only makes sense when both values are set.
        if (metallic < 0 || roughness < 0)
        {
            metallic = -1.0f;
            roughness = -1.0f;
        }

        CarColorState state;
        lock (_lock)
        {
            if (_playerColors.TryGetValue(client.SessionId, out var lastChange)
                && (now - lastChange.LastChangeTime).TotalSeconds < _config.ChangeCooldownSeconds)
            {
                return;
            }

            state = new CarColorState
            {
                SessionId = client.SessionId,
                HasBody = packet.HasBody,
                Color = packet.Color,
                Metallic = metallic,
                Roughness = roughness,
                HasCaliper = packet.HasCaliper,
                CaliperColor = packet.CaliperColor,
                LastChangeTime = now
            };

            if (!state.HasBody && !state.HasCaliper)
            {
                _playerColors.Remove(client.SessionId);
            }
            else
            {
                _playerColors[client.SessionId] = state;
            }
        }

        Log.Information("{ClientName} ({SessionId}) changed car color (Body: {HasBody} {Color}, Metallic: {Metallic}, Roughness: {Roughness}, Caliper: {HasCaliper} {Caliper})",
            client.Name, client.SessionId, state.HasBody, state.Color, metallic, roughness, state.HasCaliper, state.CaliperColor);

        _entryCarManager.BroadcastPacket(CreateUpdate(state), client);
    }

    public Task StartAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}

public class CarColorState
{
    public byte SessionId { get; set; }
    public bool HasBody { get; set; }
    public System.Drawing.Color Color { get; set; }
    public float Metallic { get; set; }
    public float Roughness { get; set; }
    public bool HasCaliper { get; set; }
    public System.Drawing.Color CaliperColor { get; set; }
    public DateTime LastChangeTime { get; set; }
}

// Client -> server. Field names/types must match the ac.OnlineEvent "AS_CarColor" in lua/carcolor.lua.
[OnlineEvent(Key = "AS_CarColor")]
public class CarColorChangePacket : OnlineEvent<CarColorChangePacket>
{
    [OnlineEventField(Name = "hasBody")]
    public bool HasBody;

    [OnlineEventField(Name = "color")]
    public System.Drawing.Color Color;

    [OnlineEventField(Name = "hasCaliper")]
    public bool HasCaliper;

    [OnlineEventField(Name = "caliperColor")]
    public System.Drawing.Color CaliperColor;

    [OnlineEventField(Name = "metallic")]
    public float Metallic;

    [OnlineEventField(Name = "roughness")]
    public float Roughness;
}

// Server -> clients. The car is identified by the message sender (SessionId). Must match "AS_CarColorUpdate" in lua/carcolor.lua.
[OnlineEvent(Key = "AS_CarColorUpdate")]
public class CarColorUpdatePacket : OnlineEvent<CarColorUpdatePacket>
{
    [OnlineEventField(Name = "hasBody")]
    public bool HasBody;

    [OnlineEventField(Name = "color")]
    public System.Drawing.Color Color;

    [OnlineEventField(Name = "hasCaliper")]
    public bool HasCaliper;

    [OnlineEventField(Name = "caliperColor")]
    public System.Drawing.Color CaliperColor;

    [OnlineEventField(Name = "metallic")]
    public float Metallic;

    [OnlineEventField(Name = "roughness")]
    public float Roughness;
}