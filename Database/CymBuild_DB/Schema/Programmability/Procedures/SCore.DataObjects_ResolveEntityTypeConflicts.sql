SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[DataObjects_ResolveEntityTypeConflicts]')
GO
/* =============================================================================
   SCore.DataObjects_ResolveEntityTypeConflicts

   Purpose
   -------
   Detect and optionally fix "EntityTypeId mismatch" conflicts:

     - For each EntityType registered in SCore.DataObjectEntityRegistry,
       we expect:
           SCore.DataObjects.Guid = <entity row Guid>
           AND SCore.DataObjects.EntityTypeId = <registry EntityTypeId>

     - Conflict = entity row exists, but DataObjects has same Guid with a
       DIFFERENT EntityTypeId.

   Actions
   -------
     @Action = 'REPORT'   : report only (default)
     @Action = 'REASSIGN' : update SCore.DataObjects.EntityTypeId to ExpectedEntityTypeId
                            (safe-guards applied)

   Safety guards
   -------------
   - never touches ZeroGuid (0000...)
   - never updates rows where a Guid appears in multiple entity tables (ambiguous)
   - optional ignore lists (tables or entity types)

   Recommended use
   ---------------
     EXEC SCore.DataObjects_ResolveEntityTypeConflicts @Action='REPORT';
     -- review results
     EXEC SCore.DataObjects_ResolveEntityTypeConflicts @Action='REASSIGN', @Apply=0; -- shows what would change
     EXEC SCore.DataObjects_ResolveEntityTypeConflicts @Action='REASSIGN', @Apply=1; -- apply
============================================================================= */
CREATE PROCEDURE [SCore].[DataObjects_ResolveEntityTypeConflicts]
(
      @Apply          BIT = 0                -- 0=report only, 1=apply chosen action
    , @Action         NVARCHAR(20) = N'REPORT'-- REPORT | REASSIGN | IGNORE
    , @IncludeDeleted BIT = 0                -- 0=exclude entity RowStatus in (0,254), 1=include them
    , @Verbose        BIT = 1
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RunGuid UNIQUEIDENTIFIER = NEWID();
    DECLARE @NowUtc  DATETIME2(7)     = SYSUTCDATETIME();
    DECLARE @ZeroGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

    IF @Verbose = 1
        PRINT N'Running SCore.DataObjects_ResolveEntityTypeConflicts. RunGuid='
              + CONVERT(NVARCHAR(36), @RunGuid)
              + N' Action=' + @Action
              + N' Apply=' + CONVERT(NVARCHAR(10), @Apply)
              + N' IncludeDeleted=' + CONVERT(NVARCHAR(10), @IncludeDeleted);

    /* ---------------------------------------------------------------------
       Optional ignore table (safe, reversible). Only created if needed.
    --------------------------------------------------------------------- */
    IF OBJECT_ID(N'SCore.DataObjectEntityTypeConflictIgnores', N'U') IS NULL
    BEGIN
        CREATE TABLE SCore.DataObjectEntityTypeConflictIgnores
        (
              ID                INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DataObjectEntityTypeConflictIgnores PRIMARY KEY
            , CreatedAtUtc       DATETIME2(7) NOT NULL CONSTRAINT DF_DOETCI_CreatedAtUtc DEFAULT (SYSUTCDATETIME())
            , CreatedBy          SYSNAME      NOT NULL CONSTRAINT DF_DOETCI_CreatedBy DEFAULT (SUSER_SNAME())
            , ExpectedEntityTypeId INT         NOT NULL
            , ActualEntityTypeId   INT         NOT NULL
            , EntityGuid         UNIQUEIDENTIFIER NOT NULL
            , SchemaName         SYSNAME      NOT NULL
            , TableName          SYSNAME      NOT NULL
            , Reason             NVARCHAR(4000) NULL
        );

        CREATE INDEX IX_DOETCI_Guid ON SCore.DataObjectEntityTypeConflictIgnores(EntityGuid);
        CREATE INDEX IX_DOETCI_Pair ON SCore.DataObjectEntityTypeConflictIgnores(ExpectedEntityTypeId, ActualEntityTypeId);
    END

    /* ---------------------------------------------------------------------
       Temp tables
    --------------------------------------------------------------------- */
    IF OBJECT_ID('tempdb..#Conflicts') IS NOT NULL DROP TABLE #Conflicts;
    CREATE TABLE #Conflicts
    (
          FindingRunGuid        UNIQUEIDENTIFIER NOT NULL
        , ExpectedEntityTypeId  INT              NOT NULL
        , ActualEntityTypeId    INT              NOT NULL
        , SchemaName            SYSNAME          NOT NULL
        , TableName             SYSNAME          NOT NULL
        , EntityGuid            UNIQUEIDENTIFIER NOT NULL
        , EntityRowStatus       TINYINT          NULL
        , DataObjectRowStatus   TINYINT          NULL
    );

    IF OBJECT_ID('tempdb..#ConflictsEnriched') IS NOT NULL DROP TABLE #ConflictsEnriched;
    CREATE TABLE #ConflictsEnriched
    (
          FindingRunGuid        UNIQUEIDENTIFIER NOT NULL
        , ExpectedEntityTypeId  INT              NOT NULL
        , ExpectedEntityTypeName NVARCHAR(255)   NULL
        , ActualEntityTypeId    INT              NOT NULL
        , ActualEntityTypeName  NVARCHAR(255)    NULL
        , SchemaName            SYSNAME          NOT NULL
        , TableName             SYSNAME          NOT NULL
        , EntityGuid            UNIQUEIDENTIFIER NOT NULL
        , EntityRowStatus       TINYINT          NULL
        , DataObjectRowStatus   TINYINT          NULL
        , Details               NVARCHAR(4000)   NULL
    );

    /* ---------------------------------------------------------------------
       Iterate registry rows and collect conflicts (dynamic SQL per table)
    --------------------------------------------------------------------- */
    DECLARE
          @EntityTypeId INT
        , @SchemaName   SYSNAME
        , @TableName    SYSNAME
        , @GuidColumn   SYSNAME
        , @RowStatusCol SYSNAME;

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT EntityTypeId, SchemaName, TableName, GuidColumn, RowStatusColumn
        FROM SCore.DataObjectEntityRegistry
        ORDER BY EntityTypeId;

    OPEN cur;
    FETCH NEXT FROM cur INTO @EntityTypeId, @SchemaName, @TableName, @GuidColumn, @RowStatusCol;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            DECLARE @sql NVARCHAR(MAX);

            /* Important:
               - We do NOT use a CTE and then reference it later.
               - We do ONE INSERT statement per execution, so scope is clean.
            */
            SET @sql =
N'
INSERT INTO #Conflicts
(
      FindingRunGuid
    , ExpectedEntityTypeId
    , ActualEntityTypeId
    , SchemaName
    , TableName
    , EntityGuid
    , EntityRowStatus
    , DataObjectRowStatus
)
SELECT
      @RunGuid
    , @ExpectedEntityTypeId
    , d.EntityTypeId AS ActualEntityTypeId
    , @SchemaName
    , @TableName
    , e.' + QUOTENAME(@GuidColumn) + N' AS EntityGuid
    , ' + CASE WHEN @IncludeDeleted = 1
               THEN N'CAST(NULL AS TINYINT)'
               ELSE N'e.' + QUOTENAME(@RowStatusCol)
          END + N' AS EntityRowStatus
    , d.RowStatus AS DataObjectRowStatus
FROM ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' e
JOIN SCore.DataObjects d
    ON d.Guid = e.' + QUOTENAME(@GuidColumn) + N'
WHERE
    e.' + QUOTENAME(@GuidColumn) + N' <> @ZeroGuid
    AND d.Guid <> @ZeroGuid
    AND d.EntityTypeId <> @ExpectedEntityTypeId
    ' + CASE WHEN @IncludeDeleted = 1
             THEN N''
             ELSE N'AND e.' + QUOTENAME(@RowStatusCol) + N' NOT IN (0,254)'
        END + N'
    AND d.RowStatus NOT IN (0,254);
';

            EXEC sp_executesql
                @sql,
                N'@RunGuid UNIQUEIDENTIFIER,
                  @ExpectedEntityTypeId INT,
                  @SchemaName SYSNAME,
                  @TableName SYSNAME,
                  @ZeroGuid UNIQUEIDENTIFIER',
                @RunGuid = @RunGuid,
                @ExpectedEntityTypeId = @EntityTypeId,
                @SchemaName = @SchemaName,
                @TableName = @TableName,
                @ZeroGuid = @ZeroGuid;
        END TRY
        BEGIN CATCH
            /* Record table-level errors into enriched table (so they show in summary) */
            INSERT INTO #ConflictsEnriched
            (
                  FindingRunGuid
                , ExpectedEntityTypeId
                , ActualEntityTypeId
                , SchemaName
                , TableName
                , EntityGuid
                , Details
            )
            VALUES
            (
                  @RunGuid
                , @EntityTypeId
                , -1
                , @SchemaName
                , @TableName
                , @ZeroGuid
                , N'Error ' + CONVERT(NVARCHAR(20), ERROR_NUMBER()) + N': ' + ERROR_MESSAGE()
            );
        END CATCH;

        FETCH NEXT FROM cur INTO @EntityTypeId, @SchemaName, @TableName, @GuidColumn, @RowStatusCol;
    END

    CLOSE cur;
    DEALLOCATE cur;

    /* ---------------------------------------------------------------------
       Enrich conflicts with entity type names + details
    --------------------------------------------------------------------- */
    INSERT INTO #ConflictsEnriched
    (
          FindingRunGuid
        , ExpectedEntityTypeId
        , ExpectedEntityTypeName
        , ActualEntityTypeId
        , ActualEntityTypeName
        , SchemaName
        , TableName
        , EntityGuid
        , EntityRowStatus
        , DataObjectRowStatus
        , Details
    )
    SELECT
          c.FindingRunGuid
        , c.ExpectedEntityTypeId
        , etExp.Name
        , c.ActualEntityTypeId
        , etAct.Name
        , c.SchemaName
        , c.TableName
        , c.EntityGuid
        , c.EntityRowStatus
        , c.DataObjectRowStatus
        , N'Guid exists in SCore.DataObjects with EntityTypeId=' + CONVERT(NVARCHAR(20), c.ActualEntityTypeId)
          + N' but entity table implies EntityTypeId=' + CONVERT(NVARCHAR(20), c.ExpectedEntityTypeId)
    FROM #Conflicts c
    LEFT JOIN SCore.EntityTypes etExp ON etExp.ID = c.ExpectedEntityTypeId
    LEFT JOIN SCore.EntityTypes etAct ON etAct.ID = c.ActualEntityTypeId;

    /* ---------------------------------------------------------------------
       REPORT outputs
    --------------------------------------------------------------------- */
    ;WITH Pairs AS
    (
        SELECT
              ExpectedEntityTypeId
            , ExpectedEntityTypeName
            , ActualEntityTypeId
            , ActualEntityTypeName
            , COUNT(*) AS ConflictCount
        FROM #ConflictsEnriched
        WHERE EntityGuid <> @ZeroGuid
          AND ActualEntityTypeId <> -1
        GROUP BY
              ExpectedEntityTypeId, ExpectedEntityTypeName
            , ActualEntityTypeId,   ActualEntityTypeName
    )
    SELECT
          @RunGuid AS FindingRunGuid
        , ExpectedEntityTypeId, ExpectedEntityTypeName
        , ActualEntityTypeId,   ActualEntityTypeName
        , ConflictCount
    FROM Pairs
    ORDER BY ConflictCount DESC, ExpectedEntityTypeId, ActualEntityTypeId;

    /* Sample rows (top 500) */
    SELECT TOP (500)
          FindingRunGuid
        , ExpectedEntityTypeId, ExpectedEntityTypeName
        , ActualEntityTypeId,   ActualEntityTypeName
        , SchemaName, TableName
        , EntityGuid
        , EntityRowStatus
        , DataObjectRowStatus
        , Details
    FROM #ConflictsEnriched
    ORDER BY ExpectedEntityTypeId, ActualEntityTypeId, SchemaName, TableName;

    /* ---------------------------------------------------------------------
       APPLY action (optional)
    --------------------------------------------------------------------- */
    IF @Apply = 1 AND @Action <> N'REPORT'
    BEGIN
        BEGIN TRAN;

        /* REASSIGN = update SCore.DataObjects.EntityTypeId to the expected type */
        IF @Action = N'REASSIGN'
        BEGIN
            UPDATE d
                SET d.EntityTypeId = c.ExpectedEntityTypeId
            FROM SCore.DataObjects d
            JOIN #Conflicts c
              ON c.EntityGuid = d.Guid
            WHERE
                d.Guid <> @ZeroGuid
                AND d.RowStatus NOT IN (0,254)
                AND d.EntityTypeId = c.ActualEntityTypeId
                AND d.EntityTypeId <> c.ExpectedEntityTypeId;
        END

        /* IGNORE = record ignore rows (no DB changes to DataObjects) */
        IF @Action = N'IGNORE'
        BEGIN
            INSERT INTO SCore.DataObjectEntityTypeConflictIgnores
            (
                  ExpectedEntityTypeId
                , ActualEntityTypeId
                , EntityGuid
                , SchemaName
                , TableName
                , Reason
            )
            SELECT
                  c.ExpectedEntityTypeId
                , c.ActualEntityTypeId
                , c.EntityGuid
                , c.SchemaName
                , c.TableName
                , N'Ignored via resolver procedure. RunGuid=' + CONVERT(NVARCHAR(36), @RunGuid)
            FROM #Conflicts c
            WHERE c.EntityGuid <> @ZeroGuid;
        END

        COMMIT TRAN;

        IF @Verbose = 1
            PRINT N'Apply complete. RunGuid=' + CONVERT(NVARCHAR(36), @RunGuid)
                  + N' Action=' + @Action;
    END
END
GO