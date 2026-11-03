using Xunit;

namespace CymBuild.Architecture.Tests;

// CYB-515 (LIVE 26.2 commit 52eb8f94 / CB262_WFN_R1, missing from release/26.4): workflow
// notifications must never fail silently. The enqueue procedure reports an explicit outcome, the
// API treats only Enqueued/AlreadyEnqueued (success) and NotLatestTransition/NotificationDisabled
// (terminal no-send) as complete and retries anything else, and the transition triggers log
// non-enqueued outcomes to SCore.WorkflowNotificationQueueErrorLog.
public sealed class Cyb515WorkflowNotificationOutcomeSourceContractTests
{
    [Fact]
    public void EnqueueProcedure_ReportsAnOutcomeOnEveryPath()
    {
        var sql = Read("Database", "CymBuild_DB", "Schema", "Programmability", "Procedures",
            "SCore.IntegrationOutbox_EnqueueWorkflowStatusNotification.sql");

        Assert.Contains("@OutcomeCode NVARCHAR(64) = NULL OUTPUT", sql, StringComparison.Ordinal);
        Assert.Contains("@OutcomeMessage NVARCHAR(2000) = NULL OUTPUT", sql, StringComparison.Ordinal);
        Assert.Contains("@OutboxId BIGINT = NULL OUTPUT", sql, StringComparison.Ordinal);

        foreach (var code in new[]
                 {
                     "TransitionNotFound", "LatestTransitionNotFound", "NotLatestTransition", "NotificationDisabled",
                     "AlreadyEnqueued", "StatusNotFound", "RoutingNotResolved", "WorkflowNotResolved",
                     "NotificationGroupsNotConfigured", "Enqueued",
                 })
        {
            Assert.Contains($"SET @OutcomeCode = N'{code}';", sql, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void OutboxRepository_RetriesAnythingThatWasNotEnqueuedOrDeliberatelySkipped()
    {
        var source = Read("services", "Concursus.API", "Services", "Outbox", "WorkflowOutboxRepository.cs");

        Assert.Contains("new SqlParameter(\"@OutcomeCode\", SqlDbType.NVarChar, 64)", source, StringComparison.Ordinal);
        Assert.Contains("Direction = ParameterDirection.Output", source, StringComparison.Ordinal);
        Assert.Contains("case \"Enqueued\":", source, StringComparison.Ordinal);
        Assert.Contains("case \"AlreadyEnqueued\":", source, StringComparison.Ordinal);
        Assert.Contains("case \"NotLatestTransition\":", source, StringComparison.Ordinal);
        Assert.Contains("case \"NotificationDisabled\":", source, StringComparison.Ordinal);
        Assert.Contains("throw new InvalidOperationException(", source, StringComparison.Ordinal);
    }

    [Fact]
    public void UpgradeScript_ShipsTheTriggerDiagnosticsAndIsIdempotent()
    {
        var sql = Read("Database", "CymBuild_DB", "Scripts", "Upgrade Scripts",
            "CYB-515_26.4_WorkflowNotificationOutcomes.sql");

        Assert.Contains("CREATE OR ALTER PROCEDURE [SCore].[IntegrationOutbox_EnqueueWorkflowStatusNotification]", sql, StringComparison.Ordinal);
        Assert.Contains("CREATE OR ALTER TRIGGER [SCore].[tr_DataObjectTransition_EnqueueWorkflowStatusNotification]", sql, StringComparison.Ordinal);
        Assert.Contains("CREATE OR ALTER TRIGGER [SCore].[tr_DataObjectTransition_QueueWorkflowNotifications]", sql, StringComparison.Ordinal);
        Assert.Contains("@OutcomeCode = @OutcomeCode OUTPUT", sql, StringComparison.Ordinal);
        Assert.Contains("INSERT INTO SCore.WorkflowNotificationQueueErrorLog", sql, StringComparison.Ordinal);
        Assert.DoesNotContain("ADD CONSTRAINT", sql, StringComparison.OrdinalIgnoreCase);
    }

    private static string Read(params string[] parts) => File.ReadAllText(RepositoryLayout.PathFromRoot(parts));
}
