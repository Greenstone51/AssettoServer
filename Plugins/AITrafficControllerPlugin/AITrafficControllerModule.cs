using AssettoServer.Server.Plugin;
using Autofac;
using Microsoft.Extensions.Hosting;

namespace AITrafficControllerPlugin;

public class AITrafficControllerModule : AssettoServerModule<AITrafficControllerConfiguration>
{
    protected override void Load(ContainerBuilder builder)
    {
        builder.RegisterType<AITrafficControllerPlugin>().AsSelf().As<IHostedService>().SingleInstance();
    }
}
