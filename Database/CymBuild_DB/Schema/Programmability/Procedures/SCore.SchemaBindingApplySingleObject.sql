SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[SchemaBindingApplySingleObject]')
GO

CREATE OR ALTER PROCEDURE [SCore].[SchemaBindingApplySingleObject]
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
        , @CanLog           BIT = 0
        , @IsSchemaBound    BIT = 0
        , @HasPreparedMarker BIT = 0
        , @PreparedMarkerRemoved BIT = 0
        , @ScanPosition     INT
        , @DefinitionLength INT
        , @LexicalState     TINYINT
        , @BlockDepth       INT
        , @Character        NCHAR(1)
        , @NextCharacter    NCHAR(1);

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
        , @IsSchemaBound = CONVERT(BIT, sm.is_schema_bound)
        , @HasPreparedMarker = CONVERT
          (
              BIT,
              CASE
                  WHEN sm.definition LIKE N'%--WITH SCHEMABINDING%' THEN 1
                  ELSE 0
              END
          )
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

    IF @IsSchemaBound = 1
       AND @HasPreparedMarker = 0
    BEGIN
        RETURN;
    END;

    /*
        Supported:
        V  = View
        IF = Inline TVF
        TF = Multi-statement TVF
        FN = Scalar function

        The procedure injects WITH SCHEMABINDING when required and removes only
        the exact prepared lifecycle marker from executable SQL.
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
            Build a same-length lexical search buffer. Comments and string
            literals are replaced with spaces so words such as "user-created"
            or example DDL inside a header cannot be mistaken for the module
            declaration. Positions continue to line up exactly for STUFF().

            LexicalState: 0 = SQL, 1 = line comment, 2 = block comment,
                          3 = string literal.
        */
        SET @Search = N'';
        SET @ScanPosition = 1;
        /* Appending a sentinel preserves trailing spaces and follows the current collation's character indexing. */
        SET @DefinitionLength = LEN(@Sql + N'#') - 1;
        SET @LexicalState = 0;
        SET @BlockDepth = 0;

        WHILE @ScanPosition <= @DefinitionLength
        BEGIN
            SET @Character = SUBSTRING(@Sql, @ScanPosition, 1);
            SET @NextCharacter = CASE
                WHEN @ScanPosition < @DefinitionLength
                    THEN SUBSTRING(@Sql, @ScanPosition + 1, 1)
                ELSE N''
            END;

            IF @LexicalState = 0
            BEGIN
                /*
                    SCore.PreDeploymentScript creates this exact line-comment token.
                    Remove it only while scanning executable SQL (never from strings,
                    quoted identifiers or block comments).  This allows an already-bound
                    module to shed a stale prepared marker without losing its active
                    WITH SCHEMABINDING clause.
                */
                IF @Character = N'-'
                   AND @NextCharacter = N'-'
                   AND UPPER
                       (
                           SUBSTRING
                           (
                                 @Sql
                               , @ScanPosition
                               , LEN(N'--WITH SCHEMABINDING')
                           )
                       ) = N'--WITH SCHEMABINDING'
                BEGIN
                    SET @Sql = STUFF
                    (
                          @Sql
                        , @ScanPosition
                        , LEN(N'--WITH SCHEMABINDING')
                        , N''
                    );
                    SET @DefinitionLength = @DefinitionLength - LEN(N'--WITH SCHEMABINDING');
                    SET @PreparedMarkerRemoved = 1;
                    CONTINUE;
                END;

                IF @Character = N'-' AND @NextCharacter = N'-'
                BEGIN
                    SET @Search += N'  ';
                    SET @ScanPosition += 2;
                    SET @LexicalState = 1;
                    CONTINUE;
                END;

                IF @Character = N'/' AND @NextCharacter = N'*'
                BEGIN
                    SET @Search += N'  ';
                    SET @ScanPosition += 2;
                    SET @LexicalState = 2;
                    SET @BlockDepth = 1;
                    CONTINUE;
                END;

                IF @Character = N''''
                BEGIN
                    SET @Search += N' ';
                    SET @ScanPosition += 1;
                    SET @LexicalState = 3;
                    CONTINUE;
                END;

                SET @Search += CASE
                    WHEN @Character IN (NCHAR(9), NCHAR(10), NCHAR(13)) THEN N' '
                    ELSE UPPER(@Character)
                END;
                SET @ScanPosition += 1;
                CONTINUE;
            END;

            IF @LexicalState = 1
            BEGIN
                SET @Search += N' ';
                SET @ScanPosition += 1;
                IF @Character IN (NCHAR(10), NCHAR(13))
                    SET @LexicalState = 0;
                CONTINUE;
            END;

            IF @LexicalState = 2
            BEGIN
                IF @Character = N'/' AND @NextCharacter = N'*'
                BEGIN
                    SET @Search += N'  ';
                    SET @ScanPosition += 2;
                    SET @BlockDepth += 1;
                    CONTINUE;
                END;

                IF @Character = N'*' AND @NextCharacter = N'/'
                BEGIN
                    SET @Search += N'  ';
                    SET @ScanPosition += 2;
                    SET @BlockDepth -= 1;
                    IF @BlockDepth = 0
                        SET @LexicalState = 0;
                    CONTINUE;
                END;

                SET @Search += N' ';
                SET @ScanPosition += 1;
                CONTINUE;
            END;

            /* String literal, including escaped single quotes. */
            IF @Character = N'''' AND @NextCharacter = N''''
            BEGIN
                SET @Search += N'  ';
                SET @ScanPosition += 2;
                CONTINUE;
            END;

            SET @Search += N' ';
            SET @ScanPosition += 1;
            IF @Character = N''''
                SET @LexicalState = 0;
        END;

        IF @LexicalState = 2
            THROW 51209, N'Unterminated block comment in module definition.', 1;

        IF @LexicalState = 3
            THROW 51210, N'Unterminated string literal in module definition.', 1;

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

            SET @Search = STUFF
            (
                  @Search
                , @DdlStart
                , (@KeywordPos + LEN(N'VIEW')) - @DdlStart
                , N'ALTER VIEW'
            );

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

            SET @Search = STUFF
            (
                  @Search
                , @DdlStart
                , (@KeywordPos + LEN(N'FUNCTION')) - @DdlStart
                , N'ALTER FUNCTION'
            );

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
                , CASE
                    WHEN @PreparedMarkerRemoved = 1 AND @IsSchemaBound = 1
                        THEN N'Removed the stale prepared --WITH SCHEMABINDING marker from an already schema-bound module.'
                    WHEN @PreparedMarkerRemoved = 1
                        THEN N'Applied WITH SCHEMABINDING and removed the prepared lifecycle marker.'
                    ELSE N'Applied WITH SCHEMABINDING to discovered dependency.'
                  END
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
                , CASE
                    /*
                        Dependency discovery and stale-marker cleanup deliberately call
                        this procedure with @ThrowOnError = 0.  Their final state checks
                        are authoritative, so a speculative ALTER failure must remain a
                        diagnostic warning rather than poison the strict post-deployment
                        result.  Direct strict callers still receive hard parser/compile
                        failures and the original exception is re-thrown below.
                    */
                    WHEN @ThrowOnError = 0 THEN N'Warning'
                    WHEN ERROR_NUMBER() IN (3729, 4513) THEN N'Warning'
                    ELSE N'Error'
                  END
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
