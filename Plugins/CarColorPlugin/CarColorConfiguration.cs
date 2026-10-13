using System.Text.Json.Serialization;

namespace CarColorPlugin;

public class CarColorConfiguration
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

    [JsonPropertyName("allowedCarModels")]
    public List<string> AllowedCarModels { get; set; } = new();

    [JsonPropertyName("changeCooldownSeconds")]
    [JsonNumberHandling(JsonNumberHandling.AllowReadingFromString)]
    public float ChangeCooldownSeconds { get; set; } = 1.0f;
}
