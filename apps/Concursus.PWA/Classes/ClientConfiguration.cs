namespace Concursus.PWA.Classes
{
    public sealed class ClientConfiguration
    {
        public VersioningConfiguration Versioning { get; set; } = new();
        public EnvironmentConfiguration Environment { get; set; } = new();
    }

    public sealed class VersioningConfiguration
    {
        public string EFVersion { get; set; } = string.Empty;
        public string PWAVersion { get; set; } = string.Empty;
    }

    public sealed class EnvironmentConfiguration
    {
        public string Type { get; set; } = string.Empty;
        public bool ShowDocumentsTab { get; set; }
    }
}
