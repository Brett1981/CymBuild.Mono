SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataRun_Get]')
GO

CREATE PROCEDURE [SMigration].[MetadataRun_Get]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        r.ID,
        r.Guid,
        r.RowStatus,
        r.SourceEnvironment,
        r.TargetEnvironment,
        r.SourceServerName,
        r.SourceDatabaseName,
        r.TargetServerName,
        r.TargetDatabaseName,
        r.RunStatus,
        r.IsValidateOnly,
        r.CreatedOnUtc,
        r.ValidatedOnUtc,
        r.AppliedOnUtc,
        r.CreatedByUserId,
        r.SummaryJson
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    SELECT
        sr.ID,
        sr.Guid,
        sr.RowStatus,
        sr.RunGuid,
        sr.RegistryGuid,
        tr.SchemaName,
        tr.TableName,
        sr.SourceRowGuid,
        sr.SourceRowId,
        sr.SourceRowStatus,
        sr.DifferenceType,
        sr.CreatedOnUtc
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
    ORDER BY tr.ApplyOrder, tr.SchemaName, tr.TableName, sr.ID;

    SELECT
        vi.ID,
        vi.Guid,
        vi.RowStatus,
        vi.RunGuid,
        vi.RegistryGuid,
        tr.SchemaName,
        tr.TableName,
        vi.SourceRowGuid,
        vi.Severity,
        vi.IssueCode,
        vi.IssueMessage,
        vi.DetailsJson,
        vi.CreatedOnUtc
    FROM SMigration.Metadata_ValidationIssues AS vi
    LEFT JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = vi.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE vi.RunGuid = @RunGuid
      AND vi.RowStatus NOT IN (0,254)
    ORDER BY vi.ID;

    SELECT
        el.ID,
        el.Guid,
        el.RowStatus,
        el.RunGuid,
        el.StepName,
        el.StepStatus,
        el.Message,
        el.DetailsJson,
        el.CreatedOnUtc
    FROM SMigration.Metadata_ExecutionLog AS el
    WHERE el.RunGuid = @RunGuid
      AND el.RowStatus NOT IN (0,254)
    ORDER BY el.ID;
END;
GO