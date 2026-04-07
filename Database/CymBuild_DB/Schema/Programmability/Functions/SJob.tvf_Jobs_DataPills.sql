SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create function [SJob].[tvf_Jobs_DataPills]')
GO
PRINT (N'Create function [SJob].[tvf_Jobs_DataPills]')
GO
PRINT (N'Create function [SJob].[tvf_Jobs_DataPills]')
GO
CREATE FUNCTION [SJob].[tvf_Jobs_DataPills]
(
    @Guid                      UNIQUEIDENTIFIER,
    @AppFormReceived           BIT,
    @ClientAppointmentReceived BIT,
    @ClientAccountGuid         UNIQUEIDENTIFIER,
    @AgentAccountGuid          UNIQUEIDENTIFIER,
    @FinanceAccountGuid        UNIQUEIDENTIFIER,
    @JobCompleted              DATETIME2,
    @JobCancelled              DATETIME2,
    @JobDormant                DATETIME2,
    @JobStarted                DATETIME2,
    @OrganisationalUnitGuid    UNIQUEIDENTIFIER,
    @IsNDA                     BIT,
    @JobTypeGuid               UNIQUEIDENTIFIER,
    @CannotBeInvoiced          BIT,
    @CannotBeInvoicedReason    NVARCHAR(MAX),
    @ContractGuid              UNIQUEIDENTIFIER,
    @AgentContractGuid         UNIQUEIDENTIFIER,
    @ProjectGuid               UNIQUEIDENTIFIER
)
RETURNS @DataPills TABLE
(
    [ID]        [INT]        IDENTITY (1, 1) NOT NULL,
    [Label]     NVARCHAR(MAX) NOT NULL,
    [Class]     NVARCHAR(50) NOT NULL,
    [SortOrder] INT          NOT NULL
)
       --WITH SCHEMABINDING
AS
BEGIN

    -------------------------------------------------------------------------
    -- Resolve JobID
    -------------------------------------------------------------------------
    DECLARE @JobID INT;

    SELECT @JobID = j.ID
    FROM SJob.Jobs j
    WHERE j.Guid = @Guid;

    -------------------------------------------------------------------------
    -- Canonical workflow statuses (Job workflow)
    -------------------------------------------------------------------------
    DECLARE @CancelledStatus     UNIQUEIDENTIFIER = '18D8E36B-43BE-4BDE-9D0B-1F34B460AD64';
    DECLARE @CompletedStatus     UNIQUEIDENTIFIER = '20D22623-283B-4088-9CEB-D944AC3E6516';
    DECLARE @DormantStatus       UNIQUEIDENTIFIER = '6708FDB6-29A7-4505-A209-F1E785386122';
    DECLARE @JobStartedStatus    UNIQUEIDENTIFIER = 'FC9AA6A3-79DB-4533-A6A9-B831610F2BDC';

    -- Resolve “New” dynamically for jobs (safer across envs / IDs)
    DECLARE @NewStatus UNIQUEIDENTIFIER = NULL;

    SELECT TOP (1) @NewStatus = ws.Guid
    FROM SCore.WorkflowStatus ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInJobs = 1
      AND ws.Name = N'New'
    ORDER BY ws.ID;

    -------------------------------------------------------------------------
    -- Latest-only: read the single latest status row for this Job
    -------------------------------------------------------------------------
    DECLARE @LatestStatusGuid UNIQUEIDENTIFIER = NULL;
    DECLARE @LatestStatusName NVARCHAR(250) = NULL;
    DECLARE @LatestRequiresUsersAction BIT = 0;
    DECLARE @LatestIsCustomerWaiting   BIT = 0;

    -- NEW flags for pill styling
    DECLARE @LatestIsActiveStatus  BIT = NULL;  -- when 0 => red
    DECLARE @LatestIsCompleteStatus BIT = NULL; -- when 1 => green

    SELECT TOP (1)
        @LatestStatusGuid          = wfs.Guid,
        @LatestStatusName          = wfs.Name,
        @LatestRequiresUsersAction = ISNULL(wfs.RequiresUsersAction, 0),
        @LatestIsCustomerWaiting   = ISNULL(wfs.IsCustomerWaitingStatus, 0),
        @LatestIsActiveStatus      = ISNULL(wfs.IsActiveStatus, 1),
        @LatestIsCompleteStatus    = ISNULL(wfs.IsCompleteStatus, 0)
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
    WHERE dot.DataObjectGuid = @Guid
      AND dot.RowStatus NOT IN (0,254)
      AND wfs.RowStatus NOT IN (0,254)
    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC;

    -------------------------------------------------------------------------
    -- Helper: insert without duplicating an existing label
    -------------------------------------------------------------------------
    DECLARE @Lbl NVARCHAR(50), @Cls NVARCHAR(50), @Ord INT;

    -------------------------------------------------------------------------
    -- NDA pill (preserved) - de-dupe safe
    -------------------------------------------------------------------------
    IF (@IsNDA = 1)
    BEGIN
        SET @Lbl = N'NDA'; SET @Cls = N'bg-danger'; SET @Ord = 1;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END

    -------------------------------------------------------------------------
    -- Job status pill (LATEST ONLY, with legacy datetime fallback)
    -- Precedence: Cancelled > Completed > Dormant > Started > New
    -------------------------------------------------------------------------
    DECLARE @IsCancelled BIT = 0,
            @IsCompleted BIT = 0,
            @IsDormant   BIT = 0,
            @IsStarted   BIT = 0,
            @IsNew       BIT = 0;

    IF (@LatestStatusGuid IS NOT NULL)
    BEGIN
        IF (@LatestStatusGuid = @CancelledStatus)          SET @IsCancelled = 1;
        ELSE IF (@LatestStatusGuid = @CompletedStatus)     SET @IsCompleted = 1;
        ELSE IF (@LatestStatusGuid = @DormantStatus)       SET @IsDormant   = 1;
        ELSE IF (@LatestStatusGuid = @JobStartedStatus)    SET @IsStarted   = 1;
        ELSE IF (@NewStatus IS NOT NULL AND @LatestStatusGuid = @NewStatus) SET @IsNew = 1;
        ELSE
        BEGIN
            -- Unknown/custom job statuses: handled later as "latest workflow status pill"
            SET @IsNew = 0;
        END
    END
    ELSE
    BEGIN
        -- Fallback for old records with no transitions
        IF (@JobCancelled IS NOT NULL)       SET @IsCancelled = 1;
        ELSE IF (@JobCompleted IS NOT NULL)  SET @IsCompleted = 1;
        ELSE IF (@JobDormant   IS NOT NULL)  SET @IsDormant   = 1;
        ELSE IF (@JobStarted   IS NOT NULL)  SET @IsStarted   = 1;
        ELSE                                 SET @IsNew       = 1;
    END

    IF (@IsCompleted = 1)
    BEGIN
        SET @Lbl = N'Completed'; SET @Cls = N'bg-success'; SET @Ord = 2;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END
    ELSE IF (@IsCancelled = 1)
    BEGIN
        SET @Lbl = N'Cancelled'; SET @Cls = N'bg-danger'; SET @Ord = 2;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END
    ELSE IF (@IsDormant = 1)
    BEGIN
        SET @Lbl = N'Dormant'; SET @Cls = N'bg-warning'; SET @Ord = 2;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END
    ELSE IF (@IsStarted = 1)
    BEGIN
        SET @Lbl = N'Job Started'; SET @Cls = N'bg-info'; SET @Ord = 2;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END
    ELSE IF (@IsNew = 1)
    BEGIN
        SET @Lbl = N'New'; SET @Cls = N'bg-info'; SET @Ord = 2;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END

    -------------------------------------------------------------------------
    -- NEW: Latest workflow status pill (only when it's NOT already covered
    --      by the existing standard status pills above)
    --
    -- Rules requested:
    --  - If latest workflow status IsActiveStatus = 0 => show as Red (bg-danger)
    --  - Else if latest workflow status IsCompleteStatus = 1 => show as Green (bg-success)
    --  - Do not duplicate pills if one is already being shown
    -------------------------------------------------------------------------
    IF (@LatestStatusGuid IS NOT NULL)
       AND (@LatestStatusName IS NOT NULL)
       AND (@LatestStatusGuid NOT IN (@CancelledStatus, @CompletedStatus, @DormantStatus, @JobStartedStatus))
       AND NOT (@NewStatus IS NOT NULL AND @LatestStatusGuid = @NewStatus)
    BEGIN
        DECLARE @LatestPillClass NVARCHAR(50);

        IF (ISNULL(@LatestIsActiveStatus, 1) = 0)
            SET @LatestPillClass = N'bg-danger';      -- Warning (Red)
        ELSE IF (ISNULL(@LatestIsCompleteStatus, 0) = 1 OR @LatestStatusGuid = @CompletedStatus)
            SET @LatestPillClass = N'bg-success';     -- Complete (Green)
        ELSE
            SET @LatestPillClass = N'bg-info';        -- Neutral / informational

        -- Keep label within NVARCHAR(50)
        SET @Lbl = LEFT(@LatestStatusName, 50);
        SET @Cls = @LatestPillClass;
        SET @Ord = 2;

        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END

    -------------------------------------------------------------------------
    -- Client/Agent/Finance holds (preserved) - de-dupe safe
    -------------------------------------------------------------------------
    IF (EXISTS
    (
        SELECT 1
        FROM SCrm.Accounts a
        JOIN SCrm.AccountStatus st ON st.ID = a.AccountStatusID
        WHERE a.Guid = @ClientAccountGuid
          AND st.IsHold = 1
    ))
    BEGIN
        SET @Lbl = N'Client Account Hold'; SET @Cls = N'bg-danger'; SET @Ord = 3;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END

    IF (EXISTS
    (
        SELECT 1
        FROM SCrm.Accounts a
        JOIN SCrm.AccountStatus st ON st.ID = a.AccountStatusID
        WHERE a.Guid = @AgentAccountGuid
          AND st.IsHold = 1
    ))
    BEGIN
        SET @Lbl = N'Agent Account Hold'; SET @Cls = N'bg-danger'; SET @Ord = 3;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END

    IF (EXISTS
    (
        SELECT 1
        FROM SCrm.Accounts Ac
        WHERE Ac.Guid = @FinanceAccountGuid
          AND Ac.AccountStatusID = 4
    ))
    BEGIN
        SET @Lbl = N'Credit Hold'; SET @Cls = N'bg-danger'; SET @Ord = 1;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END

    -------------------------------------------------------------------------
    -- Outstanding Fees (preserved) - de-dupe safe
    -------------------------------------------------------------------------
    IF (EXISTS
    (
        SELECT 1
        FROM SFin.Transactions t
        JOIN SFin.TransactionCalculations tc ON tc.ID = t.ID
        JOIN SFin.TransactionTypes tt ON tt.ID = t.TransactionTypeID
        WHERE t.JobID = @JobID
          AND tc.RealOutstanding <> 0
          AND tt.IsBank = 0
          AND tc.DueDate < GETDATE()
    ))
    BEGIN
        SET @Lbl = N'Overdue Invoices'; SET @Cls = N'bg-warning'; SET @Ord = 3;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END

    -------------------------------------------------------------------------
    -- App Form not received (preserved) - de-dupe safe
    -------------------------------------------------------------------------
    IF (@AppFormReceived = 0)
    BEGIN
        SET @Lbl = N'App Form Not Received'; SET @Cls = N'bg-danger'; SET @Ord = 4;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END

    -------------------------------------------------------------------------
    -- Outstanding Actions (preserved) - de-dupe safe
    -------------------------------------------------------------------------
    IF (EXISTS
    (
        SELECT 1
        FROM SJob.Actions a
        WHERE a.RowStatus NOT IN (0,254)
          AND a.ActionStatusId <> 1
          AND (
                EXISTS (SELECT 1 FROM SJob.Jobs j WHERE j.Guid = @Guid AND j.ID = a.JobID)
             OR EXISTS (
                    SELECT 1
                    FROM SJob.Milestones m
                    JOIN SJob.Jobs jm ON jm.ID = m.JobID
                    WHERE jm.Guid = @Guid
                      AND a.MilestoneID = m.ID
                      AND m.RowStatus NOT IN (0,254)
                )
             OR EXISTS (
                    SELECT 1
                    FROM SJob.Activities act
                    WHERE a.ActivityID = act.ID
                      AND act.RowStatus NOT IN (0,254)
                      AND (
                            EXISTS (SELECT 1 FROM SJob.Jobs jact WHERE jact.Guid = @Guid AND jact.ID = act.JobID)
                         OR EXISTS (
                                SELECT 1
                                FROM SJob.Milestones am
                                JOIN SJob.Jobs amj ON amj.ID = am.JobID
                                WHERE amj.Guid = @Guid
                                  AND act.MilestoneID = am.ID
                                  AND am.RowStatus NOT IN (0,254)
                            )
                          )
                )
          )
    ))
    BEGIN
        SET @Lbl = N'Outstanding Actions'; SET @Cls = N'bg-warning'; SET @Ord = 4;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END

    -------------------------------------------------------------------------
    -- BCCS exemption list (preserved) - de-dupe safe
    -------------------------------------------------------------------------
    DECLARE @OrgTypes TABLE (OrganisationalUnitID UNIQUEIDENTIFIER);
    INSERT INTO @OrgTypes (OrganisationalUnitID)
    VALUES ('F233BB03-3181-49AE-B331-39C58F328457'); -- BCCS

    IF (@ClientAppointmentReceived = 0
        AND @OrganisationalUnitGuid NOT IN (SELECT OrganisationalUnitID FROM @OrgTypes)
        AND @JobTypeGuid IN (
            '3B2BB359-D4DA-417E-8D0D-78C82F0EE043', -- CDM-PD
            'AFFB3DA2-EDD8-42A5-A481-8E4AA5A73EC1', -- CDM-CON
            '57832995-708D-4B9C-8172-07BD94A3EBCA'  -- CDM-PRE
        )
    )
    BEGIN
        SET @Lbl = N'No Client Appointment Received'; SET @Cls = N'bg-danger'; SET @Ord = 5;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END

    -------------------------------------------------------------------------
    -- F10 Expired (preserved) - de-dupe safe
    -------------------------------------------------------------------------
    IF (EXISTS
    (
        SELECT 1
        FROM SJob.Milestones m
        JOIN SJob.MilestoneTypes mt ON mt.ID = m.MilestoneTypeID
        WHERE m.JobID = @JobID
          AND mt.Code = N'F10'
          AND m.CompletedDateTimeUTC IS NULL
          AND m.IsNotApplicable = 0
          AND (
                CONVERT(date, ISNULL(m.DueDateTimeUTC, GETUTCDATE())) < CONVERT(date, GETUTCDATE())
             OR CONVERT(date, ISNULL(m.ScheduledDateTimeUTC, GETUTCDATE())) < CONVERT(date, GETUTCDATE())
          )
    ))
    BEGIN
        SET @Lbl = N'F10 Expired'; SET @Cls = N'bg-danger'; SET @Ord = 6;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END

    -------------------------------------------------------------------------
    -- Overdue Milestones (preserved) - de-dupe safe
    -------------------------------------------------------------------------
    IF (EXISTS
    (
        SELECT 1
        FROM SJob.Milestones m
        WHERE m.JobId = @JobID
          AND m.RowStatus NOT IN (0,254)
          AND ISNULL(m.IsNotApplicable, 0) = 0
          AND m.CompletedDateTimeUTC IS NULL
          AND m.DueDateTimeUTC IS NOT NULL
          AND m.DueDateTimeUTC < GETUTCDATE()
    ))
    BEGIN
        SET @Lbl = N'Overdue Milestones.'; SET @Cls = N'bg-warning'; SET @Ord = 6;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END

    -------------------------------------------------------------------------
    -- Incomplete historic activities (preserved) - de-dupe safe
    -------------------------------------------------------------------------
    IF (EXISTS
    (
        SELECT 1
        FROM SJob.Activities a
        WHERE a.JobID = @JobID
          AND a.EndDate < GETUTCDATE()
          AND EXISTS
          (
              SELECT 1
              FROM SJob.ActivityStatus ast
              WHERE ast.ID = a.ActivityStatusID
                AND ast.IsCompleteStatus = 0
          )
    ))
    BEGIN
        SET @Lbl = N'Incomplete Activities.'; SET @Cls = N'bg-warning'; SET @Ord = 6;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END

    -------------------------------------------------------------------------
    -- Cannot be invoiced (preserved) - de-dupe safe
    -------------------------------------------------------------------------
    IF (@CannotBeInvoiced = 1)
    BEGIN
        SET @Lbl = N'Cannot Be Invoiced'; SET @Cls = N'bg-danger'; SET @Ord = 7;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END

    -------------------------------------------------------------------------
    -- Contract pills (preserved) - de-dupe safe
    -------------------------------------------------------------------------
    IF(@ContractGuid <> '00000000-0000-0000-0000-000000000000'
       OR @AgentContractGuid <> '00000000-0000-0000-0000-000000000000')
    BEGIN
        SET @Lbl = N'Contract In Place'; SET @Cls = N'bg-warning'; SET @Ord = 7;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);

        DECLARE @EndDate DATE,
                @NextReviewDate DATE;

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
            SET @Lbl = N'Contract Ending In ' + CONVERT(NVARCHAR(10), DATEDIFF(DAY, GETDATE(), @EndDate)) + N' Days';
            SET @Cls = N'bg-danger'; SET @Ord = 8;
            IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
                INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
        END

        IF (@NextReviewDate IS NOT NULL AND DATEDIFF(DAY, GETDATE(), @NextReviewDate) <= 30)
        BEGIN
            SET @Lbl = N'Contract Needs Reviewing By ' + CONVERT(NVARCHAR(10), @NextReviewDate, 23);
            SET @Cls = N'bg-danger'; SET @Ord = 9;
            IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
                INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
        END
    END

    -------------------------------------------------------------------------
    -- Latest-only: User Action Required / Customer Waiting (preserved) - de-dupe safe
    -------------------------------------------------------------------------
    IF (@LatestRequiresUsersAction = 1)
    BEGIN
        SET @Lbl = N'User Action Required'; SET @Cls = N'bg-warning'; SET @Ord = 0;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END

    IF (@LatestIsCustomerWaiting = 1)
    BEGIN
        SET @Lbl = N'Awaiting Customer'; SET @Cls = N'bg-warning'; SET @Ord = 0;
        IF NOT EXISTS (SELECT 1 FROM @DataPills WHERE Label = @Lbl)
            INSERT @DataPills (Label, Class, SortOrder) VALUES (@Lbl, @Cls, @Ord);
    END


	DECLARE @ScheduledInvoicingTypeName NVARCHAR(50);


	SELECT TOP(1) @ScheduledInvoicingTypeName = invtr.Name
	FROM SSop.QuoteItems root_hobt
	JOIN SJob.Jobs AS j ON (j.ID = root_hobt.CreatedJobId)
	JOIN SFin.InvoiceSchedules AS invsch ON (root_hobt.InvoicingSchedule = invsch.ID)
	JOIN SFin.InvoiceScheduleTrigger AS invtr ON (invtr.ID = invsch.TriggerId)
	WHERE j.Guid = @Guid

	IF(@ScheduledInvoicingTypeName <> N'')
	BEGIN 
		INSERT @DataPills (Label, Class, SortOrder)
			VALUES (@ScheduledInvoicingTypeName + N' Invoicing Type', N'bg-success', 0);
	END;

	DECLARE 
		@NotInvoicedAmount	DECIMAL(18,2) = 0.0,
		@OutStandingAmount	DECIMAL(18,2) = 0.0,
		@Overdue_1_30		DECIMAL(18,2) = 0.0,
		@Overdue_31_60		DECIMAL(18,2) = 0.0,
		@Overdue_61_90		DECIMAL(18,2) = 0.0,
		@Overdue_90Plus		DECIMAL(18,2) = 0.0;

		SELECT 
		@NotInvoicedAmount = ISNULL(root_hobt.NotInvoicedAmount, 0),
		@OutStandingAmount = ISNULL(root_hobt.OutStandingAmount, 0),
		@Overdue_1_30      = ISNULL(root_hobt.Overdue_1_30, 0),
		@Overdue_31_60     = ISNULL(root_hobt.Overdue_31_60, 0),
		@Overdue_61_90     = ISNULL(root_hobt.Overdue_61_90, 0),
		@Overdue_90Plus    = ISNULL(root_hobt.Overdue_90Plus, 0)
	FROM [SFin].[tvf_OverdueInvoicesForJob](@Guid) AS root_hobt;

	INSERT @DataPills (Label, Class, SortOrder)
	VALUES  (N'Amount not invoiced: £' + CONVERT(NVARCHAR(50), @NotInvoicedAmount), N'financial-data', 0),
	        (N'Outstanding amount: £' + CONVERT(NVARCHAR(50), @OutStandingAmount), N'financial-data', 0),
	        (N'Overdue_1_30: £' + CONVERT(NVARCHAR(50), @Overdue_1_30), N'financial-data', 0),
	        (N'Overdue_31_60: £' + CONVERT(NVARCHAR(50), @Overdue_31_60), N'financial-data', 0),
	        (N'Overdue_61_90: £' + CONVERT(NVARCHAR(50), @Overdue_61_90), N'financial-data', 0),
	        (N'Overdue_90+: £' + CONVERT(NVARCHAR(50), @Overdue_90Plus), N'financial-data', 0)

    RETURN;
END;
GO