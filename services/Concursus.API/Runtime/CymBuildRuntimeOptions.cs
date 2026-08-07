namespace Concursus.API.Runtime;

/// <summary>
/// Controls which runtime responsibilities are enabled in the Concursus API host.
/// The default remains <see cref="CymBuildRuntimeMode.Combined"/> to preserve
/// the existing non-Kubernetes behaviour.
/// </summary>
public sealed class CymBuildRuntimeOptions
{
    public const string SectionName = "CymBuildRuntime";

    /// <summary>
    /// Gets or sets the process runtime mode.
    /// </summary>
    public CymBuildRuntimeMode Mode { get; set; } = CymBuildRuntimeMode.Combined;

    /// <summary>
    /// Gets or sets the single worker role used when <see cref="Mode"/> is
    /// <see cref="CymBuildRuntimeMode.Worker"/>.
    /// </summary>
    public CymBuildWorkerRole WorkerRole { get; set; } = CymBuildWorkerRole.None;
}

public enum CymBuildRuntimeMode
{
    Combined = 0,
    ApiOnly = 1,
    Worker = 2
}

public enum CymBuildWorkerRole
{
    None = 0,
    InvoiceAutomation = 1,
    WorkflowOutbox = 2,
    SharePointRepair = 3,
    SageSubmission = 4,
    SageInbound = 5
}
