SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


/* ---------------------------------------------------------------------------------------
   Enqueue proc (best-effort). Does NOT throw.
--------------------------------------------------------------------------------------- */
CREATE PROCEDURE [SCore].[IntegrationOutbox_EnqueueJobCreatedFromProposal]
(
      @JobId   INT
    , @QuoteId INT
)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE
              @NowUtc             DATETIME2(7) = SYSUTCDATETIME()
            , @OutboxGuid         UNIQUEIDENTIFIER = NEWID()
            , @JobGuid            UNIQUEIDENTIFIER
            , @JobNumber          NVARCHAR(50)
            , @QuoteGuid          UNIQUEIDENTIFIER
            , @QuoteRef           NVARCHAR(50) = NULL
            , @ClientName         NVARCHAR(200) = NULL
            , @ProjectDescription NVARCHAR(500) = NULL
            , @CreatedOnUtc       DATETIME2(7) = NULL
            , @ActorIdentityId    INT = NULL
            , @ActorFullName      NVARCHAR(200) = NULL
            , @ActorEmail         NVARCHAR(256) = NULL
            , @DrafterIdentityId  INT = NULL
            , @DrafterFullName    NVARCHAR(200) = NULL
            , @DrafterEmail       NVARCHAR(256) = NULL
            , @PayloadJson        NVARCHAR(MAX);

        /* -------------------------
           Resolve Job basics
        ------------------------- */
        SELECT
              @JobGuid      = j.Guid
            , @JobNumber    = j.Number
            , @CreatedOnUtc = COALESCE(j.CreatedOn, @NowUtc)
        FROM SJob.Jobs j
        WHERE j.ID = @JobId
          AND j.RowStatus NOT IN (0,254);

        IF (@JobGuid IS NULL)
            RETURN;

        /* -------------------------
           Resolve Quote basics + Drafter
        ------------------------- */
        SELECT
              @QuoteGuid         = q.Guid
            , @QuoteRef          = CAST(q.Number AS NVARCHAR(50))
            , @DrafterIdentityId = q.QuotingConsultantId
        FROM SSop.Quotes q
        WHERE q.ID = @QuoteId
          AND q.RowStatus NOT IN (0,254);

        IF (@QuoteGuid IS NULL)
            RETURN;

        /* -------------------------
           Resolve Actor = current user
        ------------------------- */
        SELECT @ActorIdentityId = TRY_CONVERT(INT, SCore.GetCurrentUserId());

        IF (@ActorIdentityId IS NOT NULL)
        BEGIN
            SELECT
                  @ActorFullName = i.FullName
                , @ActorEmail    = i.EmailAddress
            FROM SCore.Identities i
            WHERE i.RowStatus NOT IN (0,254)
              AND i.ID = @ActorIdentityId;
        END

        /* -------------------------
           Resolve Drafter identity/email
        ------------------------- */
        IF (@DrafterIdentityId IS NOT NULL)
        BEGIN
            SELECT
                  @DrafterFullName = i.FullName
                , @DrafterEmail    = i.EmailAddress
            FROM SCore.Identities i
            WHERE i.RowStatus NOT IN (0,254)
              AND i.IsActive = 1
              AND i.ID = @DrafterIdentityId;
        END

        /* -------------------------
           Resolve Client + ProjectDescription
        ------------------------- */
        SELECT
              @ClientName = a.Name
        FROM SJob.Jobs j
        JOIN SCrm.Accounts a ON a.ID = j.ClientAccountID
        WHERE j.ID = @JobId
          AND j.RowStatus NOT IN (0,254)
          AND a.RowStatus NOT IN (0,254);

        SELECT
              @ProjectDescription = p.ProjectDescription
        FROM SJob.Jobs j
        JOIN SSop.Projects p ON p.ID = j.ProjectId
        WHERE j.ID = @JobId
          AND j.RowStatus NOT IN (0,254)
          AND p.RowStatus NOT IN (0,254);

        /* -------------------------
           Idempotency
        ------------------------- */
        IF EXISTS
        (
            SELECT 1
            FROM SCore.IntegrationOutbox o
            WHERE o.RowStatus NOT IN (0,254)
              AND o.EventType = N'JobCreatedFromProposal'
              AND ISJSON(o.PayloadJson) = 1
              AND TRY_CONVERT(uniqueidentifier, JSON_VALUE(o.PayloadJson, '$.jobGuid')) = @JobGuid
        )
        BEGIN
            RETURN;
        END

        /* -------------------------
           Build recipients array as plain strings
        ------------------------- */
        DECLARE @Recipients NVARCHAR(MAX);

        SELECT @Recipients =
            N'[' +
            STRING_AGG(
                N'"' + STRING_ESCAPE(v.EmailAddress, 'json') + N'"',
                N','
            ) +
            N']'
        FROM
        (
            SELECT DISTINCT EmailAddress
            FROM
            (
                SELECT @DrafterEmail AS EmailAddress
                UNION ALL
                SELECT N'SVC_Concursus@socotec.co.uk'
            ) x
            WHERE NULLIF(LTRIM(RTRIM(x.EmailAddress)), N'') IS NOT NULL
        ) v;

        /* -------------------------
           Build payload JSON
        ------------------------- */
        SET @PayloadJson =
        (
            SELECT
                  @OutboxGuid                 AS eventGuid
                , N'JobCreatedFromProposal'   AS eventType
                , @NowUtc                     AS occurredOnUtc

                , @JobGuid                    AS jobGuid
                , @JobNumber                  AS jobNumber
                , @CreatedOnUtc               AS jobCreatedOnUtc

                , @QuoteGuid                  AS quoteGuid
                , @QuoteRef                   AS quoteReference

                , @ClientName                 AS clientName
                , @ProjectDescription         AS projectDescription

                , JSON_QUERY(
                    (
                        SELECT
                              @ActorIdentityId AS identityId
                            , @ActorFullName   AS fullName
                            , @ActorEmail      AS emailAddress
                        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                    )
                  ) AS actor

                , JSON_QUERY(
                    (
                        SELECT
                              @DrafterIdentityId AS identityId
                            , @DrafterFullName   AS fullName
                            , @DrafterEmail      AS emailAddress
                        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                    )
                  ) AS drafter

                , JSON_QUERY(@Recipients) AS recipients
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        INSERT INTO SCore.IntegrationOutbox
        (
              RowStatus
            , Guid
            , CreatedOnUtc
            , EventType
            , PayloadJson
            , PublishedOnUtc
            , PublishAttempts
            , LastError
        )
        VALUES
        (
              1
            , @OutboxGuid
            , @NowUtc
            , N'JobCreatedFromProposal'
            , @PayloadJson
            , NULL
            , 0
            , NULL
        );
    END TRY
    BEGIN CATCH
        RETURN;
    END CATCH
END;
GO