SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[Metadata_CheckMissingDataObjects]')
GO

CREATE PROCEDURE [SCore].[Metadata_CheckMissingDataObjects]
(
      @Apply          BIT = 0          -- 0 = report only, 1 = apply fixes
    , @TopPerTable    INT = 500        -- cap per table per run
    , @IncludeDeleted BIT = 0          -- 0 = RowStatus NOT IN (0,254) (when RowStatus exists)
    , @Verbose        BIT = 1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RunGuid  UNIQUEIDENTIFIER = NEWID();
    DECLARE @NowUtc   DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @ZeroGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

    IF @Verbose = 1
        PRINT N'Running SCore.Metadata_CheckMissingDataObjects. RunGuid='
            + CONVERT(NVARCHAR(36), @RunGuid)
            + N' Apply=' + CONVERT(NVARCHAR(1), @Apply)
            + N' IncludeDeleted=' + CONVERT(NVARCHAR(1), @IncludeDeleted);

    /* -------------------------------------------------------------------------
       1) Metadata table list (from your screenshot)
       ------------------------------------------------------------------------- */
    DECLARE @Tables TABLE
    (
          Ord        INT IDENTITY(1,1) PRIMARY KEY
        , SchemaName SYSNAME NOT NULL
        , TableName  SYSNAME NOT NULL
    );

    INSERT INTO @Tables (SchemaName, TableName)
    VALUES
        /* SCore */
        (N'SCore', N'EntityDataTypes'),
        (N'SCore', N'EntityHobts'),
        (N'SCore', N'EntityProperties'),
        (N'SCore', N'EntityPropertyActions'),
        (N'SCore', N'EntityPropertyDependants'),
        (N'SCore', N'EntityPropertyGroups'),
        (N'SCore', N'EntityQueries'),
        (N'SCore', N'EntityQueryParameters'),
        (N'SCore', N'EntityTypes'),
        (N'SCore', N'LanguageLabels'),
        (N'SCore', N'LanguageLabelTranslations'),
        (N'SCore', N'Languages'),
        (N'SCore', N'MergeDocumentItemTypes'),
        (N'SCore', N'NonActivityTypes'),
        (N'SCore', N'RowStatus'),
        (N'SCore', N'SequenceTable'),
        (N'SCore', N'System'),
        (N'SCore', N'Versioning'),

        /* SUserInterface */
        (N'SUserInterface', N'ActionMenuItems'),
        (N'SUserInterface', N'DropDownListDefinitions'),
        (N'SUserInterface', N'GridDefinitions'),
        (N'SUserInterface', N'GridViewActions'),
        (N'SUserInterface', N'GridViewColumnDefinitions'),
        (N'SUserInterface', N'GridViewDefinitions'),
        (N'SUserInterface', N'GridViewTypes'),
        (N'SUserInterface', N'GridViewWidgetQueries'),
        (N'SUserInterface', N'Icons'),
        (N'SUserInterface', N'MainMenuItems'),
        (N'SUserInterface', N'MetricTypes'),
        (N'SUserInterface', N'PropertyGroupLayouts'),
        (N'SUserInterface', N'WidgetDashboards'),
        (N'SUserInterface', N'WidgetDashboardWidgetTypes'),
        (N'SUserInterface', N'WidgetTypes');

    /* -------------------------------------------------------------------------
       2) Working set for missing items across ALL tables
       ------------------------------------------------------------------------- */
    IF OBJECT_ID('tempdb..#Missing') IS NOT NULL DROP TABLE #Missing;
    CREATE TABLE #Missing
    (
          SchemaName   SYSNAME          NOT NULL
        , TableName    SYSNAME          NOT NULL
        , EntityTypeId INT              NULL
        , EntityGuid   UNIQUEIDENTIFIER NOT NULL
        , Details      NVARCHAR(4000)   NULL
    );

    /* -------------------------------------------------------------------------
       3) Iterate each table and collect missing DataObjects
       ------------------------------------------------------------------------- */
    DECLARE
          @SchemaName SYSNAME
        , @TableName  SYSNAME
        , @EntityTypeId INT
        , @HasGuid BIT
        , @HasRowStatus BIT;

    DECLARE curTbl CURSOR LOCAL FAST_FORWARD FOR
        SELECT SchemaName, TableName
        FROM @Tables
        ORDER BY Ord;

    OPEN curTbl;
    FETCH NEXT FROM curTbl INTO @SchemaName, @TableName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EntityTypeId = NULL;

        /* Resolve an EntityTypeId for logging (best-effort; metadata might have multiple HoBTs) */
        SELECT TOP (1) @EntityTypeId = et.ID
        FROM SCore.EntityHobts eh
        JOIN SCore.EntityTypes et ON et.ID = eh.EntityTypeID
        WHERE eh.SchemaName = @SchemaName
          AND eh.ObjectName = @TableName
          AND et.ID > 0
        ORDER BY ISNULL(eh.IsMainHoBT, 0) DESC, eh.ID DESC;

        /* Verify required columns exist in the target table */
        SELECT
              @HasGuid = CASE WHEN EXISTS
              (
                  SELECT 1
                  FROM sys.columns c
                  JOIN sys.objects o ON o.object_id = c.object_id
                  JOIN sys.schemas s ON s.schema_id = o.schema_id
                  WHERE s.name = @SchemaName
                    AND o.name = @TableName
                    AND c.name = N'Guid'
              ) THEN 1 ELSE 0 END,
              @HasRowStatus = CASE WHEN EXISTS
              (
                  SELECT 1
                  FROM sys.columns c
                  JOIN sys.objects o ON o.object_id = c.object_id
                  JOIN sys.schemas s ON s.schema_id = o.schema_id
                  WHERE s.name = @SchemaName
                    AND o.name = @TableName
                    AND c.name = N'RowStatus'
              ) THEN 1 ELSE 0 END;

        BEGIN TRY
            IF @HasGuid = 1
            BEGIN
                DECLARE @Sql NVARCHAR(MAX) =
N'
INSERT INTO #Missing (SchemaName, TableName, EntityTypeId, EntityGuid, Details)
SELECT TOP (@TopPerTable)
      @SchemaName
    , @TableName
    , @EntityTypeId
    , e.[Guid]
    , NULL
FROM ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' e
LEFT JOIN SCore.DataObjects d
    ON d.[Guid] = e.[Guid]
WHERE
    e.[Guid] IS NOT NULL
    AND e.[Guid] <> @ZeroGuid
    AND d.[Guid] IS NULL
' + CASE
        WHEN @IncludeDeleted = 1 THEN N''
        WHEN @HasRowStatus = 1 THEN N'    AND e.[RowStatus] NOT IN (0,254)
'
        ELSE N''
    END + N'
ORDER BY e.[Guid];
';

                EXEC sp_executesql
                    @Sql,
                    N'@TopPerTable INT, @SchemaName SYSNAME, @TableName SYSNAME, @EntityTypeId INT, @ZeroGuid UNIQUEIDENTIFIER, @IncludeDeleted BIT',
                    @TopPerTable    = @TopPerTable,
                    @SchemaName     = @SchemaName,
                    @TableName      = @TableName,
                    @EntityTypeId   = @EntityTypeId,
                    @ZeroGuid       = @ZeroGuid,
                    @IncludeDeleted = @IncludeDeleted;
            END
            ELSE
            BEGIN
                /* No Guid column -> treat as “skipped” (log as Error row) */
                INSERT INTO SCore.DataObjectIntegrityFindings
                (
                      FindingRunGuid, LoggedAtUtc, FindingType, EntityTypeId, SchemaName, TableName,
                      EntityGuid, DataObjectGuid, DataObjectRowStatus, Details
                )
                VALUES
                (
                      @RunGuid, SYSUTCDATETIME(), N'Error', @EntityTypeId, @SchemaName, @TableName,
                      NULL, NULL, NULL, N'Table does not have a [Guid] column (skipped).'
                );
            END
        END TRY
        BEGIN CATCH
            INSERT INTO SCore.DataObjectIntegrityFindings
            (
                  FindingRunGuid, LoggedAtUtc, FindingType, EntityTypeId, SchemaName, TableName,
                  EntityGuid, DataObjectGuid, DataObjectRowStatus, Details
            )
            VALUES
            (
                  @RunGuid, SYSUTCDATETIME(), N'Error', @EntityTypeId, @SchemaName, @TableName,
                  NULL, NULL, NULL,
                  N'Error ' + CONVERT(NVARCHAR(20), ERROR_NUMBER()) + N': ' + ERROR_MESSAGE()
            );
        END CATCH;

        FETCH NEXT FROM curTbl INTO @SchemaName, @TableName;
    END

    CLOSE curTbl;
    DEALLOCATE curTbl;

    /* -------------------------------------------------------------------------
       4) Log Missing findings (one row per missing Guid)
       ------------------------------------------------------------------------- */
    INSERT INTO SCore.DataObjectIntegrityFindings
    (
          FindingRunGuid, LoggedAtUtc, FindingType, EntityTypeId, SchemaName, TableName,
          EntityGuid, DataObjectGuid, DataObjectRowStatus, Details
    )
    SELECT
          @RunGuid
        , @NowUtc
        , N'MissingDataObject'
        , m.EntityTypeId
        , m.SchemaName
        , m.TableName
        , m.EntityGuid
        , NULL
        , NULL
        , NULL
    FROM #Missing m;

    /* -------------------------------------------------------------------------
       5) Summary + preview
       ------------------------------------------------------------------------- */
    SELECT
          @RunGuid AS RunGuid
        , m.SchemaName
        , m.TableName
        , COUNT(*) AS MissingCount
    FROM #Missing m
    GROUP BY m.SchemaName, m.TableName
    ORDER BY m.SchemaName, m.TableName;

    SELECT TOP (500)
          m.SchemaName
        , m.TableName
        , m.EntityTypeId
        , m.EntityGuid
    FROM #Missing m
    ORDER BY m.SchemaName, m.TableName, m.EntityGuid;

        /* -------------------------------------------------------------------------
           6) Apply fixes (calls UpsertDataObject)
           ------------------------------------------------------------------------- */
        /* =============================================================================
       APPLY FIXES (safe transaction handling)

       Why this exists:
       - Msg 3930 happens when an error occurs inside an open transaction and
         XACT_ABORT ON dooms the transaction.
       - If you then try to COMMIT or do any logged writes, SQL throws 3930.

       Fix:
       - No “big batch” transaction.
       - Use a per-row transaction.
       - In CATCH: always rollback if needed using XACT_STATE().
       - Optionally continue to next row or stop immediately.

       Add these optional parameters to your proc signature if you want control:
         , @StopOnError BIT = 0   -- 0=continue, 1=throw after first failure
    ============================================================================= */

    IF @Apply = 1
    BEGIN
        DECLARE
              @FixGuid UNIQUEIDENTIFIER
            , @FixSchema SYSNAME
            , @FixObject SYSNAME
            , @IsInsert BIT
            , @StopOnError BIT = 0; -- change to 1 if you want fail-fast

        DECLARE curFix CURSOR LOCAL FAST_FORWARD FOR
            SELECT DISTINCT
                  m.EntityGuid
                , m.SchemaName
                , m.TableName
            FROM #Missing m
            WHERE m.EntityGuid IS NOT NULL
            ORDER BY m.SchemaName, m.TableName, m.EntityGuid;

        OPEN curFix;
        FETCH NEXT FROM curFix INTO @FixGuid, @FixSchema, @FixObject;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                /* Double-check still missing */
                IF NOT EXISTS (SELECT 1 FROM SCore.DataObjects d WHERE d.Guid = @FixGuid)
                BEGIN
                    IF @Verbose = 1
                        PRINT CONCAT('Running upsert data object for ', CONVERT(NVARCHAR(36), @FixGuid),
                                     ' [', @FixSchema, '].[', @FixObject, ']');

                    /* Per-row transaction */
                    BEGIN TRAN;

                    SET @IsInsert = 0;

                    EXEC SCore.UpsertDataObject
                          @Guid                  = @FixGuid
                        , @SchemeName             = @FixSchema
                        , @ObjectName             = @FixObject
                        , @IncludeDefaultSecurity = 0
                        , @IsInsert               = @IsInsert OUTPUT;

                    COMMIT TRAN;
                END
            END TRY
            BEGIN CATCH
                /* IMPORTANT: transaction might be doomed; you MUST rollback */
                IF XACT_STATE() <> 0
                    ROLLBACK TRAN;

                /* Log the error if findings table exists */
                IF OBJECT_ID(N'SCore.DataObjectIntegrityFindings', N'U') IS NOT NULL
                BEGIN
                    INSERT INTO SCore.DataObjectIntegrityFindings
                    (
                          FindingRunGuid, LoggedAtUtc, FindingType, EntityTypeId, SchemaName, TableName,
                          EntityGuid, DataObjectGuid, DataObjectRowStatus, Details
                    )
                    VALUES
                    (
                          @RunGuid, SYSUTCDATETIME(), N'Error', NULL, @FixSchema, @FixObject,
                          @FixGuid, NULL, NULL,
                          CONCAT(N'UpsertDataObject failed. Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE())
                    );
                END

                /* Decide whether to continue or stop */
                IF @StopOnError = 1
                BEGIN
                    DECLARE @Err NVARCHAR(4000) =
                        CONCAT(N'UpsertDataObject failed for ', CONVERT(NVARCHAR(36), @FixGuid),
                               N' [', @FixSchema, N'].[' , @FixObject, N']. Error ',
                               ERROR_NUMBER(), N': ', ERROR_MESSAGE());
                    THROW 60010, @Err, 1;
                END
            END CATCH;

            FETCH NEXT FROM curFix INTO @FixGuid, @FixSchema, @FixObject;
        END

        CLOSE curFix;
        DEALLOCATE curFix;

        IF @Verbose = 1
            PRINT CONCAT('Apply completed. RunGuid=', CONVERT(NVARCHAR(36), @RunGuid));
    END


END
GO