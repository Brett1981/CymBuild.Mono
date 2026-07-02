SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[DataObjectsRepairForKnownEntityTypeFallbackTables]')
GO

CREATE PROCEDURE [SCore].[DataObjectsRepairForKnownEntityTypeFallbackTables]
(
      @ValidateConstraints BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    PRINT N'Repair DataObjects for known EntityType fallback tables';

    DECLARE @KnownTables TABLE
    (
          WorkId                 INT IDENTITY(1,1) NOT NULL PRIMARY KEY
        , SchemaName             SYSNAME NOT NULL
        , TableName              SYSNAME NOT NULL
        , ExpectedEntityTypeName  NVARCHAR(255) NOT NULL
        , ConstraintName          SYSNAME NOT NULL
    );

    INSERT INTO @KnownTables
    (
          SchemaName
        , TableName
        , ExpectedEntityTypeName
        , ConstraintName
    )
    VALUES
          (N'SFin', N'InvoiceAutomationRuns',       N'Invoice Automation Runs',        N'FK_InvoiceAutomationRuns_DataObjects')
        , (N'SFin', N'InvoiceAutomationRunDetails', N'Invoice Automation Run Details', N'FK_InvoiceAutomationRunDetails_DataObjects');

    DECLARE
          @WorkId                 INT = 0
        , @MaxWorkId              INT
        , @SchemaName             SYSNAME
        , @TableName              SYSNAME
        , @ExpectedEntityTypeName NVARCHAR(255)
        , @ConstraintName         SYSNAME
        , @TwoPartName            NVARCHAR(517)
        , @EntityTypeId           INT
        , @CandidateCount         INT
        , @InsertedRows           INT
        , @MissingBefore          BIGINT
        , @MissingAfter           BIGINT
        , @stmt                   NVARCHAR(MAX);

    SELECT
        @MaxWorkId = MAX(kt.WorkId)
    FROM @KnownTables AS kt;

    WHILE @WorkId < ISNULL(@MaxWorkId, 0)
    BEGIN
        SELECT TOP (1)
              @WorkId                 = kt.WorkId
            , @SchemaName             = kt.SchemaName
            , @TableName              = kt.TableName
            , @ExpectedEntityTypeName = kt.ExpectedEntityTypeName
            , @ConstraintName         = kt.ConstraintName
        FROM @KnownTables AS kt
        WHERE kt.WorkId > @WorkId
        ORDER BY
            kt.WorkId;

        SET @TwoPartName = QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName);
        SET @EntityTypeId = NULL;
        SET @CandidateCount = 0;
        SET @InsertedRows = 0;
        SET @MissingBefore = 0;
        SET @MissingAfter = 0;

        IF OBJECT_ID(@TwoPartName, N'U') IS NULL
        BEGIN
            PRINT N'Skipping missing table: ' + @TwoPartName;
            CONTINUE;
        END;

        IF NOT EXISTS
        (
            SELECT 1
            FROM sys.foreign_keys AS fk
            WHERE fk.parent_object_id = OBJECT_ID(@TwoPartName, N'U')
              AND fk.name = @ConstraintName
              AND fk.referenced_object_id = OBJECT_ID(N'SCore.DataObjects', N'U')
        )
        BEGIN
            PRINT N'Skipping table because expected DataObjects FK was not found: '
                + @TwoPartName
                + N'.'
                + QUOTENAME(@ConstraintName);

            CONTINUE;
        END;

        SELECT
              @CandidateCount = COUNT_BIG(1)
            , @EntityTypeId = MIN(et.ID)
        FROM SCore.EntityTypes AS et
        WHERE et.RowStatus = 1
          AND
          (
              et.Name = @ExpectedEntityTypeName
              OR REPLACE(REPLACE(REPLACE(et.Name, N' ', N''), N'_', N''), N'-', N'')
               = REPLACE(REPLACE(REPLACE(@ExpectedEntityTypeName, N' ', N''), N'_', N''), N'-', N'')
          );

        IF @CandidateCount <> 1 OR @EntityTypeId IS NULL
        BEGIN
            SELECT
                  kt.SchemaName
                , kt.TableName
                , kt.ExpectedEntityTypeName
                , CandidateCount = @CandidateCount
            FROM @KnownTables AS kt
            WHERE kt.WorkId = @WorkId;

            THROW 51060, N'Cannot repair known EntityType fallback table because exactly one active EntityType could not be resolved.', 1;
        END;

        SET @stmt = N'
SELECT
    @MissingBefore = COUNT_BIG(1)
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

        EXEC sys.sp_executesql
              @stmt
            , N'@MissingBefore BIGINT OUTPUT'
            , @MissingBefore = @MissingBefore OUTPUT;

        IF @MissingBefore = 0
        BEGIN
            PRINT N'No missing DataObjects rows for ' + @TwoPartName;
        END
        ELSE
        BEGIN
            PRINT N'Repairing DataObjects for '
                + @TwoPartName
                + N' using EntityTypeId '
                + CONVERT(NVARCHAR(20), @EntityTypeId)
                + N' from known EntityType fallback: '
                + @ExpectedEntityTypeName;

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

            EXEC sys.sp_executesql
                  @stmt
                , N'@EntityTypeId INT, @InsertedRows INT OUTPUT'
                , @EntityTypeId = @EntityTypeId
                , @InsertedRows = @InsertedRows OUTPUT;

            PRINT N'  Inserted missing DataObjects rows: '
                + CONVERT(NVARCHAR(20), @InsertedRows);
        END;

        SET @stmt = N'
SELECT
    @MissingAfter = COUNT_BIG(1)
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

        EXEC sys.sp_executesql
              @stmt
            , N'@MissingAfter BIGINT OUTPUT'
            , @MissingAfter = @MissingAfter OUTPUT;

        IF @MissingAfter > 0
        BEGIN
            SELECT
                  SchemaName = @SchemaName
                , TableName = @TableName
                , ConstraintName = @ConstraintName
                , ExpectedEntityTypeName = @ExpectedEntityTypeName
                , EntityTypeId = @EntityTypeId
                , MissingBefore = @MissingBefore
                , MissingAfter = @MissingAfter;

            THROW 51061, N'Known EntityType fallback repair did not resolve all missing DataObjects rows.', 1;
        END;

        IF @ValidateConstraints = 1
        BEGIN
            SET @stmt =
                  N'ALTER TABLE '
                + @TwoPartName
                + N' WITH CHECK CHECK CONSTRAINT '
                + QUOTENAME(@ConstraintName)
                + N';';

            PRINT @stmt;
            EXEC sys.sp_executesql @stmt;
        END;
    END;

    PRINT N'Known EntityType fallback DataObjects repair complete.';
END;
GO