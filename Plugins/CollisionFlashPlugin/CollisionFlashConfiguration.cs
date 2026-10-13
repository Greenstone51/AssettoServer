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
}
