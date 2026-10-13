namespace AssettoServer.Network.ClientMessages;

[OnlineEvent(Key = "AS_ToggleUi")]
public class ToggleUiPacket : OnlineEvent<ToggleUiPacket>
{
    // Empty or "all" = every plugin UI, otherwise the plugin's UI id (e.g. "collisionflash")
    [OnlineEventField(Name = "target", Size = 16)]
    public string Target = "";
}
