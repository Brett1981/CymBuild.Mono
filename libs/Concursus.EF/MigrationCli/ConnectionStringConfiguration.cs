using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Primitives;

namespace Concursus.EF.MigrationCli;

/// <summary>
/// Minimal <see cref="IConfiguration"/> exposing only ConnectionStrings:DefaultConnection, so the
/// migration repositories can be constructed from a console tool without the configuration
/// builder packages. The repositories treat the string as a template and replace the server and
/// database on every open, so it supplies only authentication and TLS settings.
/// </summary>
public sealed class ConnectionStringConfiguration : IConfiguration
{
    private readonly Dictionary<string, string?> _values;

    public ConnectionStringConfiguration(string defaultConnection)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(defaultConnection);
        _values = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase)
        {
            ["ConnectionStrings:DefaultConnection"] = defaultConnection
        };
    }

    /// <summary>Integrated-security template for <paramref name="server"/>/<paramref name="database"/>.</summary>
    public static ConnectionStringConfiguration ForIntegratedSecurity(string server, string database) =>
        new($"Data Source={server};Initial Catalog={database};Integrated Security=True;TrustServerCertificate=True;Application Name=CymBuild Migration CLI");

    public string? this[string key]
    {
        get => _values.TryGetValue(key, out var value) ? value : null;
        set => _values[key] = value;
    }

    public IConfigurationSection GetSection(string key) => new Section(this, key);

    public IEnumerable<IConfigurationSection> GetChildren() => [GetSection("ConnectionStrings")];

    public IChangeToken GetReloadToken() => NullChangeToken.Instance;

    private sealed class Section(ConnectionStringConfiguration root, string path) : IConfigurationSection
    {
        public string? this[string key]
        {
            get => root[$"{path}:{key}"];
            set => root[$"{path}:{key}"] = value;
        }

        public string Key => path.Split(':')[^1];
        public string Path => path;
        public string? Value { get => root[path]; set => root[path] = value; }
        public IConfigurationSection GetSection(string key) => new Section(root, $"{path}:{key}");
        public IEnumerable<IConfigurationSection> GetChildren() => [];
        public IChangeToken GetReloadToken() => NullChangeToken.Instance;
    }

    private sealed class NullChangeToken : IChangeToken
    {
        public static readonly NullChangeToken Instance = new();
        public bool HasChanged => false;
        public bool ActiveChangeCallbacks => false;
        public IDisposable RegisterChangeCallback(Action<object?> callback, object? state) => EmptyDisposable.Instance;
    }

    private sealed class EmptyDisposable : IDisposable
    {
        public static readonly EmptyDisposable Instance = new();
        public void Dispose() { }
    }
}
