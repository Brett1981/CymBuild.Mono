SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[SchemaBindingApplySingleObject]')
GO

CREATE PROCEDURE [SCore].[SchemaBindingApplySingleObject]
(
      @ObjectId       INT
    , @RunGuid        UNIQUEIDENTIFIER = NULL
    , @Apply          BIT = 1
    , @ThrowOnError   BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;

    DECLARE
          @ObjectName       SYSNAME
        , @SchemaName       SYSNAME
        , @ObjectType       CHAR(2)
        , @TwoPartName      NVARCHAR(517)
        , @Definition       NVARCHAR(MAX)
        , @Sql              NVARCHAR(MAX)
        , @Search           NVARCHAR(MAX)
        , @DdlStart         INT
        , @KeywordPos       INT
        , @AsPos            INT
        , @ReturnsPos       INT
        , @CanLog           BIT = 0;

    IF @RunGuid IS NULL
        SET @RunGuid = NEWID();

    IF OBJECT_ID(N'SCore.PostDeploymentRunLog', N'U') IS NOT NULL
        SET @CanLog = 1;

    SELECT
          @ObjectName  = o.name
        , @SchemaName  = s.name
        , @ObjectType  = o.type
        , @TwoPartName = QUOTENAME(s.name) + N'.' + QUOTENAME(o.name)
        , @Definition  = sm.definition
    FROM sys.objects AS o
    JOIN sys.schemas AS s
        ON s.schema_id = o.schema_id
    JOIN sys.sql_modules AS sm
        ON sm.object_id = o.object_id
    WHERE o.object_id = @ObjectId
      AND o.is_ms_shipped = 0;

    IF @ObjectName IS NULL
        RETURN;

    IF @Definition IS NULL
    BEGIN
        IF @CanLog = 1
        BEGIN
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
                , N'Schema binding dependency discovery'
                , @TwoPartName
                , N'Warning'
                , N'Skipped because module definition is NULL, possibly encrypted.'
            );
        END;

        RETURN;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM sys.sql_modules AS sm
        WHERE sm.object_id = @ObjectId
          AND sm.is_schema_bound = 1
    )
    BEGIN
        RETURN;
    END;

    /*
        Supported:
        V  = View
        IF = Inline TVF
        TF = Multi-statement TVF
        FN = Scalar function

        The procedure only injects WITH SCHEMABINDING.
        SQL Server may still reject the object later if it contains invalid
        schema-bound syntax such as SELECT *, one-part names, non-deterministic
        functions, or unbound dependencies.
    */
    IF @ObjectType NOT IN (N'V', N'IF', N'TF', N'FN')
    BEGIN
        IF @CanLog = 1
        BEGIN
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
                , N'Schema binding dependency discovery'
                , @TwoPartName
                , N'Warning'
                , N'Skipped automatic WITH SCHEMABINDING injection because object type '
                  + ISNULL(@ObjectType, N'?')
                  + N' is not supported.'
            );
        END;

        RETURN;
    END;

    BEGIN TRY
        SET @Sql = @Definition;

        /*
            Keep the same string length as the original by replacing CR/LF/TAB
            with spaces. This means positions found in @Search still line up
            with @Sql for STUFF().
        */
        SET @Search = UPPER(REPLACE(REPLACE(REPLACE(@Sql, CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' '));

        /* =====================================================================================
           VIEW
        ===================================================================================== */
        IF @ObjectType = N'V'
        BEGIN
            SET @DdlStart = NULL;

            SET @DdlStart = NULLIF(PATINDEX(N'%CREATE%OR%ALTER%VIEW%', @Search), 0);

            IF @DdlStart IS NULL
                SET @DdlStart = NULLIF(PATINDEX(N'%ALTER%VIEW%', @Search), 0);

            IF @DdlStart IS NULL
                SET @DdlStart = NULLIF(PATINDEX(N'%CREATE%VIEW%', @Search), 0);

            IF @DdlStart IS NULL
                THROW 51200, N'Could not find CREATE/ALTER VIEW token while generating schema-bound SQL.', 1;

            SET @KeywordPos = CHARINDEX(N'VIEW', @Search, @DdlStart);

            IF @KeywordPos = 0
                THROW 51201, N'Could not find VIEW keyword while generating schema-bound SQL.', 1;

            /*
                Replace CREATE VIEW / CREATE OR ALTER VIEW / ALTER VIEW, allowing
                for any spacing between the words.
            */
            SET @Sql = STUFF
            (
                  @Sql
                , @DdlStart
                , (@KeywordPos + LEN(N'VIEW')) - @DdlStart
                , N'ALTER VIEW'
            );

            SET @Search = UPPER(REPLACE(REPLACE(REPLACE(@Sql, CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' '));

            SET @DdlStart = NULLIF(PATINDEX(N'%ALTER%VIEW%', @Search), 0);

            IF @DdlStart IS NULL
                THROW 51202, N'Could not find ALTER VIEW token after normalising view definition.', 1;

            SET @AsPos = CHARINDEX(N' AS ', @Search, @DdlStart + LEN(N'ALTER VIEW'));

            IF @AsPos = 0
                THROW 51203, N'Could not find AS token while generating schema-bound view SQL.', 1;

            IF CHARINDEX(N'WITH SCHEMABINDING', SUBSTRING(@Search, @DdlStart, @AsPos - @DdlStart)) = 0
            BEGIN
                SET @Sql = STUFF(@Sql, @AsPos, 0, N' WITH SCHEMABINDING');
            END;
        END;

        /* =====================================================================================
           FUNCTIONS: IF / TF / FN
        ===================================================================================== */
        IF @ObjectType IN (N'IF', N'TF', N'FN')
        BEGIN
            SET @DdlStart = NULL;

            SET @DdlStart = NULLIF(PATINDEX(N'%CREATE%OR%ALTER%FUNCTION%', @Search), 0);

            IF @DdlStart IS NULL
                SET @DdlStart = NULLIF(PATINDEX(N'%ALTER%FUNCTION%', @Search), 0);

            IF @DdlStart IS NULL
                SET @DdlStart = NULLIF(PATINDEX(N'%CREATE%FUNCTION%', @Search), 0);

            IF @DdlStart IS NULL
                THROW 51204, N'Could not find CREATE/ALTER FUNCTION token while generating schema-bound SQL.', 1;

            SET @KeywordPos = CHARINDEX(N'FUNCTION', @Search, @DdlStart);

            IF @KeywordPos = 0
                THROW 51205, N'Could not find FUNCTION keyword while generating schema-bound SQL.', 1;

            /*
                Replace CREATE FUNCTION / CREATE OR ALTER FUNCTION / ALTER FUNCTION,
                allowing for any spacing between the words.
            */
            SET @Sql = STUFF
            (
                  @Sql
                , @DdlStart
                , (@KeywordPos + LEN(N'FUNCTION')) - @DdlStart
                , N'ALTER FUNCTION'
            );

            SET @Search = UPPER(REPLACE(REPLACE(REPLACE(@Sql, CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' '));

            SET @DdlStart = NULLIF(PATINDEX(N'%ALTER%FUNCTION%', @Search), 0);

            IF @DdlStart IS NULL
                THROW 51206, N'Could not find ALTER FUNCTION token after normalising function definition.', 1;

            SET @ReturnsPos = CHARINDEX(N'RETURNS', @Search, @DdlStart + LEN(N'ALTER FUNCTION'));

            IF @ReturnsPos = 0
                THROW 51207, N'Could not find RETURNS token while generating schema-bound function SQL.', 1;

            /*
                For inline TVFs:
                    RETURNS TABLE WITH SCHEMABINDING AS RETURN ...

                For scalar functions:
                    RETURNS INT WITH SCHEMABINDING AS BEGIN ...

                For multi-statement TVFs:
                    RETURNS @T TABLE (...) WITH SCHEMABINDING AS BEGIN ...

                So inserting immediately before the first AS after RETURNS is the
                safest generic placement.
            */
            SET @AsPos = CHARINDEX(N' AS ', @Search, @ReturnsPos + LEN(N'RETURNS'));

            IF @AsPos = 0
                THROW 51208, N'Could not find AS token while generating schema-bound function SQL.', 1;

            IF CHARINDEX(N'WITH SCHEMABINDING', SUBSTRING(@Search, @ReturnsPos, @AsPos - @ReturnsPos)) = 0
            BEGIN
                SET @Sql = STUFF(@Sql, @AsPos, 0, N' WITH SCHEMABINDING');
            END;
        END;

        IF @Apply = 0
        BEGIN
            SELECT
                  ObjectName = @TwoPartName
                , ObjectType = @ObjectType
                , AttemptedSql = @Sql;

            RETURN;
        END;

        EXEC sys.sp_executesql @Sql;

        IF @CanLog = 1
        BEGIN
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
                , N'Schema binding dependency discovery'
                , @TwoPartName
                , N'Info'
                , N'Applied WITH SCHEMABINDING to discovered dependency.'
            );
        END;
    END TRY
    BEGIN CATCH
        IF @CanLog = 1
        BEGIN
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
                , N'Schema binding dependency discovery'
                , @TwoPartName
                , N'Warning'
                , ERROR_MESSAGE()
                , ERROR_NUMBER()
                , ERROR_SEVERITY()
                , ERROR_STATE()
                , ERROR_LINE()
                , ERROR_PROCEDURE()
            );
        END;

        IF @ThrowOnError = 1
            THROW;
    END CATCH;
END;
GO