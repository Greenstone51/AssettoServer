using System.Reflection;
using AITrafficControllerPlugin.Packets;
using AssettoServer.Network.ClientMessages;
using AssettoServer.Network.Tcp;
using AssettoServer.Server;
using AssettoServer.Server.Ai;
using AssettoServer.Server.Configuration;
using AssettoServer.Server.Configuration.Extra;
using Microsoft.Extensions.Hosting;
using Serilog;

namespace AITrafficControllerPlugin;

public class AITrafficControllerPlugin : IHostedService
{
    private readonly AITrafficControllerConfiguration _config;
    private readonly EntryCarManager _entryCarManager;
    private readonly AiParams _aiParams;
    private readonly AiControlSetPacket _original;
    private readonly object _lock = new();
    private bool _enabled;

    public AITrafficControllerPlugin(AITrafficControllerConfiguration config,
        EntryCarManager entryCarManager,
        CSPServerScriptProvider scriptProvider,
        CSPClientMessageTypeManager cspClientMessageTypeManager,
        ACServerConfiguration serverConfig)
    {
        _config = config;
        _entryCarManager = entryCarManager;
        _aiParams = serverConfig.Extra.AiParams;

        if (!serverConfig.Extra.EnableClientMessages)
        {
            throw new ConfigurationException("EnableClientMessages must be true for AITrafficControllerPlugin");
        }

        // Remember the configured values so that "disabled" restores them.
        _original = ReadCurrent();

        scriptProvider.AddScript(
            File.ReadAllText(Path.Join(Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location), "lua", "aitrafficcontroller.lua")),
            "aitrafficcontroller.lua",
            new Dictionary<string, object>
            {
                ["requireAdmin"] = _config.RequireAdmin ? "true" : "false"
            });

        cspClientMessageTypeManager.RegisterOnlineEvent<AiControlSetPacket>(OnSetReceived);
        _entryCarManager.ClientConnected += (client, _) => client.LuaReady += OnLuaReady;
    }

    private AiControlSetPacket ReadCurrent() => new()
    {
        Enabled = true,
        Density = _aiParams.TrafficDensity,
        MaxSpeedKph = _aiParams.MaxSpeedKph,
        PlayerRadius = _aiParams.PlayerRadiusMeters,
        PerPlayer = (ushort)Math.Clamp(_aiParams.AiPerPlayerTargetCount, 0, ushort.MaxValue),
        MaxCount = (ushort)Math.Clamp(_aiParams.MaxAiTargetCount, 0, ushort.MaxValue),
        MinSpawn = (ushort)Math.Clamp(_aiParams.MinSpawnDistancePoints, 0, ushort.MaxValue),
        MaxSpawn = (ushort)Math.Clamp(_aiParams.MaxSpawnDistancePoints, 0, ushort.MaxValue),
        MinSafety = (ushort)Math.Clamp(_aiParams.MinAiSafetyDistanceMeters, 0, ushort.MaxValue),
        MaxSafety = (ushort)Math.Clamp(_aiParams.MaxAiSafetyDistanceMeters, 0, ushort.MaxValue)
    };

    private void Apply(AiControlSetPacket p)
    {
        _aiParams.TrafficDensity = p.Density;
        _aiParams.MaxSpeedKph = p.MaxSpeedKph;
        _aiParams.PlayerRadiusMeters = p.PlayerRadius;
        _aiParams.AiPerPlayerTargetCount = p.PerPlayer;
        _aiParams.MaxAiTargetCount = p.MaxCount;
        _aiParams.MinSpawnDistancePoints = p.MinSpawn;
        _aiParams.MaxSpawnDistancePoints = p.MaxSpawn;
        _aiParams.MinAiSafetyDistanceMeters = p.MinSafety;
        _aiParams.MaxAiSafetyDistanceMeters = p.MaxSafety;
    }

    private void OnSetReceived(ACTcpClient client, AiControlSetPacket packet)
    {
        if (_config.RequireAdmin && !client.IsAdministrator)
            return;

        // Density 0 would divide by zero in AiState safety distance calculation.
        if (float.IsNaN(packet.Density) || float.IsNaN(packet.MaxSpeedKph) || float.IsNaN(packet.PlayerRadius))
            return;

        var requested = new AiControlSetPacket
        {
            Enabled = packet.Enabled,
            Density = Math.Clamp(packet.Density, 0.05f, 2.0f),
            MaxSpeedKph = Math.Clamp(packet.MaxSpeedKph, 5.0f, 300.0f),
            PlayerRadius = Math.Clamp(packet.PlayerRadius, 50.0f, 2000.0f),
            PerPlayer = Math.Min(packet.PerPlayer, (ushort)50),
            MaxCount = Math.Min(packet.MaxCount, (ushort)500),
            MinSpawn = Math.Min(packet.MinSpawn, packet.MaxSpawn),
            MaxSpawn = Math.Min(Math.Max(packet.MinSpawn, packet.MaxSpawn), (ushort)2000),
            MinSafety = Math.Min(packet.MinSafety, packet.MaxSafety),
            MaxSafety = Math.Min(Math.Max(packet.MinSafety, packet.MaxSafety), (ushort)1000)
        };

        lock (_lock)
        {
            _enabled = requested.Enabled;
            Apply(_enabled ? requested : _original);
        }

        Log.Information("{ClientName} ({SessionId}) set AI traffic controller (Enabled: {Enabled}, Density: {Density}, MaxSpeedKph: {Speed})",
            client.Name, client.SessionId, requested.Enabled, requested.Density, requested.MaxSpeedKph);

        foreach (var car in _entryCarManager.EntryCars)
        {
            var target = car.Client;
            if (target != null && (!_config.RequireAdmin || target.IsAdministrator))
            {
                target.SendPacket(CreateStatus());
            }
        }
    }

    private void OnLuaReady(ACTcpClient sender, EventArgs args)
    {
        if (_config.RequireAdmin && !sender.IsAdministrator)
            return;

        sender.SendPacket(CreateStatus());
    }

    private AiControlStatusPacket CreateStatus()
    {
        var current = ReadCurrent();
        bool enabled;
        lock (_lock)
        {
            enabled = _enabled;
        }

        var active = 0;
        var states = new List<AiState>();
        foreach (var car in _entryCarManager.EntryCars)
        {
            if (!car.AiControlled) continue;
            states.Clear();
            car.GetInitializedStates(states);
            active += states.Count;
        }

        return new AiControlStatusPacket
        {
            Enabled = enabled,
            Density = current.Density,
            MaxSpeedKph = current.MaxSpeedKph,
            PlayerRadius = current.PlayerRadius,
            PerPlayer = current.PerPlayer,
            MaxCount = current.MaxCount,
            MinSpawn = current.MinSpawn,
            MaxSpawn = current.MaxSpawn,
            MinSafety = current.MinSafety,
            MaxSafety = current.MaxSafety,
            ActiveStates = (ushort)Math.Min(active, ushort.MaxValue)
        };
    }

    public Task StartAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
