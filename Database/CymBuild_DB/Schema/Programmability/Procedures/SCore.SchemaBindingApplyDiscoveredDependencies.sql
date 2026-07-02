SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[SchemaBindingApplyDiscoveredDependencies]')
GO

CREATE PROCEDURE [SCore].[SchemaBindingApplyDiscoveredDependencies]
(
      @RunGuid       UNIQUEIDENTIFIER = NULL
    , @Apply         BIT = 1
    , @MaxPasses     INT = 6
    , @ThrowOnError  BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
          @OwnRunGuid      BIT = 0
        , @CanLog          BIT = 0
        , @Pass            INT = 0
        , @BeforeCount     BIGINT = 0
        , @AfterCount      BIGINT = 0
        , @MadeProgress    BIT = 1;

    IF @RunGuid IS NULL
    BEGIN
        SET @RunGuid = NEWID();
        SET @OwnRunGuid = 1;
    END;

    IF OBJECT_ID(N'SCore.PostDeploymentRunLog', N'U') IS NOT NULL
        SET @CanLog = 1;

    IF @CanLog = 1
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
            , N'Schema binding dependency discovery'
            , N'Info'
            , N'Started schema-binding dependency discovery.'
        );
    END;

    WHILE @Pass < @MaxPasses
      AND @MadeProgress = 1
    BEGIN
        SET @Pass += 1;

        SELECT
            @BeforeCount = COUNT_BIG(1)
        FROM sys.sql_modules AS sm
        JOIN sys.objects AS o
            ON o.object_id = sm.object_id
        WHERE sm.is_schema_bound = 1
          AND o.is_ms_shipped = 0
          AND o.type IN (N'V', N'IF', N'FN', N'TF');

        IF OBJECT_ID(N'tempdb..#SchemaBindingTargets') IS NOT NULL
            DROP TABLE #SchemaBindingTargets;

        CREATE TABLE #SchemaBindingTargets
        (
              WorkId       INT IDENTITY(1,1) NOT NULL PRIMARY KEY
            , ObjectId     INT NOT NULL
            , SchemaName   SYSNAME NOT NULL
            , ObjectName   SYSNAME NOT NULL
            , ObjectType   CHAR(2) NOT NULL
            , TwoPartName  NVARCHAR(517) NOT NULL
        );

        /*
            Discover dependencies which are themselves SQL modules and are not yet schema-bound.

            Auto-apply is restricted to:
            - Views
            - Inline TVFs

            Multi-statement TVFs and scalar functions can be added later once the parser is
            made more defensive for those definitions.
        */
        INSERT INTO #SchemaBindingTargets
        (
              ObjectId
            , SchemaName
            , ObjectName
            , ObjectType
            , TwoPartName
        )
        SELECT DISTINCT
              referencedObject.object_id
            , referencedSchema.name
            , referencedObject.name
            , referencedObject.type
            , QUOTENAME(referencedSchema.name) + N'.' + QUOTENAME(referencedObject.name)
        FROM sys.sql_expression_dependencies AS dep
        JOIN sys.objects AS referencingObject
            ON referencingObject.object_id = dep.referencing_id
        JOIN sys.sql_modules AS referencingModule
            ON referencingModule.object_id = referencingObject.object_id
        JOIN sys.objects AS referencedObject
            ON referencedObject.object_id = dep.referenced_id
        JOIN sys.schemas AS referencedSchema
            ON referencedSchema.schema_id = referencedObject.schema_id
        JOIN sys.sql_modules AS referencedModule
            ON referencedModule.object_id = referencedObject.object_id
        WHERE dep.referenced_id IS NOT NULL
          AND referencingObject.is_ms_shipped = 0
          AND referencedObject.is_ms_shipped = 0
          AND referencingObject.object_id <> referencedObject.object_id
          AND referencingObject.type IN (N'V', N'IF', N'FN', N'TF')
          AND referencedObject.type IN (N'V', N'IF')
          AND referencedModule.is_schema_bound = 0
          AND referencedSchema.name NOT IN (N'sys', N'INFORMATION_SCHEMA')
        ORDER BY
              referencedSchema.name
            , referencedObject.name;

        IF @CanLog = 1
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
                , N'Schema binding dependency discovery'
                , N'Info'
                , N'Pass '
                  + CONVERT(NVARCHAR(20), @Pass)
                  + N' discovered '
                  + CONVERT(NVARCHAR(20), (SELECT COUNT_BIG(1) FROM #SchemaBindingTargets))
                  + N' unbound dependency candidates.'
            );
        END;

        DECLARE
              @WorkId      INT = 0
            , @MaxWorkId   INT
            , @ObjectId    INT
            , @TwoPartName NVARCHAR(517);

        SELECT
            @MaxWorkId = MAX(t.WorkId)
        FROM #SchemaBindingTargets AS t;

        WHILE @WorkId < ISNULL(@MaxWorkId, 0)
        BEGIN
            SELECT TOP (1)
                  @WorkId      = t.WorkId
                , @ObjectId    = t.ObjectId
                , @TwoPartName = t.TwoPartName
            FROM #SchemaBindingTargets AS t
            WHERE t.WorkId > @WorkId
            ORDER BY
                t.WorkId;

            PRINT N'Applying discovered schema-binding dependency: ' + @TwoPartName;

            EXEC SCore.SchemaBindingApplySingleObject
                  @ObjectId = @ObjectId
                , @RunGuid = @RunGuid
                , @Apply = @Apply
                , @ThrowOnError = 0;
        END;

        SELECT
            @AfterCount = COUNT_BIG(1)
        FROM sys.sql_modules AS sm
        JOIN sys.objects AS o
            ON o.object_id = sm.object_id
        WHERE sm.is_schema_bound = 1
          AND o.is_ms_shipped = 0
          AND o.type IN (N'V', N'IF', N'FN', N'TF');

        IF @CanLog = 1
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
                , N'Schema binding dependency discovery'
                , CASE
                    WHEN @AfterCount > @BeforeCount THEN N'Info'
                    ELSE N'Warning'
                  END
                , N'Pass '
                  + CONVERT(NVARCHAR(20), @Pass)
                  + N' complete. Schema-bound module count before: '
                  + CONVERT(NVARCHAR(20), @BeforeCount)
                  + N', after: '
                  + CONVERT(NVARCHAR(20), @AfterCount)
            );
        END;

        IF @AfterCount > @BeforeCount
            SET @MadeProgress = 1;
        ELSE
            SET @MadeProgress = 0;
    END;

    IF @CanLog = 1
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
            , N'Schema binding dependency discovery'
            , N'Info'
            , N'Completed schema-binding dependency discovery.'
        );
    END;

    IF @OwnRunGuid = 1
       AND @CanLog = 1
    BEGIN
        SELECT
              RunGuid = @RunGuid;

        SELECT
              ID
            , StepName
            , ObjectName
            , Severity
            , Message
            , ErrorNumber
            , ErrorSeverity
            , ErrorState
            , ErrorLine
            , ErrorProcedure
            , CreatedUtc
        FROM SCore.PostDeploymentRunLog
        WHERE RunGuid = @RunGuid
        ORDER BY
            ID;
    END;
END;
GO