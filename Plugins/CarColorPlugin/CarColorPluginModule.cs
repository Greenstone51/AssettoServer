using AssettoServer.Server.Plugin;
using Microsoft.Extensions.DependencyInjection;

namespace CarColorPlugin;

[UsedImplicitly(ImplicitUseTargetFlags.WithInheritors)]
public class CarColorPluginModule : AssettoServerModule<CarColorConfiguration>
{
    public override void ConfigureServices(IServiceCollection services)
    {
        services.AddSingleton<CarColorPlugin>();
    }

    public override void OnStart()
    {
        var plugin = Services.GetRequiredService<CarColorPlugin>();
        plugin.Start();
    }

    public override void OnStop()
    {
        var plugin = Services.GetRequiredService<CarColorPlugin>();
        plugin.Stop();
    }
}
