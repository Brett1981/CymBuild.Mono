SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[SCHEMABINDING]')
GO

CREATE OR ALTER PROCEDURE [SCore].[SCHEMABINDING]
(
    @Apply   BIT = 1,               -- 1 = enable schemabinding, 0 = disable schemabinding
    @Strict  BIT = 0,               -- 0 = do not fail deployment if some objects cannot be processed (recommended)
    @RunGuid UNIQUEIDENTIFIER = NULL -- correlates durable log rows to a deployment run; a fresh one is generated when omitted
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @CurrentString NVARCHAR(25),
        @NewString     NVARCHAR(25),
        @Pass          INT = 0,
        @MaxPasses     INT = 50,
        @SucceededThisPass INT,
        @AttemptSql    NVARCHAR(MAX),
        @ObjectId      INT,
        @Err           INT,
        @CanLog        BIT = 0,
        @LeadingCreatePos INT;

    IF @RunGuid IS NULL
        SET @RunGuid = NEWID();

    IF OBJECT_ID(N'SCore.PostDeploymentRunLog', N'U') IS NOT NULL
        SET @CanLog = 1;

    IF @Apply = 1
    BEGIN
        SET @CurrentString = N'--WITH SCHEMABINDING';
        SET @NewString     = N' WITH SCHEMABINDING';
    END
    ELSE
    BEGIN
        SET @CurrentString = N'WITH SCHEMABINDING';
        SET @NewString     = N'--WITH SCHEMABINDING';
    END;

    -------------------------------------------------------------------------
    -- Work list
    -------------------------------------------------------------------------
    DECLARE @Work TABLE
    (
        ObjectId      INT           NOT NULL PRIMARY KEY,
        FullName      NVARCHAR(512) NOT NULL,
        ObjectType    CHAR(2)       NOT NULL,     -- V, IF, TF, FN
        ObjectTypeName NVARCHAR(30) NOT NULL,
        DefinitionSql NVARCHAR(MAX) NOT NULL,

        Done          BIT           NOT NULL DEFAULT(0),
        Failed        BIT           NOT NULL DEFAULT(0),
        Deferred      BIT           NOT NULL DEFAULT(0),
        LastError     INT           NULL
    );

    -------------------------------------------------------------------------
    -- Error log
    -------------------------------------------------------------------------
    DECLARE @Errors TABLE
    (
        Pass          INT           NOT NULL,
        FullName      NVARCHAR(512) NOT NULL,
        ObjectType    NVARCHAR(30)  NOT NULL,
        ErrorNumber   INT           NULL,
        ErrorSeverity INT           NULL,
        ErrorState    INT           NULL,
        ErrorLine     INT           NULL,
        ErrorMessage  NVARCHAR(MAX) NULL,
        AttemptedSql  NVARCHAR(MAX) NULL,
        LoggedAtUtc   DATETIME2(7)  NOT NULL DEFAULT SYSUTCDATETIME()
    );

    -------------------------------------------------------------------------
    -- Load candidates by their authoritative SQL Server binding state.
    -- A bound module can legitimately retain a prepared marker when altering it
    -- is blocked by another schema-bound dependent. It must still be disabled
    -- during the next pre-deployment lifecycle.
    -------------------------------------------------------------------------
    ;WITH Candidates AS
    (
        SELECT
            o.object_id,
            QUOTENAME(SCHEMA_NAME(o.schema_id)) + N'.' + QUOTENAME(o.name) AS FullName,
            o.type,
            sm.definition AS Defn
        FROM sys.objects o
        JOIN sys.sql_modules sm
            ON sm.object_id = o.object_id
        WHERE
            o.is_ms_shipped = 0
            AND o.type IN ('V','IF','TF','FN')
            AND sm.definition IS NOT NULL
            AND
            (
                (@Apply = 0 AND sm.is_schema_bound = 1)
                OR
                (
                    @Apply = 1
                    AND sm.is_schema_bound = 0
                    AND sm.definition LIKE N'%' + @CurrentString + N'%'
                )
            )
            AND NOT EXISTS
            (
                SELECT 1
                FROM sys.computed_columns cc
                WHERE cc.definition LIKE N'%' + o.name + N'%'
            )
    )
    INSERT @Work (ObjectId, FullName, ObjectType, ObjectTypeName, DefinitionSql)
    SELECT
        c.object_id,
        c.FullName,
        c.type,
        CASE c.type
            WHEN 'V'  THEN N'VIEW'
            WHEN 'IF' THEN N'INLINE_TVF'
            WHEN 'TF' THEN N'MULTI_TVF'
            WHEN 'FN' THEN N'SCALAR_FN'
            ELSE c.type
        END,
        c.Defn
    FROM Candidates c;

    IF NOT EXISTS (SELECT 1 FROM @Work)
        RETURN;

    -------------------------------------------------------------------------
    -- Helper: attempt ordering differs by enable/disable
    -- Disable: views first then functions.
    -- Enable : functions first then views.
    -------------------------------------------------------------------------
    WHILE EXISTS (SELECT 1 FROM @Work WHERE Done = 0 AND Failed = 0)
    BEGIN
        SET @Pass += 1;
        IF @Pass > @MaxPasses
            BREAK;

        SET @SucceededThisPass = 0;

        UPDATE @Work SET Deferred = 0 WHERE Done = 0 AND Failed = 0;

        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT w.ObjectId
        FROM @Work w
        WHERE w.Done = 0 AND w.Failed = 0
        ORDER BY
            CASE
                WHEN @Apply = 0 THEN -- DISABLE
                    CASE w.ObjectType
                        WHEN 'V'  THEN 1
                        WHEN 'IF' THEN 2
                        WHEN 'TF' THEN 3
                        WHEN 'FN' THEN 4
                        ELSE 9
                    END
                ELSE -- ENABLE
                    CASE w.ObjectType
                        WHEN 'IF' THEN 1
                        WHEN 'TF' THEN 2
                        WHEN 'FN' THEN 3
                        WHEN 'V'  THEN 4
                        ELSE 9
                    END
            END,
            w.FullName;

        OPEN cur;
        FETCH NEXT FROM cur INTO @ObjectId;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @AttemptSql =
                REPLACE(
                    REPLACE(w.DefinitionSql, @CurrentString, @NewString),
                    N'----WITH SCHEMABINDING', N'--WITH SCHEMABINDING'
                )
            FROM @Work w
            WHERE w.ObjectId = @ObjectId;

            -----------------------------------------------------------------
            -- Convert only the leading CREATE keyword to ALTER. A blind
            -- REPLACE of every "CREATE " occurrence corrupts any identifier
            -- that happens to contain the word (for example DECLARE
            -- @JobsToCreate INT), turning a later, unmatched reference to it
            -- into a "must declare the scalar variable" compile error. The
            -- object's definition always begins with its own CREATE keyword,
            -- so only the first occurrence is ever the one we mean to touch.
            -----------------------------------------------------------------
            SET @LeadingCreatePos = CHARINDEX(N'CREATE ', @AttemptSql);
            IF @LeadingCreatePos > 0
                SET @AttemptSql = STUFF(@AttemptSql, @LeadingCreatePos, LEN(N'CREATE '), N'ALTER ');

            BEGIN TRY
                EXEC sys.sp_executesql @AttemptSql;

                UPDATE @Work
                SET Done = 1
                WHERE ObjectId = @ObjectId;

                SET @SucceededThisPass += 1;
            END TRY
            BEGIN CATCH
                SET @Err = ERROR_NUMBER();

                INSERT @Errors
                (
                    Pass, FullName, ObjectType, ErrorNumber, ErrorSeverity, ErrorState, ErrorLine, ErrorMessage, AttemptedSql
                )
                SELECT
                    @Pass,
                    w.FullName,
                    w.ObjectTypeName,
                    ERROR_NUMBER(),
                    ERROR_SEVERITY(),
                    ERROR_STATE(),
                    ERROR_LINE(),
                    ERROR_MESSAGE(),
                    @AttemptSql
                FROM @Work w
                WHERE w.ObjectId = @ObjectId;

                -----------------------------------------------------------------
                -- Classification:
                -- 3729 = referenced by another object -> defer (maybe later)
                -- 4513 = schemabinding blocked because dependency not schemabound -> defer
                -- Any other error = hard fail (compile error, missing variable, etc.)
                -----------------------------------------------------------------
                -- @Errors is a local table variable: it evaporates when this
                -- procedure returns, and PowerShell invokes this proc via
                -- ExecuteNonQuery, which discards any result set. Without a
                -- durable row here, a deferred-then-never-recovered object
                -- (for example one still bound at the very end of the retry
                -- loop) leaves no trace anywhere once deployment moves on.
                IF @CanLog = 1
                BEGIN
                    INSERT INTO SCore.PostDeploymentRunLog
                    (
                        RunGuid, StepName, ObjectName, Severity, Message,
                        ErrorNumber, ErrorSeverity, ErrorState, ErrorLine
                    )
                    SELECT
                        @RunGuid,
                        CASE WHEN @Apply = 0 THEN N'Schema binding pre-deployment disable' ELSE N'Schema binding pre-deployment enable' END,
                        w.FullName,
                        CASE WHEN @Err IN (3729,4513) THEN N'Warning' ELSE N'Error' END,
                        N'Pass ' + CONVERT(NVARCHAR(20), @Pass) + N': ' + ERROR_MESSAGE(),
                        ERROR_NUMBER(),
                        ERROR_SEVERITY(),
                        ERROR_STATE(),
                        ERROR_LINE()
                    FROM @Work w
                    WHERE w.ObjectId = @ObjectId;
                END;

                UPDATE w
                SET
                    LastError = @Err,
                    Deferred  = CASE WHEN @Err IN (3729,4513) THEN 1 ELSE 0 END,
                    Failed    = CASE WHEN @Err IN (3729,4513) THEN 0 ELSE 1 END
                FROM @Work w
                WHERE w.ObjectId = @ObjectId;
            END CATCH;

            FETCH NEXT FROM cur INTO @ObjectId;
        END

        CLOSE cur;
        DEALLOCATE cur;

        IF @SucceededThisPass = 0
            BREAK;
    END;

    -------------------------------------------------------------------------
    -- Results
    -------------------------------------------------------------------------
    IF EXISTS (SELECT 1 FROM @Work WHERE Failed = 1 OR Done = 0)
    BEGIN
        -- Always show errors for diagnostics
        SELECT * FROM @Errors ORDER BY LoggedAtUtc, FullName;

        -- Durable summary: every object left bound (or unbound, on the enable
        -- path) when this procedure gives up, so the next dependent ALTER's
        -- failure downstream in the deployment can be traced back to a cause
        -- instead of a bare "referenced by object" error with no history.
        IF @CanLog = 1
        BEGIN
            INSERT INTO SCore.PostDeploymentRunLog
            (
                RunGuid, StepName, ObjectName, Severity, Message, ErrorNumber
            )
            SELECT
                @RunGuid,
                CASE WHEN @Apply = 0 THEN N'Schema binding pre-deployment disable' ELSE N'Schema binding pre-deployment enable' END,
                w.FullName,
                N'Error',
                CASE
                    WHEN w.Failed = 1 THEN N'Object never processed to completion; last error ' + ISNULL(CONVERT(NVARCHAR(20), w.LastError), N'?') + N'.'
                    ELSE N'Object still deferred after the maximum number of retry passes (' + CONVERT(NVARCHAR(20), @MaxPasses) + N').'
                END,
                w.LastError
            FROM @Work w
            WHERE w.Failed = 1 OR w.Done = 0;
        END;

        IF @Strict = 1
        BEGIN
            THROW 60000, N'Failed Schemabinding (see error list)', 1;
        END;

        -- Non-strict: do not block deployment
        RETURN;
    END;
END;
GO
