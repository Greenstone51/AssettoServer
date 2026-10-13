using System.Text.Json.Serialization;
using AssettoServer.Server.Configuration;

namespace CarColorPlugin;

public class CarColorConfiguration : IValidateConfiguration<CarColorConfigurationValidator>
{
    [JsonPropertyName("presets")]
    public List<string> Presets { get; set; } = new()
    {
        "#FF0000", "#00FF00", "#0000FF", "#FFFF00",
        "#FF00FF", "#00FFFF", "#FFA500", "#800080",
        "#008000", "#000080", "#808080", "#FFFFFF"
    };

    [JsonPropertyName("bodyMaterialNames")]
    public List<string> BodyMaterialNames { get; set; } = new()
    {
        "carpaint", "body", "paint"
    };

    [JsonPropertyName("caliperMaterialNames")]
    public List<string> CaliperMaterialNames { get; set; } = new()
    {
        "caliper", "brake", "disc"
    };

    [JsonPropertyName("allowedCarModels")]
    public List<string> AllowedCarModels { get; set; } = new();

    [JsonPropertyName("changeCooldownSeconds")]
    [JsonNumberHandling(JsonNumberHandling.AllowReadingFromString)]
    public float ChangeCooldownSeconds { get; set; } = 1.0f;

    [JsonPropertyName("maxHistory")]
    public int MaxHistory { get; set; } = 10;

    [JsonPropertyName("maxFavourites")]
    public int MaxFavourites { get; set; } = 50;
}
