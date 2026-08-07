# Testing and Diagnostics

> **Release baseline:** CymBuild 26.3  
> **Validated:** 4 August 2026  
> **Schema deployment baseline:** CYB361_R27 (QA deployment completed with `DeploymentApplied`)  
> **Source basis:** `CymBuild.Monorepo(8).zip`, uploaded schema, and the reviewed CYB361 R22–R27 changes.

Use read-only diagnostics first. Every query below uses explicit columns and the 26.3 source-controlled schema.

## DataObject

```sql
DECLARE @RecordGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

SELECT
    data_object.Guid,
    data_object.EntityTypeId,
    entity_type.Name AS EntityTypeName,
    data_object.RowStatus,
    data_object.RowVersion
FROM SCore.DataObjects AS data_object
LEFT JOIN SCore.EntityTypes AS entity_type
    ON entity_type.ID = data_object.EntityTypeId
WHERE data_object.Guid = @RecordGuid
  AND data_object.RowStatus <> 0
  AND data_object.RowStatus <> 254;
```

## Latest workflow transition

```sql
DECLARE @DataObjectGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

SELECT TOP (1)
    transition.ID,
    transition.Guid,
    transition.DataObjectGuid,
    transition.OldStatusID,
    transition.StatusID,
    workflow_status.Name AS StatusName,
    transition.DateTimeUTC,
    transition.Comment,
    transition.RowStatus
FROM SCore.DataObjectTransition AS transition
LEFT JOIN SCore.WorkflowStatus AS workflow_status
    ON workflow_status.ID = transition.StatusID
WHERE transition.DataObjectGuid = @DataObjectGuid
  AND transition.RowStatus <> 0
  AND transition.RowStatus <> 254
ORDER BY transition.ID DESC;
```

## Integration outbox

```sql
DECLARE @RecordGuidText NVARCHAR(36) = N'00000000-0000-0000-0000-000000000000';

SELECT
    outbox.ID,
    outbox.Guid,
    outbox.EventType,
    outbox.CreatedOnUtc,
    outbox.PublishedOnUtc,
    outbox.PublishAttempts,
    outbox.PublishingToken,
    outbox.PublishingStartedOnUtc,
    outbox.LastError,
    outbox.RowStatus
FROM SCore.IntegrationOutbox AS outbox
WHERE outbox.RowStatus <> 0
  AND outbox.RowStatus <> 254
  AND outbox.PayloadJson LIKE N'%' + @RecordGuidText + N'%'
ORDER BY outbox.ID DESC;
```

## Grid and columns

```sql
DECLARE @GridCode NVARCHAR(30) = N'<GRID-CODE>';

SELECT
    grid.ID,
    grid.Guid,
    grid.Code,
    grid.PageUri,
    grid.TabName,
    grid.RowStatus
FROM SUserInterface.GridDefinitions AS grid
WHERE grid.Code = @GridCode
  AND grid.RowStatus <> 0
  AND grid.RowStatus <> 254;

DECLARE @GridViewDefinitionId INT = -1;

SELECT
    grid_column.ID,
    grid_column.Guid,
    grid_column.Name,
    grid_column.ColumnOrder,
    grid_column.GridViewDefinitionId,
    grid_column.IsHidden,
    grid_column.IsFiltered,
    grid_column.DisplayFormat,
    grid_column.Width,
    grid_column.RowStatus
FROM SUserInterface.GridViewColumnDefinitions AS grid_column
WHERE grid_column.GridViewDefinitionId = @GridViewDefinitionId
  AND grid_column.RowStatus <> 0
  AND grid_column.RowStatus <> 254
ORDER BY grid_column.ColumnOrder, grid_column.ID;
```

## Schema migration run and audit

```sql
DECLARE @RunGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

SELECT
    run.Guid,
    run.SourceEnvironment,
    run.TargetEnvironment,
    run.SourceDatabaseName,
    run.TargetDatabaseName,
    run.ReleaseReference,
    run.RunStatus,
    run.IsReviewed,
    run.ComparedOnUtc,
    run.ValidatedOnUtc,
    run.ReviewedOnUtc,
    run.AppliedOnUtc,
    run.DeploymentReference,
    run.Notes
FROM SMigration.Schema_Run AS run
WHERE run.Guid = @RunGuid
  AND run.RowStatus <> 0
  AND run.RowStatus <> 254;

SELECT
    execution_log.ID,
    execution_log.Guid,
    execution_log.StepName,
    execution_log.StepStatus,
    execution_log.Message,
    execution_log.CreatedOnUtc
FROM SMigration.Schema_ExecutionLog AS execution_log
WHERE execution_log.RunGuid = @RunGuid
  AND execution_log.RowStatus <> 0
  AND execution_log.RowStatus <> 254
ORDER BY execution_log.ID;
```

## Metadata migration run and audit

```sql
DECLARE @MetadataRunGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

SELECT
    run.Guid,
    run.SourceEnvironment,
    run.TargetEnvironment,
    run.RunStatus,
    run.IsValidateOnly,
    run.CreatedOnUtc,
    run.ValidatedOnUtc,
    run.AppliedOnUtc
FROM SMigration.Metadata_Run AS run
WHERE run.Guid = @MetadataRunGuid
  AND run.RowStatus <> 0
  AND run.RowStatus <> 254;

SELECT
    execution_log.ID,
    execution_log.StepName,
    execution_log.StepStatus,
    execution_log.Message,
    execution_log.CreatedOnUtc
FROM SMigration.Metadata_ExecutionLog AS execution_log
WHERE execution_log.RunGuid = @MetadataRunGuid
  AND execution_log.RowStatus <> 0
  AND execution_log.RowStatus <> 254
ORDER BY execution_log.ID;
```

Only provide remediation SQL after confirming the exact target schema and root cause. Remediation must be idempotent, non-destructive, DataObjects-compliant and environment-appropriate.
