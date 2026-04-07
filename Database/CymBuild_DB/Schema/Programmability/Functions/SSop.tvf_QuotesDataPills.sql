SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create function [SSop].[tvf_QuotesDataPills]')
GO

CREATE FUNCTION [SSop].[tvf_QuotesDataPills]
(
    @Guid                UNIQUEIDENTIFIER,
    @DateAccepted        DATE,
    @DateRejected        DATE,
    @ProjectGuid         UNIQUEIDENTIFIER,
    @ContractGuid        UNIQUEIDENTIFIER,
    @AgentContractGuid   UNIQUEIDENTIFIER
)
RETURNS @DataPills TABLE
(
    [ID]        [INT]        IDENTITY (1, 1) NOT NULL,
    [Label]     NVARCHAR(50) NOT NULL,
    [Class]     NVARCHAR(50) NOT NULL,
    [SortOrder] INT          NOT NULL
)
   --WITH SCHEMABINDING
AS
BEGIN

    -------------------------------------------------------------------------
    -- NDA (existing behaviour preserved)
    -------------------------------------------------------------------------
    DECLARE @IsSubjectToNDA BIT;
    DECLARE @ProjectID INT;

    SELECT @ProjectID = p.ID
    FROM SSop.Projects AS p
    WHERE p.Guid = @ProjectGuid;

    SELECT @IsSubjectToNDA = e.IsSubjectToNDA
    FROM SSop.Enquiries AS e
    WHERE e.ProjectId = @ProjectID;

    IF (@IsSubjectToNDA = 1)
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'NDA', N'bg-danger', 1);
    END

    -------------------------------------------------------------------------
    -- Canonical workflow status GUIDs (locked rules)
    -------------------------------------------------------------------------
    DECLARE @ReadyToSendGuid UNIQUEIDENTIFIER = CONVERT(UNIQUEIDENTIFIER, '02A2237F-2AE7-4E05-926F-38E8B7D050A0'); -- ID 14
    DECLARE @SentGuid        UNIQUEIDENTIFIER = CONVERT(UNIQUEIDENTIFIER, '25D5491C-42A8-4B04-B3AC-D648AF0F8032');
    DECLARE @AcceptedGuid    UNIQUEIDENTIFIER = CONVERT(UNIQUEIDENTIFIER, '21A29AEE-2D99-4DA3-8182-F31813B0C498');
    DECLARE @RejectedGuid    UNIQUEIDENTIFIER = CONVERT(UNIQUEIDENTIFIER, '0A6A71F7-B39F-4213-997E-2B3A13B6144C');
    DECLARE @DeclinedGuid    UNIQUEIDENTIFIER = CONVERT(UNIQUEIDENTIFIER, '708C00E6-F45F-4CB2-8E91-A80B8B8E802E');
    DECLARE @DeadGuid        UNIQUEIDENTIFIER = CONVERT(UNIQUEIDENTIFIER, '8C7F7526-559F-4CCF-8FC2-DB0DA67E793D');
	DECLARE @FirstChase      UNIQUEIDENTIFIER = CONVERT(UNIQUEIDENTIFIER, '9FF22CEA-A2A6-4907-9B2D-E62DF8150913');
	DECLARE @SecondChase     UNIQUEIDENTIFIER = CONVERT(UNIQUEIDENTIFIER, '1F01C16B-1A73-4844-A938-FE357405FD93');

    -------------------------------------------------------------------------
    -- Latest workflow status for THIS quote (single source of truth)
    -------------------------------------------------------------------------
    DECLARE @LatestStatusName NVARCHAR(250) = NULL;
    DECLARE @LatestStatusGuid UNIQUEIDENTIFIER = NULL;
    DECLARE @LatestRequiresUsersAction BIT = 0;
    DECLARE @LatestIsCustomerWaiting BIT = 0;

    SELECT TOP (1)
        @LatestStatusName           = wfs.Name,
        @LatestStatusGuid           = wfs.Guid,
        @LatestRequiresUsersAction  = ISNULL(wfs.RequiresUsersAction, 0),
        @LatestIsCustomerWaiting    = ISNULL(wfs.IsCustomerWaitingStatus, 0)
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
    WHERE dot.DataObjectGuid = @Guid
      AND dot.RowStatus NOT IN (0,254)
      AND wfs.RowStatus NOT IN (0,254)
    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC;

    -------------------------------------------------------------------------
    -- STATUS datapill: ONLY latest status (no historical EXISTS)
    -- Prefer GUID matching; label text remains as today for UI consistency.
    -------------------------------------------------------------------------
    IF (@LatestStatusGuid IS NOT NULL)
    BEGIN
        IF (@LatestStatusGuid = @ReadyToSendGuid)
        BEGIN
            INSERT @DataPills (Label, Class, SortOrder)
            VALUES (N'Ready To Send', N'bg-warning', 1);
        END
		ELSE IF (@LatestStatusGuid = @FirstChase)
        BEGIN
            INSERT @DataPills (Label, Class, SortOrder)
            VALUES (N'1st Chase', N'bg-info', 1);
        END
		ELSE IF (@LatestStatusGuid = @SecondChase)
        BEGIN
            INSERT @DataPills (Label, Class, SortOrder)
            VALUES (N'2nd Chase', N'bg-info', 1);
        END
        ELSE IF (@LatestStatusGuid = @SentGuid)
        BEGIN
            INSERT @DataPills (Label, Class, SortOrder)
            VALUES (N'Sent', N'bg-info', 1);
        END
        ELSE IF (@LatestStatusGuid = @AcceptedGuid)
        BEGIN
            INSERT @DataPills (Label, Class, SortOrder)
            VALUES (N'Accepted', N'bg-success', 1);
        END
        ELSE IF (@LatestStatusGuid IN (@RejectedGuid, @DeclinedGuid, @DeadGuid))
        BEGIN
            -- Keep the displayed label consistent with the actual latest name.
            -- (So if it’s “Declined”, label is “Declined”, etc.)
            INSERT @DataPills (Label, Class, SortOrder)
            VALUES (ISNULL(@LatestStatusName, N'Status'), N'bg-danger', 1);
        END
        -- else: deliberately no pill for every workflow status.
    END

    -------------------------------------------------------------------------
    -- Jobs pending creation (preserved)
    -------------------------------------------------------------------------
    IF (@DateAccepted IS NOT NULL)
    BEGIN
        DECLARE @JobCount INT;

        SELECT @JobCount = COUNT(1)
        FROM SSop.Quote_JobsSummary js
        WHERE js.QuoteGuid = @Guid;

        IF (@JobCount > 0)
        BEGIN
            INSERT @DataPills (Label, Class, SortOrder)
            VALUES (CONVERT(NVARCHAR(50), @JobCount) + N' job(s) pending creation.', N'bg-warning', 1);
        END
    END

    -------------------------------------------------------------------------
    -- Finance Account Credit Hold (preserved)
    -------------------------------------------------------------------------
    IF (EXISTS
    (
        SELECT 1
        FROM SSop.Quotes AS Q
        JOIN SSop.Quote_ExtendedInfo AS QE ON QE.ID = Q.ID
        JOIN SCrm.Accounts AC ON AC.ID = QE.FinanceAccountId
        WHERE Q.Guid = @Guid
          AND AC.AccountStatusID = 4
    ))
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'Credit Hold', N'bg-danger', 1);
    END

    -------------------------------------------------------------------------
    -- Contract pills (preserved)
    -------------------------------------------------------------------------
    IF(@ContractGuid <> '00000000-0000-0000-0000-000000000000'
       OR @AgentContractGuid <> '00000000-0000-0000-0000-000000000000')
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'Contract In Place', N'bg-warning', 2);

        DECLARE @EndDate DATE, @NextReviewDate DATE;

        IF(@ContractGuid <> '00000000-0000-0000-0000-000000000000')
        BEGIN
            SELECT @EndDate = EndDate, @NextReviewDate = NextReviewDate
            FROM SSop.Contracts
            WHERE Guid = @ContractGuid;
        END
        ELSE
        BEGIN
            SELECT @EndDate = EndDate, @NextReviewDate = NextReviewDate
            FROM SSop.Contracts
            WHERE Guid = @AgentContractGuid;
        END

        IF (@EndDate IS NOT NULL AND DATEDIFF(DAY, GETDATE(), @EndDate) <= 30)
        BEGIN
            INSERT @DataPills (Label, Class, SortOrder)
            VALUES (N'Contract Ending In ' + CONVERT(NVARCHAR(10), DATEDIFF(DAY, GETDATE(), @EndDate)) + N' Days', N'bg-danger', 8);
        END

        IF (@NextReviewDate IS NOT NULL AND DATEDIFF(DAY, GETDATE(), @NextReviewDate) <= 30)
        BEGIN
            INSERT @DataPills (Label, Class, SortOrder)
            VALUES (N'Contract Needs Reviewing By ' + CONVERT(NVARCHAR(10), @NextReviewDate, 23), N'bg-danger', 9);
        END
    END

    -------------------------------------------------------------------------
    -- Latest-only: User Action Required / Customer Waiting (preserved)
    -------------------------------------------------------------------------
    IF (@LatestRequiresUsersAction = 1)
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'User Action Required', N'bg-warning', 0);
    END

    IF (@LatestIsCustomerWaiting = 1)
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'Awaiting Customer', N'bg-warning', 0);
    END

    RETURN;
END
GO