using AssettoServer.Server.Configuration;
using JetBrains.Annotations;
using YamlDotNet.Serialization;

namespace AITrafficControllerPlugin;

[UsedImplicitly(ImplicitUseKindFlags.Assign, ImplicitUseTargetFlags.WithMembers)]
public class AITrafficControllerConfiguration : IValidateConfiguration<AITrafficControllerConfigurationValidator>
{
    [YamlMember(Description = "Only server administrators can change AI traffic settings")]
    public bool RequireAdmin { get; init; } = true;
}
