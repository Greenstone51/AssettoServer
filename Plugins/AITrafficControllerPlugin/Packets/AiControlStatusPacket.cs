using AssettoServer.Network.ClientMessages;

namespace AITrafficControllerPlugin.Packets;

// Server -> client. Field names/types must match the ac.OnlineEvent "AS_AiCtrlStatus" in lua/aitrafficcontroller.lua.
[OnlineEvent(Key = "AS_AiCtrlStatus")]
public class AiControlStatusPacket : OnlineEvent<AiControlStatusPacket>
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

    [OnlineEventField(Name = "activeStates")]
    public ushort ActiveStates;
}
