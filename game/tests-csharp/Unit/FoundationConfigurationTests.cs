using System.Text.Json;
using System.Xml.Linq;
using Xunit;

namespace Oozeborne.UnitTests;

public sealed class FoundationConfigurationTests
{
    [Fact]
    public void ToolchainAndGodotSdkArePinnedToValidatedVersions()
    {
        using var globalJson = JsonDocument.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "global.json")));
        var sdkVersion = globalJson.RootElement.GetProperty("sdk").GetProperty("version").GetString();
        var project = XDocument.Load(Path.Combine(AppContext.BaseDirectory, "NewGame.csproj"));

        Assert.Equal("8.0.401", sdkVersion);
        Assert.Equal("Godot.NET.Sdk/4.6.2", project.Root?.Attribute("Sdk")?.Value);
        Assert.Equal("net8.0", project.Descendants("TargetFramework").First().Value);
    }

    [Fact]
    public void SanitizedValidJsonFixturesParse()
    {
        var fixtures = Path.Combine(AppContext.BaseDirectory, "Fixtures");
        var validJsonFiles = Directory.GetFiles(fixtures, "*.json", SearchOption.AllDirectories)
            .Where(path => !path.Contains($"{Path.DirectorySeparatorChar}Invalid{Path.DirectorySeparatorChar}", StringComparison.Ordinal))
            .ToArray();

        Assert.NotEmpty(validJsonFiles);
        foreach (var path in validJsonFiles)
        {
            using var _ = JsonDocument.Parse(File.ReadAllText(path));
        }
    }

    [Fact]
    public void NonFiniteNetworkFixtureIsRejectedByStrictJsonParser()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "Fixtures", "Network", "Invalid", "non-finite-number.json");
        Assert.ThrowsAny<JsonException>(() => JsonDocument.Parse(File.ReadAllText(path)));
    }
}
