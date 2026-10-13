using System.Globalization;
using System.Reflection;
using AssettoServer.Server;
using Microsoft.Extensions.Hosting;

namespace CollisionFlashPlugin;

/// <summary>
/// Sends a small client-side Lua script to every player. The script itself detects
/// collisions of the player's own car (other cars, barriers, walls) and draws the red block.
/// The server only delivers the script and its settings.
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
            ["topLeftX"] = configuration.TopLeftX.ToString(CultureInfo.InvariantCulture),
            ["topLeftY"] = configuration.TopLeftY.ToString(CultureInfo.InvariantCulture),
            ["bottomRightX"] = configuration.BottomRightX.ToString(CultureInfo.InvariantCulture),
            ["bottomRightY"] = configuration.BottomRightY.ToString(CultureInfo.InvariantCulture)
        });
    }

    public Task StartAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
