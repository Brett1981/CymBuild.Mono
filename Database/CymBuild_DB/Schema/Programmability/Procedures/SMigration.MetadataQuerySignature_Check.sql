SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
    CYB-584: an EntityQuery statement is text, so nothing tied it to the signature of the routine it
    calls. CYB-333 gave SJob.ActivitiesValidate two more parameters while EntityQuery
    'SJob.ActivitiesValidate' still passed 9 arguments; schema and metadata both deployed "green" to
    QA and UAT and every Activity save failed with "An insufficient number of arguments were supplied".

    Checks every active EntityQuery that calls a function or procedure in this (target) database:
      - function (FN/IF/TF): the call must pass exactly as many arguments as the function declares;
      - procedure (P), named arguments only: every argument must exist on the procedure, and every
        procedure parameter without a default must be passed.

    @RunGuid NULL : current state of this database (post-deploy verification).
    @RunGuid set  : state after the run is applied - a selected EntityQueries row is checked as its
                    source payload, other queries as they are now - and each problem is recorded as a
                    Fail issue 'QueryCallSignatureMismatch' against the run.
    @ReturnResults: 1 returns the problems as a result set; MetadataValidate_Run passes 0.
*/
CREATE OR ALTER PROCEDURE [SMigration].[MetadataQuerySignature_Check]
(
    @RunGuid UNIQUEIDENTIFIER = NULL,
    @ReturnResults BIT = 1
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TargetDatabaseName SYSNAME,
            @EntityQueriesRegistryGuid UNIQUEIDENTIFIER;

    CREATE TABLE #SignatureQuery
    (
        QueryGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
        QueryName NVARCHAR(250) NOT NULL,
        SchemaName NVARCHAR(255) NOT NULL,
        ObjectName NVARCHAR(255) NOT NULL,
        Statement NVARCHAR(MAX) NOT NULL,
        IsFromRun BIT NOT NULL
    );

    CREATE TABLE #SignatureReplaced
    (
        QueryGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY
    );

    CREATE TABLE #SignatureProblem
    (
        ID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
        QueryGuid UNIQUEIDENTIFIER NOT NULL,
        QueryName NVARCHAR(250) NOT NULL,
        RoutineName NVARCHAR(520) NOT NULL,
        IsFromRun BIT NOT NULL,
        Problem NVARCHAR(1000) NOT NULL
    );

    IF @RunGuid IS NOT NULL
    BEGIN
        SELECT  @TargetDatabaseName = run.TargetDatabaseName
        FROM    SMigration.Metadata_Run AS run
        WHERE   run.Guid = @RunGuid
          AND   run.RowStatus NOT IN (0,254);

        SELECT  TOP (1) @EntityQueriesRegistryGuid = tr.Guid
        FROM    SMigration.Metadata_TableRegistry AS tr
        WHERE   tr.SchemaName = N'SCore'
          AND   tr.TableName = N'EntityQueries'
          AND   tr.RowStatus NOT IN (0,254);
    END;

    /* 1. Selected EntityQueries rows replace (or retire) the target row - same selection rules as MetadataValidate_Run. */
    IF @EntityQueriesRegistryGuid IS NOT NULL
    BEGIN
        WITH SelectedRows AS
        (
            SELECT  sr.SourceRowGuid,
                    sr.SourcePayloadJson,
                    ROW_NUMBER() OVER (PARTITION BY sr.SourceRowGuid ORDER BY sr.ID DESC) AS RowNumber
            FROM    SMigration.Metadata_StagedRows AS sr
            INNER JOIN SMigration.Metadata_RunSelections AS selection
                ON  selection.RunGuid = sr.RunGuid
                AND selection.RegistryGuid = sr.RegistryGuid
                AND selection.SourceRowGuid = sr.SourceRowGuid
                AND selection.RowStatus NOT IN (0,254)
            WHERE   sr.RunGuid = @RunGuid
              AND   sr.RegistryGuid = @EntityQueriesRegistryGuid
              AND   sr.RowStatus NOT IN (0,254)
              AND   sr.DifferenceType IN (N'Insert', N'Update')
              AND   NOT EXISTS
                    (
                        SELECT 1
                        FROM   SMigration.Metadata_IgnoredRecords AS ignored
                        WHERE  ignored.DatabaseName = @TargetDatabaseName
                          AND  ignored.RegistryGuid = sr.RegistryGuid
                          AND  ignored.SourceRowGuid = sr.SourceRowGuid
                          AND  ignored.RowStatus NOT IN (0,254)
                    )
              AND   NOT EXISTS
                    (
                        SELECT 1
                        FROM   SMigration.Metadata_IdentityMapOverrides AS identityOverride
                        WHERE  identityOverride.DatabaseName = @TargetDatabaseName
                          AND  identityOverride.RegistryGuid = sr.RegistryGuid
                          AND  identityOverride.SourceRowGuid = sr.SourceRowGuid
                          AND  identityOverride.RowStatus NOT IN (0,254)
                    )
        )
        SELECT  s.SourceRowGuid,
                src.Name,
                src.SchemaName,
                src.ObjectName,
                src.Statement,
                src.RowStatus
        INTO    #SignatureSelected
        FROM    SelectedRows AS s
        CROSS APPLY OPENJSON(s.SourcePayloadJson)
                WITH
                (
                    Name NVARCHAR(250) N'$.Name',
                    SchemaName NVARCHAR(255) N'$.SchemaName',
                    ObjectName NVARCHAR(255) N'$.ObjectName',
                    Statement NVARCHAR(MAX) N'$.Statement',
                    RowStatus INT N'$.RowStatus'
                ) AS src
        WHERE   s.RowNumber = 1;

        INSERT INTO #SignatureReplaced (QueryGuid)
        SELECT  sel.SourceRowGuid
        FROM    #SignatureSelected AS sel;

        INSERT INTO #SignatureQuery (QueryGuid, QueryName, SchemaName, ObjectName, Statement, IsFromRun)
        SELECT  sel.SourceRowGuid,
                ISNULL(sel.Name, N''),
                ISNULL(sel.SchemaName, N''),
                ISNULL(sel.ObjectName, N''),
                ISNULL(sel.Statement, N''),
                1
        FROM    #SignatureSelected AS sel
        WHERE   ISNULL(sel.RowStatus, 1) NOT IN (0,254);
    END;

    /* 2. Every other active query as it is in this database. */
    INSERT INTO #SignatureQuery (QueryGuid, QueryName, SchemaName, ObjectName, Statement, IsFromRun)
    SELECT  q.Guid, q.Name, q.SchemaName, q.ObjectName, q.Statement, 0
    FROM
    (
        SELECT  eq.Guid, eq.Name, eq.SchemaName, eq.ObjectName, eq.Statement,
                ROW_NUMBER() OVER (PARTITION BY eq.Guid ORDER BY eq.ID DESC) AS RowNumber
        FROM    SCore.EntityQueries AS eq
        WHERE   eq.RowStatus NOT IN (0,254)
    ) AS q
    WHERE   q.RowNumber = 1
      AND   NOT EXISTS (SELECT 1 FROM #SignatureReplaced AS r WHERE r.QueryGuid = q.Guid);

    /* 3. Compare each call with the routine it names. */
    DECLARE @QueryGuid UNIQUEIDENTIFIER, @QueryName NVARCHAR(250), @SchemaName NVARCHAR(255), @ObjectName NVARCHAR(255),
            @Statement NVARCHAR(MAX), @IsFromRun BIT, @ObjectId INT, @ObjectType CHAR(2), @RoutineName NVARCHAR(520),
            @Length INT, @Position INT, @Found INT, @Character NCHAR(1), @Depth INT, @InQuote BIT,
            @ArgumentCount INT, @HasContent BIT, @DeclaredCount INT, @Definition NVARCHAR(MAX),
            @Token NVARCHAR(130), @Next INT, @Scan INT, @CallEnd INT,
            @ParameterName SYSNAME, @HasDefault BIT, @Start INT, @EndOfLine INT;

    CREATE TABLE #SignatureArgument (Name NVARCHAR(130) NOT NULL PRIMARY KEY);

    DECLARE query_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT  q.QueryGuid, q.QueryName,
                -- Bracketed names and stray tab/CR/LF (seen in DEV) must not fail the lookup (CYB-574).
                REPLACE(REPLACE(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(q.SchemaName, NCHAR(9), N''), NCHAR(10), N''), NCHAR(13), N''))), N'[', N''), N']', N''),
                REPLACE(REPLACE(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(q.ObjectName, NCHAR(9), N''), NCHAR(10), N''), NCHAR(13), N''))), N'[', N''), N']', N''),
                q.Statement, q.IsFromRun
        FROM    #SignatureQuery AS q;

    OPEN query_cursor;
    FETCH NEXT FROM query_cursor INTO @QueryGuid, @QueryName, @SchemaName, @ObjectName, @Statement, @IsFromRun;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @ObjectId = CASE WHEN @SchemaName = N'' OR @ObjectName = N'' THEN NULL
                             ELSE OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@ObjectName)) END;
        SET @ObjectType = (SELECT o.type FROM sys.objects AS o WHERE o.object_id = @ObjectId);
        SET @RoutineName = @SchemaName + N'.' + @ObjectName;
        SET @Length = LEN(@Statement + N'x') - 1;

        IF @ObjectType IN ('FN', 'IF', 'TF')
        BEGIN
            /* The call is the first occurrence of the name followed (after ] and blanks) by '('. */
            SET @Found = 0;
            SET @Position = CHARINDEX(@ObjectName, @Statement);
            WHILE @Position > 0 AND @Found = 0
            BEGIN
                SET @Scan = @Position + LEN(@ObjectName);
                WHILE @Scan <= @Length AND SUBSTRING(@Statement, @Scan, 1) IN (N']', N' ', NCHAR(9), NCHAR(10), NCHAR(13))
                    SET @Scan += 1;

                IF SUBSTRING(@Statement, @Scan, 1) = N'('
                    SET @Found = @Scan;
                ELSE
                    SET @Position = CHARINDEX(@ObjectName, @Statement, @Position + 1);
            END;

            IF @Found > 0
            BEGIN
                SET @Position = @Found + 1;
                SET @Depth = 1;
                SET @InQuote = 0;
                SET @ArgumentCount = 1;
                SET @HasContent = 0;

                WHILE @Position <= @Length AND @Depth > 0
                BEGIN
                    SET @Character = SUBSTRING(@Statement, @Position, 1);
                    IF @InQuote = 1
                    BEGIN
                        IF @Character = N'''' SET @InQuote = 0;
                    END
                    ELSE IF @Character = N'''' SET @InQuote = 1;
                    ELSE IF @Character = N'(' SET @Depth += 1;
                    ELSE IF @Character = N')' SET @Depth -= 1;
                    ELSE IF @Character = N',' AND @Depth = 1 SET @ArgumentCount += 1;

                    IF @Depth > 0 AND @Character NOT IN (N' ', NCHAR(9), NCHAR(10), NCHAR(13))
                        SET @HasContent = 1;

                    SET @Position += 1;
                END;

                IF @HasContent = 0 SET @ArgumentCount = 0;

                SELECT  @DeclaredCount = COUNT(*)
                FROM    sys.parameters AS p
                WHERE   p.object_id = @ObjectId
                  AND   p.parameter_id > 0;

                IF @Depth = 0 AND @ArgumentCount <> @DeclaredCount
                    INSERT INTO #SignatureProblem (QueryGuid, QueryName, RoutineName, IsFromRun, Problem)
                    VALUES (@QueryGuid, @QueryName, @RoutineName, @IsFromRun,
                            CONCAT(N'passes ', @ArgumentCount, N' argument(s) to function ', @RoutineName, N', which takes ', @DeclaredCount, N'.'));
            END;
        END
        ELSE IF @ObjectType = 'P'
        BEGIN
            /*
                Named arguments of the call itself: after EXEC[UTE] <name>, a list of '@name = value'
                separated by commas at depth 0 outside quotes. A value runs to the next such comma, so
                anything after the call (SET @x = ..., SELECT ...) is part of the last value and is never
                read as an argument; anything before the EXEC (DECLARE/SET) is skipped. A call whose first
                argument is not named ('@name =') is positional and is not checked.
            */
            DELETE FROM #SignatureArgument;
            SET @CallEnd = 0; -- 1 = named argument list found

            SET @Position = PATINDEX(N'%EXEC%', @Statement);
            SET @Position = CASE WHEN @Position = 0 THEN 0 ELSE CHARINDEX(@ObjectName, @Statement, @Position) END;

            IF @Position > 0
            BEGIN
                SET @Position += LEN(@ObjectName);
                IF SUBSTRING(@Statement, @Position, 1) = N']' SET @Position += 1;

                WHILE @Position <= @Length
                BEGIN
                    WHILE @Position <= @Length AND SUBSTRING(@Statement, @Position, 1) IN (N' ', NCHAR(9), NCHAR(10), NCHAR(13))
                        SET @Position += 1;

                    IF SUBSTRING(@Statement, @Position, 1) <> N'@' BREAK;

                    SET @Next = @Position + 1;
                    WHILE @Next <= @Length AND SUBSTRING(@Statement, @Next, 1) LIKE N'[A-Za-z0-9_@#$]'
                        SET @Next += 1;

                    SET @Token = SUBSTRING(@Statement, @Position, @Next - @Position);
                    SET @Scan = @Next;
                    WHILE @Scan <= @Length AND SUBSTRING(@Statement, @Scan, 1) IN (N' ', NCHAR(9), NCHAR(10), NCHAR(13))
                        SET @Scan += 1;

                    IF SUBSTRING(@Statement, @Scan, 1) <> N'=' BREAK;

                    SET @CallEnd = 1;
                    IF NOT EXISTS (SELECT 1 FROM #SignatureArgument AS a WHERE a.Name = @Token)
                        INSERT INTO #SignatureArgument (Name) VALUES (@Token);

                    /* Skip the value to the next comma at depth 0, or the end of the statement. */
                    SET @Scan += 1;
                    SET @Depth = 0;
                    SET @InQuote = 0;
                    WHILE @Scan <= @Length
                    BEGIN
                        SET @Character = SUBSTRING(@Statement, @Scan, 1);
                        IF @InQuote = 1
                        BEGIN
                            IF @Character = N'''' SET @InQuote = 0;
                        END
                        ELSE IF @Character = N'''' SET @InQuote = 1;
                        ELSE IF @Character = N'(' SET @Depth += 1;
                        ELSE IF @Character = N')' SET @Depth -= 1;
                        ELSE IF @Character = N',' AND @Depth = 0 BREAK;
                        ELSE IF @Character = N';' AND @Depth = 0 BEGIN SET @Scan = @Length; END;

                        SET @Scan += 1;
                    END;

                    SET @Position = @Scan + 1;
                END;
            END;

            IF @CallEnd = 1
            BEGIN
                INSERT INTO #SignatureProblem (QueryGuid, QueryName, RoutineName, IsFromRun, Problem)
                SELECT  @QueryGuid, @QueryName, @RoutineName, @IsFromRun,
                        CONCAT(N'passes ', a.Name, N', which procedure ', @RoutineName, N' does not have.')
                FROM    #SignatureArgument AS a
                WHERE   NOT EXISTS (SELECT 1 FROM sys.parameters AS p WHERE p.object_id = @ObjectId AND p.name = a.Name);

                /*
                    sys.parameters.has_default_value is only populated for CLR routines, so a T-SQL
                    default is read from the definition: each parameter's declaration runs from its
                    name to the next ',' at depth 0, or the ')' that closes the list, or the AS/WITH
                    that starts the body. '=' at depth 0 inside it is a default.
                */
                SET @Definition = OBJECT_DEFINITION(@ObjectId);
                SET @Length = LEN(@Definition + N'x') - 1;
                SET @Position = PATINDEX(N'%PROC%' + @ObjectName + N'%', @Definition);

                DECLARE parameter_cursor CURSOR LOCAL FAST_FORWARD FOR
                    SELECT p.name FROM sys.parameters AS p WHERE p.object_id = @ObjectId AND p.parameter_id > 0 ORDER BY p.parameter_id;

                OPEN parameter_cursor;
                FETCH NEXT FROM parameter_cursor INTO @ParameterName;
                WHILE @@FETCH_STATUS = 0 AND @Position > 0
                BEGIN
                    /* Whole-word match of the parameter name, after the previous one. */
                    SET @Start = 0;
                    SET @Scan = CHARINDEX(@ParameterName, @Definition, @Position);
                    WHILE @Scan > 0 AND @Start = 0
                    BEGIN
                        IF SUBSTRING(@Definition, @Scan + LEN(@ParameterName), 1) NOT LIKE N'[A-Za-z0-9_@#$]'
                            SET @Start = @Scan;
                        ELSE
                            SET @Scan = CHARINDEX(@ParameterName, @Definition, @Scan + 1);
                    END;

                    IF @Start = 0
                    BEGIN
                        SET @Position = 0; -- cannot follow the declaration; stop rather than guess
                        BREAK;
                    END;

                    SET @HasDefault = 0;
                    SET @Depth = 0;
                    SET @InQuote = 0;
                    SET @Scan = @Start + LEN(@ParameterName);

                    WHILE @Scan <= @Length
                    BEGIN
                        SET @Character = SUBSTRING(@Definition, @Scan, 1);

                        IF @InQuote = 1
                        BEGIN
                            IF @Character = N'''' SET @InQuote = 0;
                        END
                        ELSE IF @Character = N'-' AND SUBSTRING(@Definition, @Scan + 1, 1) = N'-'
                        BEGIN
                            SET @EndOfLine = CHARINDEX(NCHAR(10), @Definition, @Scan);
                            SET @Scan = CASE WHEN @EndOfLine = 0 THEN @Length ELSE @EndOfLine END;
                        END
                        ELSE IF @Character = N'/' AND SUBSTRING(@Definition, @Scan + 1, 1) = N'*'
                        BEGIN
                            SET @EndOfLine = CHARINDEX(N'*/', @Definition, @Scan + 2);
                            SET @Scan = CASE WHEN @EndOfLine = 0 THEN @Length ELSE @EndOfLine + 1 END;
                        END
                        ELSE IF @Character = N'''' SET @InQuote = 1;
                        ELSE IF @Character = N'(' SET @Depth += 1;
                        ELSE IF @Character = N')'
                        BEGIN
                            IF @Depth = 0 BREAK;
                            SET @Depth -= 1;
                        END
                        ELSE IF @Depth = 0 AND @Character = N',' BREAK;
                        ELSE IF @Depth = 0 AND @Character = N'=' SET @HasDefault = 1;
                        ELSE IF @Depth = 0
                             AND SUBSTRING(@Definition, @Scan - 1, 1) IN (N' ', NCHAR(9), NCHAR(10), NCHAR(13))
                             AND (   (SUBSTRING(@Definition, @Scan, 2) = N'AS' AND SUBSTRING(@Definition, @Scan + 2, 1) IN (N' ', NCHAR(9), NCHAR(10), NCHAR(13)))
                                  OR (SUBSTRING(@Definition, @Scan, 4) = N'WITH' AND SUBSTRING(@Definition, @Scan + 4, 1) IN (N' ', NCHAR(9), NCHAR(10), NCHAR(13))))
                            BREAK;

                        SET @Scan += 1;
                    END;

                    IF @HasDefault = 0
                       AND NOT EXISTS (SELECT 1 FROM #SignatureArgument AS a WHERE a.Name = @ParameterName)
                        INSERT INTO #SignatureProblem (QueryGuid, QueryName, RoutineName, IsFromRun, Problem)
                        VALUES (@QueryGuid, @QueryName, @RoutineName, @IsFromRun,
                                CONCAT(N'does not pass ', @ParameterName, N', which procedure ', @RoutineName, N' requires (no default).'));

                    SET @Position = @Scan;
                    FETCH NEXT FROM parameter_cursor INTO @ParameterName;
                END;

                CLOSE parameter_cursor;
                DEALLOCATE parameter_cursor;
            END;
        END;

        FETCH NEXT FROM query_cursor INTO @QueryGuid, @QueryName, @SchemaName, @ObjectName, @Statement, @IsFromRun;
    END;

    CLOSE query_cursor;
    DEALLOCATE query_cursor;

    /* 4. Record against the run. */
    IF @RunGuid IS NOT NULL AND @EntityQueriesRegistryGuid IS NOT NULL
    BEGIN
        INSERT INTO SMigration.Metadata_ValidationIssues
        (
            Guid,
            RowStatus,
            RunGuid,
            RegistryGuid,
            SourceRowGuid,
            Severity,
            IssueCode,
            IssueMessage,
            DetailsJson,
            CreatedOnUtc
        )
        SELECT
            NEWID(),
            1,
            @RunGuid,
            @EntityQueriesRegistryGuid,
            p.QueryGuid,
            N'Fail',
            N'QueryCallSignatureMismatch',
            LEFT(CONCAT
            (
                CASE WHEN p.IsFromRun = 1 THEN N'Selected query ''' ELSE N'Target query ''' END,
                p.QueryName, N''' ', p.Problem,
                N' Every call to it fails. Update the query statement and parameters in the source (or deploy the schema it expects) before applying.'
            ), 2000),
            CONCAT(N'{"entityQueryGuid":"', CONVERT(NVARCHAR(36), p.QueryGuid), N'","routine":"', STRING_ESCAPE(p.RoutineName, 'json'), N'"}'),
            SYSUTCDATETIME()
        FROM #SignatureProblem AS p;
    END;

    IF @ReturnResults = 1
        SELECT  p.QueryGuid,
                p.QueryName,
                p.RoutineName,
                p.IsFromRun,
                p.Problem
        FROM    #SignatureProblem AS p
        ORDER BY p.ID;
END;
GO
