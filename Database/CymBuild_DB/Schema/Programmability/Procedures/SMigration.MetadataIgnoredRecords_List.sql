SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataIgnoredRecords_List]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataIgnoredRecords_List]
(
    @RunGuid UNIQUEIDENTIFIER,
    @IncludeInactive BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TargetDatabaseName SYSNAME;

    SELECT
        @TargetDatabaseName = r.TargetDatabaseName
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @TargetDatabaseName IS NULL
        THROW 52210, 'Metadata ignored records list could not find the selected run.', 1;

    SELECT
        ign.Guid,
        ign.DatabaseName,
        ign.SchemaName,
        ign.TableName,
        ign.SourceRowGuid,
        ign.StableRecordKey,
        ign.Reason,
        ign.IgnoredByUserId,
        CONVERT(NVARCHAR(30), ign.IgnoredOnUtc, 126) AS IgnoredOnUtc,
        CONVERT(NVARCHAR(30), ign.UnignoredOnUtc, 126) AS UnignoredOnUtc,
        ign.RowStatus
    FROM SMigration.Metadata_IgnoredRecords AS ign
    WHERE ign.DatabaseName = @TargetDatabaseName
      AND (ISNULL(@IncludeInactive, 0) = 1 OR ign.RowStatus NOT IN (0,254))
    ORDER BY ign.SchemaName, ign.TableName, ign.IgnoredOnUtc DESC, ign.ID DESC;
END
GO
