SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataStage_Run]')
GO


PRINT (N'Create procedure [SMigration].[MetadataStage_Run]')
GO
PRINT (N'Create procedure [SMigration].[MetadataStage_Run]')
GO
PRINT (N'Create procedure [SMigration].[MetadataStage_Run]')
GO
PRINT (N'Create procedure [SMigration].[MetadataStage_Run]')
GO
PRINT (N'Create procedure [SMigration].[MetadataStage_Run]')
GO


CREATE PROCEDURE [SMigration].[MetadataStage_Run]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @SourceDatabaseName SYSNAME,
        @TargetDatabaseName SYSNAME,
        @SchemaName SYSNAME,
        @TableName SYSNAME,
        @GuidColumnName SYSNAME,
        @PrimaryKeyColumnName SYSNAME,
        @RegistryGuid UNIQUEIDENTIFIER,
        @ColumnList NVARCHAR(MAX),
        @HasRowStatus BIT,
        @SourceWhereClause NVARCHAR(MAX),
        @SourceAndClause NVARCHAR(MAX),
        @DuplicateWhereClause NVARCHAR(MAX),
        @SourceRowStatusExpression NVARCHAR(MAX),
        @Sql NVARCHAR(MAX);

    SELECT
        @SourceDatabaseName = r.SourceDatabaseName,
        @TargetDatabaseName = r.TargetDatabaseName
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @SourceDatabaseName IS NULL
    BEGIN
        ;THROW 51000, 'Metadata run was not found or is inactive.', 1;
    END;

    EXEC SMigration.MetadataRegistry_SyncFromEntityTypes
        @SourceDatabaseName = @SourceDatabaseName,
        @TargetDatabaseName = @TargetDatabaseName;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_TableRegistry AS tr
        WHERE tr.RowStatus NOT IN (0,254)
          AND tr.IsEnabled = 1
    )
    BEGIN
        ;THROW 51001, 'No enabled metadata registry rows exist. Run SMigration.MetadataRegistry_Seed first.', 1;
    END;

    BEGIN TRANSACTION;

    DELETE FROM SMigration.Metadata_StagedRows
    WHERE RunGuid = @RunGuid;

    DELETE FROM SMigration.Metadata_ValidationIssues
    WHERE RunGuid = @RunGuid
      AND IssueCode IN
      (
          N'DuplicateSourceGuid',
          N'RegisteredGuidColumnMissing',
          N'RegisteredTableMissing',
          N'RegisteredSourceTableMissing'
      );

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
        SET @ColumnList = NULL;
        SET @HasRowStatus = 0;
        SET @Sql = NULL;

        IF OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName), N'U') IS NULL
        BEGIN
            INSERT INTO SMigration.Metadata_ValidationIssues
            (
                Guid,
                RowStatus,
                RunGuid,
                RegistryGuid,
                SourceRowGuid,
                Severity,
                IssueCode,
                IssueMessage,
                DetailsJson,
                CreatedOnUtc
            )
            SELECT
                NEWID(),
                1,
                @RunGuid,
                @RegistryGuid,
                NULL,
                N'Fail',
                N'RegisteredTableMissing',
                CONCAT(N'Registered metadata table does not exist in target: ', @SchemaName, N'.', @TableName),
                CONCAT(N'{"SchemaName":"', @SchemaName, N'","TableName":"', @TableName, N'"}'),
                SYSUTCDATETIME();

            FETCH NEXT FROM registry_cursor
            INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

            CONTINUE;
        END;

        IF OBJECT_ID(QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName), N'U') IS NULL
        BEGIN
            INSERT INTO SMigration.Metadata_ValidationIssues
            (
                Guid,
                RowStatus,
                RunGuid,
                RegistryGuid,
                SourceRowGuid,
                Severity,
                IssueCode,
                IssueMessage,
                DetailsJson,
                CreatedOnUtc
            )
            SELECT
                NEWID(),
                1,
                @RunGuid,
                @RegistryGuid,
                NULL,
                N'Fail',
                N'RegisteredSourceTableMissing',
                CONCAT(N'Registered metadata table does not exist in source: ', @SchemaName, N'.', @TableName),
                CONCAT(N'{"SchemaName":"', @SchemaName, N'","TableName":"', @TableName, N'"}'),
                SYSUTCDATETIME();

            FETCH NEXT FROM registry_cursor
            INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

            CONTINUE;
        END;

        IF NOT EXISTS
        (
            SELECT 1
            FROM sys.schemas AS s
            INNER JOIN sys.tables AS t
                ON t.schema_id = s.schema_id
            INNER JOIN sys.columns AS c
                ON c.object_id = t.object_id
            WHERE s.name = @SchemaName
              AND t.name = @TableName
              AND c.name = @GuidColumnName
        )
        BEGIN
            INSERT INTO SMigration.Metadata_ValidationIssues
            (
                Guid,
                RowStatus,
                RunGuid,
                RegistryGuid,
                SourceRowGuid,
                Severity,
                IssueCode,
                IssueMessage,
                DetailsJson,
                CreatedOnUtc
            )
            SELECT
                NEWID(),
                1,
                @RunGuid,
                @RegistryGuid,
                NULL,
                N'Fail',
                N'RegisteredGuidColumnMissing',
                CONCAT(N'Registered metadata table does not have Guid column: ', @SchemaName, N'.', @TableName, N'.', @GuidColumnName),
                CONCAT(N'{"SchemaName":"', @SchemaName, N'","TableName":"', @TableName, N'","GuidColumnName":"', @GuidColumnName, N'"}'),
                SYSUTCDATETIME();

            FETCH NEXT FROM registry_cursor
            INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

            CONTINUE;
        END;

        SELECT
            @HasRowStatus =
                CASE WHEN EXISTS
                (
                    SELECT 1
                    FROM sys.schemas AS s
                    INNER JOIN sys.tables AS t
                        ON t.schema_id = s.schema_id
                    INNER JOIN sys.columns AS c
                        ON c.object_id = t.object_id
                    WHERE s.name = @SchemaName
                      AND t.name = @TableName
                      AND c.name = N'RowStatus'
                )
                THEN 1 ELSE 0 END;

        SELECT
            @ColumnList =
                STRING_AGG(CONVERT(NVARCHAR(MAX), QUOTENAME(c.name)), N',')
                WITHIN GROUP (ORDER BY c.column_id)
        FROM sys.schemas AS s
        INNER JOIN sys.tables AS t
            ON t.schema_id = s.schema_id
        INNER JOIN sys.columns AS c
            ON c.object_id = t.object_id
        WHERE s.name = @SchemaName
          AND t.name = @TableName
          AND c.is_computed = 0
          AND c.system_type_id <> 189;

        IF @ColumnList IS NULL
        BEGIN
            FETCH NEXT FROM registry_cursor
            INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

            CONTINUE;
        END;

        SET @SourceRowStatusExpression =
            CASE WHEN @HasRowStatus = 1
                THEN N'TRY_CONVERT(TINYINT, s.RowStatus)'
                ELSE N'NULL'
            END;

        SET @SourceWhereClause =
            CASE WHEN @HasRowStatus = 1
                THEN N'WHERE s.RowStatus NOT IN (0,254)'
                ELSE N''
            END;

        SET @SourceAndClause =
            CASE WHEN @HasRowStatus = 1
                THEN N'AND'
                ELSE N'WHERE'
            END;

        SET @DuplicateWhereClause =
            CASE WHEN @HasRowStatus = 1
                THEN N'WHERE sd.RowStatus NOT IN (0,254)'
                ELSE N''
            END;

        SET @Sql = N'
INSERT INTO SMigration.Metadata_ValidationIssues
(
    Guid,
    RowStatus,
    RunGuid,
    RegistryGuid,
    SourceRowGuid,
    Severity,
    IssueCode,
    IssueMessage,
    DetailsJson,
    CreatedOnUtc
)
SELECT
    NEWID(),
    1,
    @RunGuid,
    @RegistryGuid,
    d.SourceRowGuid,
    N''Fail'',
    N''DuplicateSourceGuid'',
    CONCAT(N''Source metadata table contains duplicate active Guid values: ' + REPLACE(@SchemaName, '''', '''''') + N'.' + REPLACE(@TableName, '''', '''''') + N' / '', CONVERT(NVARCHAR(36), d.SourceRowGuid)),
    CONCAT
    (
        N''{"SchemaName":"' + REPLACE(@SchemaName, '''', '''''') + N'","TableName":"' + REPLACE(@TableName, '''', '''''') + N'","DuplicateCount":'',
        CONVERT(NVARCHAR(30), d.DuplicateCount),
        N''}''
    ),
    SYSUTCDATETIME()
FROM
(
    SELECT
        CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N') AS SourceRowGuid,
        COUNT_BIG(1) AS DuplicateCount
    FROM ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS s
    ' + @SourceWhereClause + N'
    GROUP BY CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N')
    HAVING COUNT_BIG(1) > 1
) AS d;

INSERT INTO SMigration.Metadata_StagedRows
(
    Guid,
    RowStatus,
    RunGuid,
    RegistryGuid,
    SourceRowGuid,
    SourceRowId,
    SourceRowStatus,
    SourcePayloadJson,
    SourcePayloadHash,
    TargetPayloadJson,
    TargetPayloadHash,
    DifferenceType,
    CreatedOnUtc
)
SELECT
    NEWID(),
    1,
    @RunGuid,
    @RegistryGuid,
    src.SourceRowGuid,
    src.SourceRowId,
    src.SourceRowStatus,
    src.SourcePayloadJson,
    HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), src.SourcePayloadJson)),
    tgt.TargetPayloadJson,
    CASE
        WHEN tgt.TargetPayloadJson IS NULL THEN NULL
        ELSE HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson))
    END,
    CASE
        WHEN tgt.TargetPayloadJson IS NULL THEN N''Insert''
        WHEN HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), src.SourcePayloadJson))
           <> HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)) THEN N''Update''
        ELSE N''NoChange''
    END,
    SYSUTCDATETIME()
FROM
(
    SELECT
        CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N') AS SourceRowGuid,
        TRY_CONVERT(BIGINT, s.' + QUOTENAME(@PrimaryKeyColumnName) + N') AS SourceRowId,
        ' + @SourceRowStatusExpression + N' AS SourceRowStatus,
        (
            SELECT ' + @ColumnList + N'
            FROM ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS sj
            WHERE sj.' + QUOTENAME(@GuidColumnName) + N' = s.' + QUOTENAME(@GuidColumnName) + N'
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS SourcePayloadJson
    FROM ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS s
    ' + @SourceWhereClause + N'
    ' + @SourceAndClause + N' NOT EXISTS
    (
        SELECT 1
        FROM
        (
            SELECT
                CONVERT(UNIQUEIDENTIFIER, sd.' + QUOTENAME(@GuidColumnName) + N') AS DuplicateGuid
            FROM ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS sd
            ' + @DuplicateWhereClause + N'
            GROUP BY CONVERT(UNIQUEIDENTIFIER, sd.' + QUOTENAME(@GuidColumnName) + N')
            HAVING COUNT_BIG(1) > 1
        ) AS dup
        WHERE dup.DuplicateGuid = CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N')
    )
) AS src
OUTER APPLY
(
    SELECT
        (
            SELECT ' + @ColumnList + N'
            FROM ' + QUOTENAME(@TargetDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS tj
            WHERE tj.' + QUOTENAME(@GuidColumnName) + N' = src.SourceRowGuid
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS TargetPayloadJson
) AS tgt;';

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

    EXEC SMigration.MetadataStage_NormaliseDifferences
        @RunGuid = @RunGuid;

    EXEC SMigration.MetadataStage_NormaliseEnvironmentOnlyUpdates
    @RunGuid = @RunGuid;

    UPDATE SMigration.Metadata_Run
    SET
        RunStatus = N'Staged',
        SummaryJson =
        (
            SELECT
                CONCAT
                (
                    N'{"insertCount":',
                    CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'Insert' THEN 1 ELSE 0 END), 0)),
                    N',"updateCount":',
                    CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'Update' THEN 1 ELSE 0 END), 0)),
                    N',"noChangeCount":',
                    CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'NoChange' THEN 1 ELSE 0 END), 0)),
                    N',"totalCount":',
                    CONVERT(NVARCHAR(30), COUNT_BIG(1)),
                    N'}'
                )
            FROM SMigration.Metadata_StagedRows AS sr
            WHERE sr.RunGuid = @RunGuid
              AND sr.RowStatus NOT IN (0,254)
        )
    WHERE Guid = @RunGuid
      AND RowStatus NOT IN (0,254);

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'StageRun',
        @StepStatus = N'Succeeded',
        @Message = N'Metadata staging completed.',
        @DetailsJson = N'{}';

    COMMIT TRANSACTION;
END;

GO