SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SSop].[QuoteReopen]')
GO

CREATE PROCEDURE [SSop].[QuoteReopen]
    @Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserID INT = -1;

    SELECT @UserID = ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1);

    IF NOT EXISTS
    (
        SELECT 1
        FROM SCore.UserGroups AS ug
        JOIN SCore.Groups AS g
            ON g.ID = ug.GroupID
        WHERE ug.IdentityID = @UserID
          AND g.Code = N'QUOTESU'
          AND ug.RowStatus NOT IN (0,254)
          AND g.RowStatus NOT IN (0,254)
    )
    BEGIN
        ;THROW 60000, N'Only members of the Quote Superusers group can run this action.', 1;
    END;

    DECLARE
        @UserGuid UNIQUEIDENTIFIER,
        @ReopenedStatusGuid UNIQUEIDENTIFIER,
        @QuotingStatusGuid UNIQUEIDENTIFIER,
        @PreviousStatusGuid UNIQUEIDENTIFIER,
        @CompleteStatusGuid UNIQUEIDENTIFIER,
        @DeclinedStatusGuid UNIQUEIDENTIFIER,
        @RejectedStatusGuid UNIQUEIDENTIFIER,
        @DataObjectTransitionGuid UNIQUEIDENTIFIER = NEWID();

    SELECT @UserGuid = i.Guid
    FROM SCore.Identities AS i
    WHERE i.ID = @UserID
      AND i.RowStatus NOT IN (0,254);

    SELECT TOP (1) @ReopenedStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInQuotes = 1
      AND ws.Name = N'Reopened'
    ORDER BY ws.ID;

    SELECT TOP (1) @QuotingStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInQuotes = 1
      AND ws.Name = N'Quoting'
    ORDER BY ws.ID;

    SELECT TOP (1) @CompleteStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInQuotes = 1
      AND ws.Name = N'Complete'
    ORDER BY ws.ID;

    SELECT TOP (1) @DeclinedStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInQuotes = 1
      AND ws.Name = N'Declined'
    ORDER BY ws.ID;

    SELECT TOP (1) @RejectedStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInQuotes = 1
      AND ws.Name = N'Rejected'
    ORDER BY ws.ID;

    IF (@UserGuid IS NULL)
        THROW 60000, N'Could not resolve current user.', 1;

    IF (@ReopenedStatusGuid IS NULL)
        THROW 60000, N'Could not resolve Reopened quote status.', 1;

    IF (@QuotingStatusGuid IS NULL)
        THROW 60000, N'Could not resolve Quoting quote status.', 1;

    IF (@CompleteStatusGuid IS NULL OR @DeclinedStatusGuid IS NULL OR @RejectedStatusGuid IS NULL)
        THROW 60000, N'Could not resolve one or more quote statuses required for reopening.', 1;

    SELECT TOP (1)
        @PreviousStatusGuid = ws.Guid
    FROM SCore.DataObjectTransition AS dot
    JOIN SCore.WorkflowStatus AS ws
        ON ws.ID = dot.StatusID
    WHERE dot.DataObjectGuid = @Guid
      AND dot.RowStatus NOT IN (0,254)
      AND ws.RowStatus NOT IN (0,254)
    ORDER BY dot.ID DESC;

    IF (@PreviousStatusGuid NOT IN (@CompleteStatusGuid, @DeclinedStatusGuid, @RejectedStatusGuid))
    BEGIN
        ;THROW 60000, N'Last applied status must be Complete, Declined, or Rejected.', 1;
    END;

    UPDATE q
    SET q.DeadDate = NULL,
        q.DateRejected = NULL,
        q.DateDeclinedToQuote = NULL
    FROM SSop.Quotes AS q
    WHERE q.Guid = @Guid
      AND q.RowStatus NOT IN (0,254)
      AND
      (
          q.DeadDate IS NOT NULL
          OR q.DateRejected IS NOT NULL
          OR q.DateDeclinedToQuote IS NOT NULL
      );

    EXEC SCore.DataObjectTransitionUpsert
        @Guid = @DataObjectTransitionGuid,
        @OldStatusGuid = @PreviousStatusGuid,
        @StatusGuid = @ReopenedStatusGuid,
        @Comment = N'Quote reopened.',
        @CreatedByUserGuid = @UserGuid,
        @SurveyorUserGuid = '00000000-0000-0000-0000-000000000000',
        @DataObjectGuid = @Guid,
        @IsImported = 1;

    SET @DataObjectTransitionGuid = NEWID();

    EXEC SCore.DataObjectTransitionUpsert
        @Guid = @DataObjectTransitionGuid,
        @OldStatusGuid = @ReopenedStatusGuid,
        @StatusGuid = @QuotingStatusGuid,
        @Comment = N'Reopened quote returned to quoting.',
        @CreatedByUserGuid = @UserGuid,
        @SurveyorUserGuid = '00000000-0000-0000-0000-000000000000',
        @DataObjectGuid = @Guid,
        @IsImported = 1;
END;
GO