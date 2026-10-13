using AssettoServer.Server.Plugin;
using Autofac;
using Microsoft.Extensions.Hosting;

namespace CarColorPlugin;

public class CarColorPluginModule : AssettoServerModule<CarColorConfiguration>
{
    protected override void Load(ContainerBuilder builder)
    {
        builder.RegisterType<CarColorPlugin>().AsSelf().As<IHostedService>().SingleInstance();
    }
}
