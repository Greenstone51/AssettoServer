using AssettoServer.Server.Plugin;
using Autofac;
using Microsoft.Extensions.Hosting;
using System.Collections.Concurrent;

namespace CollisionFlashPlugin;

public class CollisionFlashModule : AssettoServerModule<CollisionFlashConfiguration>
{
    private readonly ConcurrentDictionary<int, bool> _inPits = new();

    protected override void Load(ContainerBuilder builder)
    {
        builder.RegisterType<CollisionFlashPlugin>().AsSelf().As<IHostedService>().SingleInstance();
    }

    public void SetInPits(int sessionId, bool isInPits)
    {
        _inPits[sessionId] = isInPits;
    }

    public bool IsInPits(int sessionId)
    {
        _inPits.TryGetValue(sessionId, out bool isInPits);
        return isInPits;
    }
}
