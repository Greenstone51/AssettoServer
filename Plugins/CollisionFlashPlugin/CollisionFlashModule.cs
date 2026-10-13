using AssettoServer.Server.Plugin;
using Autofac;
using Microsoft.Extensions.Hosting;

namespace CollisionFlashPlugin;

public class CollisionFlashModule : AssettoServerModule<CollisionFlashConfiguration>
{
    protected override void Load(ContainerBuilder builder)
    {
        builder.RegisterType<CollisionFlashPlugin>().AsSelf().As<IHostedService>().SingleInstance();
    }
}
