using AssettoServer.Network.ClientMessages;

namespace AITrafficControllerPlugin.Packets;

[OnlineEvent(Key = "AS_AiCtrlSet")]
public class AiControlSetPacket : OnlineEvent<AiControlSetPacket>
{
    [OnlineEventField(Name = "enabled")]
    public bool? Enabled { get; set; }

    [OnlineEventField(Name = "density")]
    public float? Density { get; set; }

    [OnlineEventField(Name = "maxSpeedKph")]
    public float? MaxSpeedKph { get; set; }

    [OnlineEventField(Name = "playerRadius")]
    public float? PlayerRadius { get; set; }

    [OnlineEventField(Name = "perPlayer")]
    public ushort? PerPlayer { get; set; }

    [OnlineEventField(Name = "maxCount")]
    public ushort? MaxCount { get; set; }

    [OnlineEventField(Name = "minSpawn")]
    public ushort? MinSpawn { get; set; }

    [OnlineEventField(Name = "maxSpawn")]
    public ushort? MaxSpawn { get; set; }

    [OnlineEventField(Name = "minSafety")]
    public ushort? MinSafety { get; set; }

    [OnlineEventField(Name = "maxSafety")]
    public ushort? MaxSafety { get; set; }
}
