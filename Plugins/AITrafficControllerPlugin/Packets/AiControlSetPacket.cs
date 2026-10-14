using AssettoServer.Network.ClientMessages;

namespace AITrafficControllerPlugin.Packets;

// Client -> server. Field names/types must match the ac.OnlineEvent "AS_AiCtrlSet" in lua/aitrafficcontroller.lua.
[OnlineEvent(Key = "AS_AiCtrlSet")]
public class AiControlSetPacket : OnlineEvent<AiControlSetPacket>
{
    [OnlineEventField(Name = "enabled")]
    public bool Enabled;

    [OnlineEventField(Name = "density")]
    public float Density;

    [OnlineEventField(Name = "maxSpeedKph")]
    public float MaxSpeedKph;

    [OnlineEventField(Name = "playerRadius")]
    public float PlayerRadius;

    [OnlineEventField(Name = "perPlayer")]
    public ushort PerPlayer;

    [OnlineEventField(Name = "maxCount")]
    public ushort MaxCount;

    [OnlineEventField(Name = "minSpawn")]
    public ushort MinSpawn;

    [OnlineEventField(Name = "maxSpawn")]
    public ushort MaxSpawn;

    [OnlineEventField(Name = "minSafety")]
    public ushort MinSafety;

    [OnlineEventField(Name = "maxSafety")]
    public ushort MaxSafety;
}
