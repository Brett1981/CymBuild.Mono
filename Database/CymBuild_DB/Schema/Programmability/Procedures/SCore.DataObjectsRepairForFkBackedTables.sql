SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[DataObjectsRepairForFkBackedTables]')
GO

CREATE PROCEDURE [SCore].[DataObjectsRepairForFkBackedTables]
(
      @RunGuid                       UNIQUEIDENTIFIER = NULL
    , @SchemaFilter                  SYSNAME = NULL
    , @AttemptMetadataRegistration   BIT = 0
    , @ThrowOnUnresolved             BIT = 0
    , @ValidateConstraints           BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    IF @RunGuid IS NULL
        SET @RunGuid = NEWID();

    INSERT INTO SCore.PostDeploymentRunLog
    (
          RunGuid
        , StepName
        , Severity
        , Message
    )
    VALUES
    (
          @RunGuid
        , N'DataObjects FK-backed repair'
        , N'Info'
        , N'Started FK-backed DataObjects repair.'
    );

    IF @AttemptMetadataRegistration = 1
    BEGIN
        INSERT INTO SCore.PostDeploymentRunLog
        (
              RunGuid
            , StepName
            , Severity
            , Message
        )
        VALUES
        (
              @RunGuid
            , N'DataObjects FK-backed repair'
            , N'Warning'
            , N'@AttemptMetadataRegistration was requested but is intentionally ignored. Metadata must be source-controlled.'
        );
    END;

    IF OBJECT_ID(N'tempdb..#DataObjectFkTables') IS NOT NULL DROP TABLE #DataObjectFkTables;
    IF OBJECT_ID(N'tempdb..#TablesNeedingRepair') IS NOT NULL DROP TABLE #TablesNeedingRepair;
    IF OBJECT_ID(N'tempdb..#ResolvedMappings') IS NOT NULL DROP TABLE #ResolvedMappings;
    IF OBJECT_ID(N'tempdb..#UnresolvedMappings') IS NOT NULL DROP TABLE #UnresolvedMappings;
    IF OBJECT_ID(N'tempdb..#FkErrors') IS NOT NULL DROP TABLE #FkErrors;

    CREATE TABLE #DataObjectFkTables
    (
          WorkId          INT IDENTITY(1,1) NOT NULL PRIMARY KEY
        , SchemaName      SYSNAME NOT NULL
        , TableName       SYSNAME NOT NULL
        , ConstraintName  SYSNAME NOT NULL
        , TwoPartName     NVARCHAR(517) NOT NULL
    );

    CREATE TABLE #TablesNeedingRepair
    (
          WorkId              INT IDENTITY(1,1) NOT NULL PRIMARY KEY
        , SchemaName          SYSNAME NOT NULL
        , TableName           SYSNAME NOT NULL
        , ConstraintName      SYSNAME NOT NULL
        , TwoPartName         NVARCHAR(517) NOT NULL
        , MissingGuidCount    BIGINT NOT NULL
    );

    CREATE TABLE #ResolvedMappings
    (
          WorkId              INT IDENTITY(1,1) NOT NULL PRIMARY KEY
        , SchemaName          SYSNAME NOT NULL
        , TableName           SYSNAME NOT NULL
        , ConstraintName      SYSNAME NOT NULL
        , TwoPartName         NVARCHAR(517) NOT NULL
        , EntityTypeId        INT NOT NULL
        , EntityTypeName      NVARCHAR(255) NULL
        , ResolutionPath      NVARCHAR(100) NOT NULL
        , MissingGuidCount    BIGINT NOT NULL
    );

    CREATE TABLE #UnresolvedMappings
    (
          SchemaName          SYSNAME NOT NULL
        , TableName           SYSNAME NOT NULL
        , ConstraintName      SYSNAME NOT NULL
        , MissingGuidCount    BIGINT NOT NULL
        , CandidateCount      INT NOT NULL
        , Reason              NVARCHAR(4000) NOT NULL
    );

    CREATE TABLE #FkErrors
    (
          ID                  INT IDENTITY(1,1) NOT NULL PRIMARY KEY
        , SchemaName          SYSNAME NOT NULL
        , TableName           SYSNAME NOT NULL
        , ConstraintName      SYSNAME NOT NULL
        , ErrorMessage        NVARCHAR(4000) NOT NULL
    );

    INSERT INTO #DataObjectFkTables
    (
          SchemaName
        , TableName
        , ConstraintName
        , TwoPartName
    )
    SELECT DISTINCT
          s.name AS SchemaName
        , t.name AS TableName
        , fk.name AS ConstraintName
        , QUOTENAME(s.name) + N'.' + QUOTENAME(t.name) AS TwoPartName
    FROM sys.foreign_keys AS fk
    JOIN sys.foreign_key_columns AS fkc
        ON fkc.constraint_object_id = fk.object_id
    JOIN sys.tables AS t
        ON t.object_id = fk.parent_object_id
    JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id
    JOIN sys.columns AS parentCol
        ON parentCol.object_id = fkc.parent_object_id
       AND parentCol.column_id = fkc.parent_column_id
    JOIN sys.columns AS refCol
        ON refCol.object_id = fkc.referenced_object_id
       AND refCol.column_id = fkc.referenced_column_id
    WHERE fk.referenced_object_id = OBJECT_ID(N'SCore.DataObjects', N'U')
      AND parentCol.name = N'Guid'
      AND refCol.name = N'Guid'
      AND EXISTS
      (
          SELECT 1
          FROM sys.columns AS c
          WHERE c.object_id = t.object_id
            AND c.name = N'Guid'
      )
      AND EXISTS
      (
          SELECT 1
          FROM sys.columns AS c
          WHERE c.object_id = t.object_id
            AND c.name = N'RowStatus'
      )
      AND
      (
          @SchemaFilter IS NULL
          OR s.name = @SchemaFilter
      )
    ORDER BY
          s.name
        , t.name
        , fk.name;

    DECLARE
          @WorkId              INT = 0
        , @MaxWorkId           INT
        , @SchemaName          SYSNAME
        , @TableName           SYSNAME
        , @ConstraintName      SYSNAME
        , @TwoPartName         NVARCHAR(517)
        , @MissingGuidCount    BIGINT
        , @stmt                NVARCHAR(MAX);

    SELECT
        @MaxWorkId = MAX(f.WorkId)
    FROM #DataObjectFkTables AS f;

    WHILE @WorkId < ISNULL(@MaxWorkId, 0)
    BEGIN
        SELECT TOP (1)
              @WorkId         = f.WorkId
            , @SchemaName     = f.SchemaName
            , @TableName      = f.TableName
            , @ConstraintName = f.ConstraintName
            , @TwoPartName    = f.TwoPartName
        FROM #DataObjectFkTables AS f
        WHERE f.WorkId > @WorkId
        ORDER BY
            f.WorkId;

        SET @MissingGuidCount = 0;

        SET @stmt = N'
SELECT
    @MissingGuidCount = COUNT_BIG(1)
FROM
(
    SELECT DISTINCT
        t.Guid
    FROM ' + @TwoPartName + N' AS t
    WHERE t.Guid IS NOT NULL
      AND t.Guid <> CONVERT(UNIQUEIDENTIFIER, ''00000000-0000-0000-0000-000000000000'')
      AND NOT EXISTS
      (
          SELECT 1
          FROM SCore.DataObjects AS d
          WHERE d.Guid = t.Guid
      )
) AS MissingRows;
';

        BEGIN TRY
            EXEC sys.sp_executesql
                  @stmt
                , N'@MissingGuidCount BIGINT OUTPUT'
                , @MissingGuidCount = @MissingGuidCount OUTPUT;

            IF @MissingGuidCount > 0
            BEGIN
                INSERT INTO #TablesNeedingRepair
                (
                      SchemaName
                    , TableName
                    , ConstraintName
                    , TwoPartName
                    , MissingGuidCount
                )
                VALUES
                (
                      @SchemaName
                    , @TableName
                    , @ConstraintName
                    , @TwoPartName
                    , @MissingGuidCount
                );
            END;
        END TRY
        BEGIN CATCH
            INSERT INTO SCore.PostDeploymentRunLog
            (
                  RunGuid
                , StepName
                , ObjectName
                , Severity
                , Message
                , ErrorNumber
                , ErrorSeverity
                , ErrorState
                , ErrorLine
                , ErrorProcedure
            )
            VALUES
            (
                  @RunGuid
                , N'DataObjects FK-backed repair - scan'
                , @TwoPartName
                , N'Error'
                , ERROR_MESSAGE()
                , ERROR_NUMBER()
                , ERROR_SEVERITY()
                , ERROR_STATE()
                , ERROR_LINE()
                , ERROR_PROCEDURE()
            );
        END CATCH;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM #TablesNeedingRepair AS r
    )
    BEGIN
        INSERT INTO SCore.PostDeploymentRunLog
        (
              RunGuid
            , StepName
            , Severity
            , Message
        )
        VALUES
        (
              @RunGuid
            , N'DataObjects FK-backed repair'
            , N'Info'
            , N'No FK-backed tables have missing SCore.DataObjects rows.'
        );

        RETURN;
    END;

    ;WITH CandidateMappings AS
    (
        SELECT
              r.SchemaName
            , r.TableName
            , r.ConstraintName
            , r.TwoPartName
            , r.MissingGuidCount
            , et.ID AS EntityTypeId
            , et.Name AS EntityTypeName
            , CAST(1 AS INT) AS PriorityOrder
            , CAST(N'EntityHoBT exact main mapping' AS NVARCHAR(100)) AS ResolutionPath
        FROM #TablesNeedingRepair AS r
        JOIN SCore.EntityHoBTs AS h
            ON h.SchemaName = r.SchemaName
           AND h.ObjectName = r.TableName
           AND h.ObjectType = N'U'
           AND h.RowStatus NOT IN (0, 254)
           AND ISNULL(h.IsMainHoBT, 0) = 1
        JOIN SCore.EntityTypes AS et
            ON et.ID = h.EntityTypeID
           AND et.RowStatus = 1

        UNION ALL

        SELECT
              r.SchemaName
            , r.TableName
            , r.ConstraintName
            , r.TwoPartName
            , r.MissingGuidCount
            , et.ID AS EntityTypeId
            , et.Name AS EntityTypeName
            , CAST(2 AS INT) AS PriorityOrder
            , CAST(N'EntityHoBT exact active mapping' AS NVARCHAR(100)) AS ResolutionPath
        FROM #TablesNeedingRepair AS r
        JOIN SCore.EntityHoBTs AS h
            ON h.SchemaName = r.SchemaName
           AND h.ObjectName = r.TableName
           AND h.ObjectType = N'U'
           AND h.RowStatus NOT IN (0, 254)
        JOIN SCore.EntityTypes AS et
            ON et.ID = h.EntityTypeID
           AND et.RowStatus = 1

        UNION ALL

        SELECT
              r.SchemaName
            , r.TableName
            , r.ConstraintName
            , r.TwoPartName
            , r.MissingGuidCount
            , et.ID AS EntityTypeId
            , et.Name AS EntityTypeName
            , CAST(3 AS INT) AS PriorityOrder
            , CAST(N'EntityType exact name fallback' AS NVARCHAR(100)) AS ResolutionPath
        FROM #TablesNeedingRepair AS r
        JOIN SCore.EntityTypes AS et
            ON et.Name = r.TableName
           AND et.RowStatus = 1

        UNION ALL

        SELECT
              r.SchemaName
            , r.TableName
            , r.ConstraintName
            , r.TwoPartName
            , r.MissingGuidCount
            , et.ID AS EntityTypeId
            , et.Name AS EntityTypeName
            , CAST(4 AS INT) AS PriorityOrder
            , CAST(N'EntityType normalised name fallback' AS NVARCHAR(100)) AS ResolutionPath
        FROM #TablesNeedingRepair AS r
        JOIN SCore.EntityTypes AS et
            ON REPLACE(REPLACE(REPLACE(et.Name, N' ', N''), N'_', N''), N'-', N'')
             = REPLACE(REPLACE(REPLACE(r.TableName, N' ', N''), N'_', N''), N'-', N'')
           AND et.RowStatus = 1
    ),
    BestPriority AS
    (
        SELECT
              cm.SchemaName
            , cm.TableName
            , cm.ConstraintName
            , MIN(cm.PriorityOrder) AS BestPriorityOrder
        FROM CandidateMappings AS cm
        GROUP BY
              cm.SchemaName
            , cm.TableName
            , cm.ConstraintName
    ),
    BestCandidates AS
    (
        SELECT DISTINCT
              cm.SchemaName
            , cm.TableName
            , cm.ConstraintName
            , cm.TwoPartName
            , cm.MissingGuidCount
            , cm.EntityTypeId
            , cm.EntityTypeName
            , cm.ResolutionPath
        FROM CandidateMappings AS cm
        JOIN BestPriority AS bp
            ON bp.SchemaName = cm.SchemaName
           AND bp.TableName = cm.TableName
           AND bp.ConstraintName = cm.ConstraintName
           AND bp.BestPriorityOrder = cm.PriorityOrder
    ),
    CandidateCounts AS
    (
        SELECT
              r.SchemaName
            , r.TableName
            , r.ConstraintName
            , r.TwoPartName
            , r.MissingGuidCount
            , COUNT(DISTINCT bc.EntityTypeId) AS CandidateCount
            , MIN(bc.EntityTypeId) AS EntityTypeId
            , MIN(bc.EntityTypeName) AS EntityTypeName
            , MIN(bc.ResolutionPath) AS ResolutionPath
        FROM #TablesNeedingRepair AS r
        LEFT JOIN BestCandidates AS bc
            ON bc.SchemaName = r.SchemaName
           AND bc.TableName = r.TableName
           AND bc.ConstraintName = r.ConstraintName
        GROUP BY
              r.SchemaName
            , r.TableName
            , r.ConstraintName
            , r.TwoPartName
            , r.MissingGuidCount
    )
    INSERT INTO #ResolvedMappings
    (
          SchemaName
        , TableName
        , ConstraintName
        , TwoPartName
        , EntityTypeId
        , EntityTypeName
        , ResolutionPath
        , MissingGuidCount
    )
    SELECT
          cc.SchemaName
        , cc.TableName
        , cc.ConstraintName
        , cc.TwoPartName
        , cc.EntityTypeId
        , cc.EntityTypeName
        , cc.ResolutionPath
        , cc.MissingGuidCount
    FROM CandidateCounts AS cc
    WHERE cc.CandidateCount = 1;

    ;WITH CandidateMappings AS
    (
        SELECT
              r.SchemaName
            , r.TableName
            , r.ConstraintName
            , et.ID AS EntityTypeId
            , CAST(1 AS INT) AS PriorityOrder
        FROM #TablesNeedingRepair AS r
        JOIN SCore.EntityHoBTs AS h
            ON h.SchemaName = r.SchemaName
           AND h.ObjectName = r.TableName
           AND h.ObjectType = N'U'
           AND h.RowStatus NOT IN (0, 254)
           AND ISNULL(h.IsMainHoBT, 0) = 1
        JOIN SCore.EntityTypes AS et
            ON et.ID = h.EntityTypeID
           AND et.RowStatus = 1

        UNION ALL

        SELECT
              r.SchemaName
            , r.TableName
            , r.ConstraintName
            , et.ID AS EntityTypeId
            , CAST(2 AS INT) AS PriorityOrder
        FROM #TablesNeedingRepair AS r
        JOIN SCore.EntityHoBTs AS h
            ON h.SchemaName = r.SchemaName
           AND h.ObjectName = r.TableName
           AND h.ObjectType = N'U'
           AND h.RowStatus NOT IN (0, 254)
        JOIN SCore.EntityTypes AS et
            ON et.ID = h.EntityTypeID
           AND et.RowStatus = 1

        UNION ALL

        SELECT
              r.SchemaName
            , r.TableName
            , r.ConstraintName
            , et.ID AS EntityTypeId
            , CAST(3 AS INT) AS PriorityOrder
        FROM #TablesNeedingRepair AS r
        JOIN SCore.EntityTypes AS et
            ON et.Name = r.TableName
           AND et.RowStatus = 1

        UNION ALL

        SELECT
              r.SchemaName
            , r.TableName
            , r.ConstraintName
            , et.ID AS EntityTypeId
            , CAST(4 AS INT) AS PriorityOrder
        FROM #TablesNeedingRepair AS r
        JOIN SCore.EntityTypes AS et
            ON REPLACE(REPLACE(REPLACE(et.Name, N' ', N''), N'_', N''), N'-', N'')
             = REPLACE(REPLACE(REPLACE(r.TableName, N' ', N''), N'_', N''), N'-', N'')
           AND et.RowStatus = 1
    ),
    BestPriority AS
    (
        SELECT
              cm.SchemaName
            , cm.TableName
            , cm.ConstraintName
            , MIN(cm.PriorityOrder) AS BestPriorityOrder
        FROM CandidateMappings AS cm
        GROUP BY
              cm.SchemaName
            , cm.TableName
            , cm.ConstraintName
    ),
    BestCandidates AS
    (
        SELECT DISTINCT
              cm.SchemaName
            , cm.TableName
            , cm.ConstraintName
            , cm.EntityTypeId
        FROM CandidateMappings AS cm
        JOIN BestPriority AS bp
            ON bp.SchemaName = cm.SchemaName
           AND bp.TableName = cm.TableName
           AND bp.ConstraintName = cm.ConstraintName
           AND bp.BestPriorityOrder = cm.PriorityOrder
    ),
    CandidateCounts AS
    (
        SELECT
              r.SchemaName
            , r.TableName
            , r.ConstraintName
            , r.MissingGuidCount
            , COUNT(DISTINCT bc.EntityTypeId) AS CandidateCount
        FROM #TablesNeedingRepair AS r
        LEFT JOIN BestCandidates AS bc
            ON bc.SchemaName = r.SchemaName
           AND bc.TableName = r.TableName
           AND bc.ConstraintName = r.ConstraintName
        GROUP BY
              r.SchemaName
            , r.TableName
            , r.ConstraintName
            , r.MissingGuidCount
    )
    INSERT INTO #UnresolvedMappings
    (
          SchemaName
        , TableName
        , ConstraintName
        , MissingGuidCount
        , CandidateCount
        , Reason
    )
    SELECT
          cc.SchemaName
        , cc.TableName
        , cc.ConstraintName
        , cc.MissingGuidCount
        , cc.CandidateCount
        , CASE
              WHEN cc.CandidateCount = 0
                  THEN N'Missing DataObjects rows exist, but no active EntityHoBT or unique active EntityType fallback exists.'
              ELSE N'Missing DataObjects rows exist, but more than one active candidate exists. Cannot safely choose EntityTypeId.'
          END AS Reason
    FROM CandidateCounts AS cc
    WHERE cc.CandidateCount <> 1;

    DECLARE
          @RepairWorkId       INT = 0
        , @MaxRepairWorkId    INT
        , @EntityTypeId       INT
        , @EntityTypeName     NVARCHAR(255)
        , @InsertedRows       INT
        , @ResolutionPath     NVARCHAR(100);

    SELECT
        @MaxRepairWorkId = MAX(rm.WorkId)
    FROM #ResolvedMappings AS rm;

    WHILE @RepairWorkId < ISNULL(@MaxRepairWorkId, 0)
    BEGIN
        SELECT TOP (1)
              @RepairWorkId   = rm.WorkId
            , @SchemaName     = rm.SchemaName
            , @TableName      = rm.TableName
            , @ConstraintName = rm.ConstraintName
            , @TwoPartName    = rm.TwoPartName
            , @EntityTypeId   = rm.EntityTypeId
            , @EntityTypeName = rm.EntityTypeName
            , @ResolutionPath = rm.ResolutionPath
        FROM #ResolvedMappings AS rm
        WHERE rm.WorkId > @RepairWorkId
        ORDER BY
            rm.WorkId;

        SET @InsertedRows = 0;

        SET @stmt = N'
;WITH SourceRows AS
(
    SELECT
          t.Guid
        , CAST(MAX(CONVERT(INT, ISNULL(t.RowStatus, 1))) AS TINYINT) AS RowStatus
    FROM ' + @TwoPartName + N' AS t
    WHERE t.Guid IS NOT NULL
      AND t.Guid <> CONVERT(UNIQUEIDENTIFIER, ''00000000-0000-0000-0000-000000000000'')
    GROUP BY
        t.Guid
)
INSERT INTO SCore.DataObjects
(
      Guid
    , RowStatus
    , EntityTypeId
)
SELECT
      sr.Guid
    , sr.RowStatus
    , @EntityTypeId
FROM SourceRows AS sr
WHERE NOT EXISTS
(
    SELECT 1
    FROM SCore.DataObjects AS d WITH (UPDLOCK, HOLDLOCK)
    WHERE d.Guid = sr.Guid
);

SET @InsertedRows = @@ROWCOUNT;
';

        BEGIN TRY
            EXEC sys.sp_executesql
                  @stmt
                , N'@EntityTypeId INT, @InsertedRows INT OUTPUT'
                , @EntityTypeId = @EntityTypeId
                , @InsertedRows = @InsertedRows OUTPUT;

            INSERT INTO SCore.PostDeploymentRunLog
            (
                  RunGuid
                , StepName
                , ObjectName
                , Severity
                , Message
            )
            VALUES
            (
                  @RunGuid
                , N'DataObjects FK-backed repair'
                , @TwoPartName
                , N'Info'
                , N'Inserted '
                  + CONVERT(NVARCHAR(20), @InsertedRows)
                  + N' missing DataObjects rows using EntityTypeId '
                  + CONVERT(NVARCHAR(20), @EntityTypeId)
                  + N' ('
                  + ISNULL(@EntityTypeName, N'')
                  + N') via '
                  + @ResolutionPath
            );
        END TRY
        BEGIN CATCH
            INSERT INTO SCore.PostDeploymentRunLog
            (
                  RunGuid
                , StepName
                , ObjectName
                , Severity
                , Message
                , ErrorNumber
                , ErrorSeverity
                , ErrorState
                , ErrorLine
                , ErrorProcedure
            )
            VALUES
            (
                  @RunGuid
                , N'DataObjects FK-backed repair'
                , @TwoPartName
                , N'Error'
                , ERROR_MESSAGE()
                , ERROR_NUMBER()
                , ERROR_SEVERITY()
                , ERROR_STATE()
                , ERROR_LINE()
                , ERROR_PROCEDURE()
            );
        END CATCH;
    END;

    INSERT INTO SCore.PostDeploymentRunLog
    (
          RunGuid
        , StepName
        , ObjectName
        , Severity
        , Message
    )
    SELECT
          @RunGuid
        , N'DataObjects FK-backed repair'
        , QUOTENAME(um.SchemaName) + N'.' + QUOTENAME(um.TableName)
        , CASE
              WHEN @ThrowOnUnresolved = 1 THEN N'Error'
              ELSE N'Warning'
          END
        , N'Could not repair '
          + CONVERT(NVARCHAR(20), um.MissingGuidCount)
          + N' missing DataObjects rows for constraint '
          + QUOTENAME(um.ConstraintName)
          + N'. '
          + um.Reason
    FROM #UnresolvedMappings AS um;

    IF @ValidateConstraints = 1
    BEGIN
        SET @RepairWorkId = 0;

        WHILE @RepairWorkId < ISNULL(@MaxRepairWorkId, 0)
        BEGIN
            SELECT TOP (1)
                  @RepairWorkId  = rm.WorkId
                , @SchemaName    = rm.SchemaName
                , @TableName     = rm.TableName
                , @ConstraintName = rm.ConstraintName
                , @TwoPartName   = rm.TwoPartName
            FROM #ResolvedMappings AS rm
            WHERE rm.WorkId > @RepairWorkId
            ORDER BY
                rm.WorkId;

            SET @stmt =
                  N'ALTER TABLE '
                + @TwoPartName
                + N' WITH CHECK CHECK CONSTRAINT '
                + QUOTENAME(@ConstraintName)
                + N';';

            BEGIN TRY
                EXEC sys.sp_executesql @stmt;

                INSERT INTO SCore.PostDeploymentRunLog
                (
                      RunGuid
                    , StepName
                    , ObjectName
                    , Severity
                    , Message
                )
                VALUES
                (
                      @RunGuid
                    , N'DataObjects FK-backed repair - FK validate'
                    , @TwoPartName
                    , N'Info'
                    , N'Constraint validated: ' + QUOTENAME(@ConstraintName)
                );
            END TRY
            BEGIN CATCH
                INSERT INTO SCore.PostDeploymentRunLog
                (
                      RunGuid
                    , StepName
                    , ObjectName
                    , Severity
                    , Message
                    , ErrorNumber
                    , ErrorSeverity
                    , ErrorState
                    , ErrorLine
                    , ErrorProcedure
                )
                VALUES
                (
                      @RunGuid
                    , N'DataObjects FK-backed repair - FK validate'
                    , @TwoPartName
                    , N'Error'
                    , ERROR_MESSAGE()
                    , ERROR_NUMBER()
                    , ERROR_SEVERITY()
                    , ERROR_STATE()
                    , ERROR_LINE()
                    , ERROR_PROCEDURE()
                );
            END CATCH;
        END;
    END;

    INSERT INTO SCore.PostDeploymentRunLog
    (
          RunGuid
        , StepName
        , Severity
        , Message
    )
    VALUES
    (
          @RunGuid
        , N'DataObjects FK-backed repair'
        , N'Info'
        , N'Completed FK-backed DataObjects repair.'
    );
END;
GO