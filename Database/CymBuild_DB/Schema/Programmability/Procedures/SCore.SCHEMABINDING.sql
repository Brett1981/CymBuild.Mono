SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create procedure [SCore].[SCHEMABINDING]')
GO

CREATE PROCEDURE [SCore].[SCHEMABINDING]
(
    @Apply  BIT = 1,   -- 1 = enable schemabinding, 0 = disable schemabinding
    @Strict BIT = 0    -- 0 = do not fail deployment if some objects cannot be processed (recommended)
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
        @Err           INT;

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
    -- Load candidates (ONLY those containing the marker and not already swapped)
    -------------------------------------------------------------------------
    ;WITH Candidates AS
    (
        SELECT
            o.object_id,
            QUOTENAME(SCHEMA_NAME(o.schema_id)) + N'.' + QUOTENAME(o.name) AS FullName,
            o.type,
            OBJECT_DEFINITION(o.object_id) AS Defn
        FROM sys.objects o
        WHERE
            o.is_ms_shipped = 0
            AND o.type IN ('V','IF','TF','FN')
            AND OBJECT_DEFINITION(o.object_id) IS NOT NULL
            AND OBJECT_DEFINITION(o.object_id) LIKE N'%' + @CurrentString + N'%'
            AND OBJECT_DEFINITION(o.object_id) NOT LIKE N'%' + @NewString + N'%'
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
                    REPLACE(
                        REPLACE(w.DefinitionSql, @CurrentString, @NewString),
                        N'----WITH SCHEMABINDING', N'--WITH SCHEMABINDING'
                    ),
                    N'CREATE ', N'ALTER '
                )
            FROM @Work w
            WHERE w.ObjectId = @ObjectId;

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

        IF @Strict = 1
        BEGIN
            THROW 60000, N'Failed Schemabinding (see error list)', 1;
        END;

        -- Non-strict: do not block deployment
        RETURN;
    END;
END;
GO