using System.Globalization;
using System.Reflection;
using AssettoServer.Server;
using Microsoft.Extensions.Hosting;

namespace CollisionFlashPlugin;

/// <summary>
/// Sends a small client-side Lua script to every player. The script detects collisions of the
/// player's own car and draws the red block. Box position and size are set by each player
/// in their own in-game UI; the server only delivers the script and default values.
/// </summary>
public class CollisionFlashPlugin : IHostedService
{
    public CollisionFlashPlugin(CollisionFlashConfiguration configuration, CSPServerScriptProvider scriptProvider)
    {
        var luaPath = Path.Join(Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location), "lua", "collisionflash.lua");

        using var streamReader = new StreamReader(luaPath);
        var script = streamReader.ReadToEnd();

        scriptProvider.AddScript(script, "collisionflash.lua", new Dictionary<string, object>
        {
            ["durationSeconds"] = configuration.DurationSeconds.ToString(CultureInfo.InvariantCulture),
            ["opacity"] = configuration.Opacity.ToString(CultureInfo.InvariantCulture),
            // CSP only understands lowercase booleans; bool.ToString() would send "True"/"False"
            ["showInPits"] = configuration.ShowInPits ? "true" : "false"
        });
    }

    public Task StartAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
