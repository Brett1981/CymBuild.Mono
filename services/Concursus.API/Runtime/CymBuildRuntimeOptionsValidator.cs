using Microsoft.Extensions.Options;

namespace Concursus.API.Runtime;

public sealed class CymBuildRuntimeOptionsValidator : IValidateOptions<CymBuildRuntimeOptions>
{
    public ValidateOptionsResult Validate(string? name, CymBuildRuntimeOptions options)
    {
        ArgumentNullException.ThrowIfNull(options);

        var failures = ValidateCore(options);
        return failures.Count == 0
            ? ValidateOptionsResult.Success
            : ValidateOptionsResult.Fail(failures);
    }

    internal static IReadOnlyCollection<string> ValidateCore(CymBuildRuntimeOptions options)
    {
        ArgumentNullException.ThrowIfNull(options);

        var failures = new List<string>();

        if (!Enum.IsDefined(options.Mode))
        {
            failures.Add($"CymBuildRuntime:Mode value '{options.Mode}' is not supported.");
        }

        if (!Enum.IsDefined(options.WorkerRole))
        {
            failures.Add($"CymBuildRuntime:WorkerRole value '{options.WorkerRole}' is not supported.");
        }

        if (failures.Count > 0)
        {
            return failures;
        }

        switch (options.Mode)
        {
            case CymBuildRuntimeMode.Combined:
            case CymBuildRuntimeMode.ApiOnly:
                if (options.WorkerRole != CymBuildWorkerRole.None)
                {
                    failures.Add(
                        $"CymBuildRuntime:WorkerRole must be '{CymBuildWorkerRole.None}' when Mode is '{options.Mode}'.");
                }

                break;

            case CymBuildRuntimeMode.Worker:
                if (options.WorkerRole == CymBuildWorkerRole.None)
                {
                    failures.Add(
                        "CymBuildRuntime:WorkerRole must identify exactly one worker when Mode is 'Worker'.");
                }

                break;
        }

        return failures;
    }
}
