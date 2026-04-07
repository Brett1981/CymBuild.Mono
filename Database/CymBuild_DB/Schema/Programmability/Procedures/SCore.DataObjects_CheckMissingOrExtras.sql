SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[DataObjects_CheckMissingOrExtras]')
GO

CREATE PROCEDURE [SCore].[DataObjects_CheckMissingOrExtras]
(
      @Apply           BIT     = 0      -- 0 = report only, 1 = apply fixes (Missing/Extras only)
    , @FixMissing      BIT     = 1      -- inserts missing DataObjects (when safe)
    , @FixExtras       BIT     = 0      -- soft-deletes extras (RowStatus=254) - OFF by default
    , @ExtrasRowStatus TINYINT = 254
    , @IncludeDeleted  BIT     = 0      -- if 1, include entity rows even when RowStatus in (0,254)
    , @Verbose         BIT     = 1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RunGuid  UNIQUEIDENTIFIER = NEWID();
    DECLARE @NowUtc   DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @ZeroGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

    IF @Verbose = 1
        PRINT CONCAT(
            'Running SCore.DataObjects_CheckMissingOrExtras. RunGuid=', CONVERT(NVARCHAR(36), @RunGuid),
            ' Apply=', @Apply,
            ' IncludeDeleted=', @IncludeDeleted
        );

    IF OBJECT_ID('tempdb..#Findings') IS NOT NULL DROP TABLE #Findings;
    CREATE TABLE #Findings
    (
          FindingType         NVARCHAR(20)     NOT NULL
        , EntityTypeId        INT              NULL
        , SchemaName          SYSNAME          NULL
        , TableName           SYSNAME          NULL
        , EntityGuid          UNIQUEIDENTIFIER NULL
        , DataObjectGuid      UNIQUEIDENTIFIER NULL
        , DataObjectRowStatus TINYINT          NULL
        , Details             NVARCHAR(4000)   NULL
    );

    DECLARE
          @EntityTypeId INT
        , @SchemaName   SYSNAME
        , @TableName    SYSNAME
        , @GuidColumn   SYSNAME
        , @RowStatusCol SYSNAME
        , @ActiveCsv    NVARCHAR(50);

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT EntityTypeId, SchemaName, TableName, GuidColumn, RowStatusColumn, ActiveRowStatusCsv
        FROM SCore.DataObjectEntityRegistry
        ORDER BY EntityTypeId;

    OPEN cur;
    FETCH NEXT FROM cur INTO @EntityTypeId, @SchemaName, @TableName, @GuidColumn, @RowStatusCol, @ActiveCsv;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            DECLARE @EntityDeletedFilter NVARCHAR(400) =
                CASE WHEN @IncludeDeleted = 1
                     THEN N''
                     ELSE N' AND e.' + QUOTENAME(@RowStatusCol) + N' NOT IN (0,254) '
                END;

            DECLARE @sql NVARCHAR(MAX) =
N'
/* ===== ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' (EntityTypeId=' + CONVERT(NVARCHAR(20), @EntityTypeId) + N') ===== */

;WITH EntityRows AS
(
    SELECT DISTINCT
        e.' + QUOTENAME(@GuidColumn) + N' AS EntityGuid
    FROM ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' e
    WHERE
        e.' + QUOTENAME(@GuidColumn) + N' IS NOT NULL
        AND e.' + QUOTENAME(@GuidColumn) + N' <> @ZeroGuid
        ' + @EntityDeletedFilter + N'
),
DOByGuid AS
(
    SELECT d.Guid, d.EntityTypeId, d.RowStatus
    FROM SCore.DataObjects d
    WHERE d.Guid <> @ZeroGuid
),
DOByType AS
(
    SELECT d.Guid, d.RowStatus
    FROM SCore.DataObjects d
    WHERE d.EntityTypeId = @EntityTypeId
      AND d.Guid <> @ZeroGuid
)

INSERT INTO #Findings
(
      FindingType, EntityTypeId, SchemaName, TableName,
      EntityGuid, DataObjectGuid, DataObjectRowStatus, Details
)
-- 1) CONFLICT
SELECT
      ''Conflict'',
      @EntityTypeId,
      @SchemaName,
      @TableName,
      e.EntityGuid,
      d.Guid,
      d.RowStatus,
      CONCAT(''Guid already exists in SCore.DataObjects with EntityTypeId='', d.EntityTypeId,
             '' (cannot insert missing row due to PK on Guid).'')
FROM EntityRows e
JOIN DOByGuid d
  ON d.Guid = e.EntityGuid
WHERE d.EntityTypeId <> @EntityTypeId

UNION ALL
-- 2) MISSING (true missing only)
SELECT
      ''MissingDataObject'',
      @EntityTypeId,
      @SchemaName,
      @TableName,
      e.EntityGuid,
      NULL,
      NULL,
      NULL
FROM EntityRows e
LEFT JOIN DOByGuid d
  ON d.Guid = e.EntityGuid
WHERE d.Guid IS NULL

UNION ALL
-- 3) EXTRA
SELECT
      ''ExtraDataObject'',
      @EntityTypeId,
      @SchemaName,
      @TableName,
      NULL,
      d.Guid,
      d.RowStatus,
      NULL
FROM DOByType d
LEFT JOIN EntityRows e
  ON e.EntityGuid = d.Guid
WHERE e.EntityGuid IS NULL;
';

            EXEC sp_executesql
                @sql,
                N'@EntityTypeId INT, @SchemaName SYSNAME, @TableName SYSNAME, @ZeroGuid UNIQUEIDENTIFIER',
                @EntityTypeId = @EntityTypeId,
                @SchemaName   = @SchemaName,
                @TableName    = @TableName,
                @ZeroGuid     = @ZeroGuid;
        END TRY
        BEGIN CATCH
            INSERT INTO #Findings (FindingType, EntityTypeId, SchemaName, TableName, Details)
            VALUES
            (
                N'Error',
                @EntityTypeId,
                @SchemaName,
                @TableName,
                CONCAT(N'Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE())
            );
        END CATCH;

        FETCH NEXT FROM cur INTO @EntityTypeId, @SchemaName, @TableName, @GuidColumn, @RowStatusCol, @ActiveCsv;
    END

    CLOSE cur;
    DEALLOCATE cur;

    INSERT INTO SCore.DataObjectIntegrityFindings
    (
          FindingRunGuid, LoggedAtUtc, FindingType, EntityTypeId, SchemaName, TableName,
          EntityGuid, DataObjectGuid, DataObjectRowStatus, Details
    )
    SELECT
          @RunGuid, @NowUtc, FindingType, EntityTypeId, SchemaName, TableName,
          EntityGuid, DataObjectGuid, DataObjectRowStatus, Details
    FROM #Findings;

    SELECT
          @RunGuid AS FindingRunGuid,
          FindingType,
          COUNT(*) AS FindingCount
    FROM #Findings
    GROUP BY FindingType
    ORDER BY CASE FindingType WHEN 'Error' THEN 0 WHEN 'Conflict' THEN 1 WHEN 'MissingDataObject' THEN 2 ELSE 3 END;

    IF @Apply = 1
    BEGIN
        BEGIN TRAN;

        IF @FixMissing = 1
        BEGIN
            INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
            SELECT
                  f.EntityGuid,
                  1,
                  f.EntityTypeId
            FROM #Findings f
            WHERE f.FindingType = 'MissingDataObject'
              AND f.EntityGuid IS NOT NULL
              AND f.EntityGuid <> @ZeroGuid
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM SCore.DataObjects d
                  WHERE d.Guid = f.EntityGuid
              );
        END

        IF @FixExtras = 1
        BEGIN
            UPDATE d
                SET d.RowStatus = @ExtrasRowStatus
            FROM SCore.DataObjects d
            JOIN #Findings f
              ON f.FindingType = 'ExtraDataObject'
             AND f.DataObjectGuid = d.Guid
             AND f.EntityTypeId = d.EntityTypeId
            WHERE d.RowStatus NOT IN (0,254)
              AND d.Guid <> @ZeroGuid;
        END

        COMMIT TRAN;

        IF @Verbose = 1
            PRINT CONCAT('Fixes applied (safe only). RunGuid=', CONVERT(NVARCHAR(36), @RunGuid));
    END
END
GO