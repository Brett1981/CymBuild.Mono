SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SSop].[EnquiryReopen]')
GO

CREATE PROCEDURE [SSop].[EnquiryReopen]
    @Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserID INT = ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1);

    IF NOT EXISTS
    (
        SELECT 1
        FROM SCore.UserGroups AS ug
        JOIN SCore.Groups AS g
            ON g.ID = ug.GroupID
        WHERE ug.IdentityID = @UserID
          AND g.Code = N'ENQUIRYSU'
          AND ug.RowStatus NOT IN (0,254)
          AND g.RowStatus NOT IN (0,254)
    )
        THROW 60000, N'Only members of the Enquiries Superusers group can run this action.', 1;

    DECLARE
        @UserGuid UNIQUEIDENTIFIER,
        @PreviousStatusGuid UNIQUEIDENTIFIER,
        @LastStatusGuid UNIQUEIDENTIFIER,
        @ReopenedStatusGuid UNIQUEIDENTIFIER,
        @NewStatusGuid UNIQUEIDENTIFIER,
        @CompletedStatusGuid UNIQUEIDENTIFIER,
        @DeclinedStatusGuid UNIQUEIDENTIFIER,
        @EngineeringDeclinedStatusGuid UNIQUEIDENTIFIER,
        @TransitionGuid UNIQUEIDENTIFIER;

    SELECT @UserGuid = i.Guid
    FROM SCore.Identities AS i
    WHERE i.ID = @UserID
      AND i.RowStatus NOT IN (0,254);

    SELECT TOP (1) @ReopenedStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInEnquiries = 1
      AND ws.Name = N'Reopened'
    ORDER BY ws.ID;

    SELECT TOP (1) @NewStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInEnquiries = 1
      AND ws.Name = N'New'
    ORDER BY ws.ID;

    SELECT TOP (1) @CompletedStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInEnquiries = 1
      AND ws.Name IN (N'Completed', N'Complete')
    ORDER BY ws.ID;

    SELECT TOP (1) @DeclinedStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInEnquiries = 1
      AND ws.Name = N'Declined'
    ORDER BY ws.ID;

    SELECT TOP (1) @EngineeringDeclinedStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInEnquiries = 1
      AND ws.Name IN (N'Declined To Quote', N'Engineering Declined')
    ORDER BY ws.ID;

    SELECT TOP (1)
        @PreviousStatusGuid = ws.Guid,
        @LastStatusGuid = ws.Guid
    FROM SCore.DataObjectTransition AS dot
    JOIN SCore.WorkflowStatus AS ws
        ON ws.ID = dot.StatusID
    WHERE dot.DataObjectGuid = @Guid
      AND dot.RowStatus NOT IN (0,254)
      AND ws.RowStatus NOT IN (0,254)
    ORDER BY dot.ID DESC;

    IF @UserGuid IS NULL
        THROW 60000, N'Could not resolve current user.', 1;

    IF @ReopenedStatusGuid IS NULL
        THROW 60000, N'Could not resolve Reopened enquiry status.', 1;

    IF @NewStatusGuid IS NULL
        THROW 60000, N'Could not resolve New enquiry status.', 1;

    IF @LastStatusGuid NOT IN
    (
        @CompletedStatusGuid,
        @DeclinedStatusGuid,
        ISNULL(@EngineeringDeclinedStatusGuid, '00000000-0000-0000-0000-000000000000')
    )
        THROW 60000, N'Last applied status must be Completed or Declined.', 1;

    UPDATE e
    SET e.DeclinedToQuoteDate = NULL
    FROM SSop.Enquiries AS e
    WHERE e.Guid = @Guid
      AND e.RowStatus NOT IN (0,254);

    SET @TransitionGuid = NEWID();

    EXEC SCore.DataObjectTransitionUpsert
        @Guid = @TransitionGuid,
        @OldStatusGuid = @PreviousStatusGuid,
        @StatusGuid = @ReopenedStatusGuid,
        @Comment = N'The enquiry has been reopened.',
        @CreatedByUserGuid = @UserGuid,
        @SurveyorUserGuid = @UserGuid,
        @DataObjectGuid = @Guid,
        @IsImported = 0;

    SET @TransitionGuid = NEWID();

    EXEC SCore.DataObjectTransitionUpsert
        @Guid = @TransitionGuid,
        @OldStatusGuid = @ReopenedStatusGuid,
        @StatusGuid = @NewStatusGuid,
        @Comment = N'Reopened enquiry returned to New.',
        @CreatedByUserGuid = @UserGuid,
        @SurveyorUserGuid = @UserGuid,
        @DataObjectGuid = @Guid,
        @IsImported = 1;
END;
GO