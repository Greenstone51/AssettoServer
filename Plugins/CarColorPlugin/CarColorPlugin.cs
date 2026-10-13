using AssettoServer.Network.ClientMessages;
using AssettoServer.Server;
using AssettoServer.Shared.Network.Packets.Outgoing;
using CSP;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace CarColorPlugin;

public class CarColorPlugin : BackgroundService, IHostedService
{
    private readonly ILogger<CarColorPlugin> _logger;
    private readonly CSPServerScriptProvider _scriptProvider;
    private readonly IOnlineEventManager _onlineEventManager;
    private readonly CarColorConfiguration _config;
    private readonly Dictionary<ulong, ColorData> _playerColors = new();
    private readonly Dictionary<ulong, DateTime> _lastColorChange = new();

    public CarColorPlugin(
        ILogger<CarColorPlugin> logger,
        CSPServerScriptProvider scriptProvider,
        IOnlineEventManager onlineEventManager,
        IHostApplicationLifetime lifetime,
        CarColorConfiguration config)
    {
        _logger = logger;
        _scriptProvider = scriptProvider;
        _onlineEventManager = onlineEventManager;
        _config = config;
        Lifetime = lifetime;
    }

    public IHostApplicationLifetime Lifetime { get; }

    public override async Task StartAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("CarColorPlugin starting");

        // Register client message handler
        _onlineEventManager.RegisterHandler<CarColorChangePacket>(OnColorChangeReceived);

        // Send initial colors to all connected players
        BroadcastCurrentColors();

        await base.StartAsync(cancellationToken);
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("CarColorPlugin stopping");
        await base.StopAsync(cancellationToken);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await Task.Delay(1000, stoppingToken);
        }
    }

    private void OnColorChangeReceived(CarColorChangePacket packet, ACTcpClient client)
    {
        var guid = client.Guid;

        // Rate limiting
        if (_lastColorChange.TryGetValue(guid, out var lastChange))
        {
            var elapsed = DateTime.UtcNow - lastChange;
            if (elapsed.TotalSeconds < _config.ChangeCooldownSeconds)
            {
                _logger.LogWarning($"Player {guid} tried to change color too quickly");
                return;
            }
        }

        _lastColorChange[guid] = DateTime.UtcNow;
        _playerColors[guid] = packet.Color;

        _logger.LogInformation($"Player {guid} changed color to {packet.Color}");

        // Broadcast to all other clients
        BroadcastColorToOthers(guid, packet.Color);
    }

    private void BroadcastColorToOthers(ulong senderGuid, ColorData color)
    {
        var packet = new CarColorUpdatePacket
        {
            SenderGuid = senderGuid,
            Color = color
        };

        _onlineEventManager.Broadcast(packet);
    }

    private void BroadcastCurrentColors()
    {
        foreach (var kvp in _playerColors)
        {
            BroadcastColorToOthers(kvp.Key, kvp.Value);
        }
    }

    public void OnClientConnected(ACTcpClient client)
    {
        // Send stored color if available
        if (_playerColors.TryGetValue(client.Guid, out var color))
        {
            BroadcastColorToOthers(client.Guid, color);
        }
    }

    public void OnClientDisconnected(ACTcpClient client)
    {
        _playerColors.Remove(client.Guid);
        _lastColorChange.Remove(client.Guid);
    }
}

public record ColorData(byte R, byte G, byte B);

[OnlineEvent(Key = "AS_CarColor")]
public class CarColorChangePacket : OnlineEvent<CarColorChangePacket>
{
    public ColorData Color { get; set; }

    public override void FromReader(PacketReader reader)
    {
        Color = new ColorData(
            reader.ReadByte(),
            reader.ReadByte(),
            reader.ReadByte()
        );
    }

    public override void ToWriter(ref PacketWriter writer)
    {
        writer.Write(Color.R);
        writer.Write(Color.G);
        writer.Write(Color.B);
    }
}

[OnlineEvent(Key = "AS_CarColorUpdate")]
public class CarColorUpdatePacket : OnlineEvent<CarColorUpdatePacket>
{
    public ulong SenderGuid { get; set; }
    public ColorData Color { get; set; }

    public override void FromReader(PacketReader reader)
    {
        SenderGuid = reader.ReadUInt64();
        Color = new ColorData(
            reader.ReadByte(),
            reader.ReadByte(),
            reader.ReadByte()
        );
    }

    public override void ToWriter(ref PacketWriter writer)
    {
        writer.Write(SenderGuid);
        writer.Write(Color.R);
        writer.Write(Color.G);
        writer.Write(Color.B);
    }
}
