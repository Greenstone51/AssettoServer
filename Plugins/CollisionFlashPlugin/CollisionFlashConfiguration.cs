using AssettoServer.Server.Configuration;
using JetBrains.Annotations;
using YamlDotNet.Serialization;

namespace CollisionFlashPlugin;

[UsedImplicitly(ImplicitUseKindFlags.Assign, ImplicitUseTargetFlags.WithMembers)]
public class CollisionFlashConfiguration : IValidateConfiguration<CollisionFlashConfigurationValidator>
{
    [YamlMember(Description = "Default for how long the red block stays visible after the last contact, in seconds. Players can change this in their own in-game UI")]
    public float DurationSeconds { get; init; } = 0.35f;

    [YamlMember(Description = "Default opacity of the red block, 0.0 (invisible) to 1.0 (solid red). Players can change this in their own in-game UI")]
    public float Opacity { get; init; } = 0.7f;

    [YamlMember(Description = "Keep the red block permanently visible while the car is in the pits (instead of only flashing on collisions). Players can change this in their own in-game UI")]
    public bool ShowInPits { get; init; } = false;

    [YamlMember(Description = "Keep the red block permanently visible when the car speed is below the speed limit. Players can change this in their own in-game UI")]
    public bool KeepVisibleUnderSpeed { get; init; } = false;

    [YamlMember(Description = "Speed limit in km/h below which the red block stays visible. Players can change this in their own in-game UI")]
    public float SpeedLimitKph { get; init; } = 30f;
}
