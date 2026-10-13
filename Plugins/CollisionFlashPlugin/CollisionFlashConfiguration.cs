using AssettoServer.Server.Configuration;
using JetBrains.Annotations;
using YamlDotNet.Serialization;

namespace CollisionFlashPlugin;

[UsedImplicitly(ImplicitUseKindFlags.Assign, ImplicitUseTargetFlags.WithMembers)]
public class CollisionFlashConfiguration : IValidateConfiguration<CollisionFlashConfigurationValidator>
{
    [YamlMember(Description = "How long the red screen stays visible after the last contact, in seconds")]
    public float DurationSeconds { get; init; } = 0.35f;

    [YamlMember(Description = "Opacity of the red block, 0.0 (invisible) to 1.0 (solid red)")]
    public float Opacity { get; init; } = 0.7f;

    [YamlMember(Description = "First point of the box (top left corner) as a fraction of the screen width, 0.0 = left edge, 1.0 = right edge")]
    public float TopLeftX { get; init; } = 0f;

    [YamlMember(Description = "First point of the box (top left corner) as a fraction of the screen height, 0.0 = top edge, 1.0 = bottom edge")]
    public float TopLeftY { get; init; } = 0f;

    [YamlMember(Description = "Second point of the box (bottom right corner) as a fraction of the screen width, 0.0 = left edge, 1.0 = right edge")]
    public float BottomRightX { get; init; } = 1f;

    [YamlMember(Description = "Second point of the box (bottom right corner) as a fraction of the screen height, 0.0 = top edge, 1.0 = bottom edge")]
    public float BottomRightY { get; init; } = 1f;
}
