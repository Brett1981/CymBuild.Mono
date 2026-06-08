SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataApplyIdentityMap_Build]')
GO

CREATE PROCEDURE [SMigration].[MetadataApplyIdentityMap_Build]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @TargetDatabaseName SYSNAME,
        @SchemaName SYSNAME,
        @TableName SYSNAME,
        @GuidColumnName SYSNAME,
        @PrimaryKeyColumnName SYSNAME,
        @RegistryGuid UNIQUEIDENTIFIER,
        @Sql NVARCHAR(MAX);

    SELECT
        @TargetDatabaseName = r.TargetDatabaseName
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @TargetDatabaseName IS NULL
    BEGIN
        ;THROW 51000, 'Metadata run was not found or is inactive.', 1;
    END;

    BEGIN TRANSACTION;

    DELETE FROM SMigration.Metadata_ApplyIdentityMap
    WHERE RunGuid = @RunGuid;

    INSERT INTO SMigration.Metadata_ApplyIdentityMap
    (
        Guid,
        RowStatus,
        RunGuid,
        RegistryGuid,
        SchemaName,
        TableName,
        SourceRowGuid,
        SourceRowId,
        TargetRowId,
        CreatedOnUtc
    )
    SELECT
        NEWID(),
        1,
        sr.RunGuid,
        sr.RegistryGuid,
        tr.SchemaName,
        tr.TableName,
        sr.SourceRowGuid,
        sr.SourceRowId,
        NULL,
        SYSUTCDATETIME()
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update');

    DECLARE registry_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            tr.Guid,
            tr.SchemaName,
            tr.TableName,
            tr.GuidColumnName,
            tr.PrimaryKeyColumnName
        FROM SMigration.Metadata_TableRegistry AS tr
        WHERE tr.RowStatus NOT IN (0,254)
          AND tr.IsEnabled = 1
        ORDER BY
            tr.ApplyOrder,
            tr.SchemaName,
            tr.TableName;

    OPEN registry_cursor;

    FETCH NEXT FROM registry_cursor
    INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @Sql = N'
UPDATE maprow
SET
    maprow.TargetRowId = TRY_CONVERT(BIGINT, targetrow.' + QUOTENAME(@PrimaryKeyColumnName) + N')
FROM SMigration.Metadata_ApplyIdentityMap AS maprow
INNER JOIN ' + QUOTENAME(@TargetDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS targetrow
    ON targetrow.' + QUOTENAME(@GuidColumnName) + N' = maprow.SourceRowGuid
WHERE maprow.RunGuid = @RunGuid
  AND maprow.RegistryGuid = @RegistryGuid
  AND maprow.RowStatus NOT IN (0,254);';

        EXEC sys.sp_executesql
            @Sql,
            N'@RunGuid UNIQUEIDENTIFIER, @RegistryGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid,
            @RegistryGuid = @RegistryGuid;

        FETCH NEXT FROM registry_cursor
        INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;
    END;

    CLOSE registry_cursor;
    DEALLOCATE registry_cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'BuildIdentityMap',
        @StepStatus = N'Succeeded',
        @Message = N'Metadata apply identity map built.',
        @DetailsJson = N'{}';

    COMMIT TRANSACTION;

    SELECT
        SchemaName,
        TableName,
        COUNT_BIG(1) AS MapRows,
        SUM(CASE WHEN TargetRowId IS NULL THEN 1 ELSE 0 END) AS MissingTargetRows
    FROM SMigration.Metadata_ApplyIdentityMap
    WHERE RunGuid = @RunGuid
      AND RowStatus NOT IN (0,254)
    GROUP BY
        SchemaName,
        TableName
    ORDER BY
        SchemaName,
        TableName;
END;
GO