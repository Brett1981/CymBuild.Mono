using Concursus.EF.MetadataManifests.ValidateOnly.Cli;

using var cts = new CancellationTokenSource();
Console.CancelKeyPress += (_, e) =>
{
    e.Cancel = true;
    cts.Cancel();
};

try
{
    // Dispatch to the ValidateOnly CLI implemented in the EF library.
    var exitCode = await MetadataValidateCli.RunAsync(args, cts.Token);
    Environment.ExitCode = exitCode;
}
catch (OperationCanceledException)
{
    Console.Error.WriteLine("Cancelled.");
    Environment.ExitCode = 4;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Unhandled error: {ex.Message}");
    Environment.ExitCode = 4;
}
