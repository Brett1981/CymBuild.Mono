SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SFin].[tvf_InvoiceSchedulesValidate]
(
    @Guid                                UNIQUEIDENTIFIER,
    @TriggerGuid                         UNIQUEIDENTIFIER,
    @OnActivityCompletion                BIT,
    @OnMilestoneCompletion               BIT,
    @OnActivityAndMilestonCompletion     BIT,
    @RibaOnCompletion                    BIT,
    @RibaOnPartCompletion                BIT
   
)
RETURNS @ValidationResult TABLE
(
    ID INT IDENTITY(1, 1) NOT NULL,
    TargetGuid UNIQUEIDENTIFIER NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
    TargetType CHAR(1) NOT NULL DEFAULT (''),
    IsReadOnly BIT NOT NULL DEFAULT ((0)),
    IsHidden BIT NOT NULL DEFAULT ((0)),
    IsInvalid BIT NOT NULL DEFAULT ((0)),
    [IsInformationOnly] [BIT] NOT NULL DEFAULT ((0)),
    Message NVARCHAR(2000) NOT NULL DEFAULT ('')
)
AS
BEGIN
    DECLARE
        @TriggerName NVARCHAR(100),
        @InvoiceScheduleId INT,
        @HasCreatedJob BIT = 0,

        /*
            We count the number of checkboxes enabled - there should only be a max of 1 for each config.
            If there are more than 1 enabled, we throw a validation message.
        */
        @SelectedActivityCheckboxCount INT =
             (CASE WHEN @OnActivityCompletion = 1 THEN 1 ELSE 0 END)
            +(CASE WHEN @OnMilestoneCompletion = 1 THEN 1 ELSE 0 END)
            +(CASE WHEN @OnActivityAndMilestonCompletion = 1 THEN 1 ELSE 0 END),

        @SelectedRIBACheckboxCount INT =
             (CASE WHEN @RibaOnCompletion = 1 THEN 1 ELSE 0 END)
            +(CASE WHEN @RibaOnPartCompletion = 1 THEN 1 ELSE 0 END);

    SELECT
        @TriggerName = ist.Name
    FROM SFin.InvoiceScheduleTrigger AS ist
    WHERE ist.Guid = @TriggerGuid;

    SELECT
        @InvoiceScheduleId = ins.ID
    FROM SFin.InvoiceSchedules AS ins
    WHERE ins.Guid = @Guid
      AND ins.RowStatus NOT IN (0,254);

    /*
        Read-only rule:
        If the Invoice Schedule belongs to a Quote whose QuoteItems have created Jobs,
        then the Invoice Schedule form should be read-only unless explicitly bypassed
        by the automation re-enable flow.
    */
   
        IF EXISTS
        (
            SELECT 1
            FROM SFin.InvoiceSchedules AS ins
            INNER JOIN SSop.Quotes AS q
                ON q.ID = ins.QuoteId
               AND q.RowStatus NOT IN (0,254)
            INNER JOIN SSop.QuoteItems AS qi
                ON qi.QuoteId = q.ID
               AND qi.RowStatus NOT IN (0,254)
               AND qi.CreatedJobId > 0
            INNER JOIN SJob.Jobs AS j
                ON j.ID = qi.CreatedJobId
               AND j.RowStatus NOT IN (0,254)
            WHERE ins.ID = @InvoiceScheduleId
              AND ins.RowStatus NOT IN (0,254)
        )
        BEGIN
            SET @HasCreatedJob = 1;
        END;

        IF (@HasCreatedJob = 1)
        BEGIN
            /*
                Make all editable properties on the Invoice Schedule read-only.
                We leave RowStatus/Guid/RowVersion/ID system fields alone.
            */
            INSERT @ValidationResult
                (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
            SELECT
                epfvv.Guid,
                N'P',
                1,
                0,
                0,
                N'This invoice schedule is read-only because a Job has already been created from the related Quote Item.'
            FROM SCore.EntityPropertiesForValidationV AS epfvv
            WHERE epfvv.[Schema] = N'SFin'
              AND epfvv.Hobt = N'InvoiceSchedules'
              AND epfvv.Name NOT IN (N'Guid', N'RowVersion', N'RowStatus', N'ID');
        END;
    

    /*
        =======================================
            Manual
        =======================================
    */
    IF (@TriggerName = N'Manual' OR @TriggerName = N'')
        INSERT @ValidationResult
            (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT
            epfvv.Guid,
            N'P',
            0,
            1,
            0,
            N''
        FROM SCore.EntityPropertiesForValidationV AS epfvv
        WHERE epfvv.[Schema] = N'SFin'
          AND epfvv.Hobt = N'InvoiceSchedules'
          AND epfvv.Name <> N'TriggerId'
          AND epfvv.Name <> N'DescriptionOfWork'
          AND epfvv.Name <> N'Name';

    /*
        =======================================
            MONTHLY DRAWDOWN
        =======================================
    */
    IF (@TriggerName = N'Monthly Drawdowns')
    BEGIN
        INSERT @ValidationResult
            (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT
            epfvv.Guid,
            N'P',
            0,
            1,
            0,
            N''
        FROM SCore.EntityPropertiesForValidationV AS epfvv
        WHERE epfvv.[Schema] = N'SFin'
          AND epfvv.Hobt = N'InvoiceSchedules'
          AND epfvv.Name <> N'TriggerId'
          AND epfvv.Name <> N'DescriptionOfWork'
          AND epfvv.Name <> N'Name';
    END;

    /*
        =======================================
            PERCENTAGE
        =======================================
    */
    IF (@TriggerName = N'Percentage-based')
    BEGIN
        INSERT @ValidationResult
            (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT
            epfvv.Guid,
            N'P',
            0,
            1,
            0,
            N''
        FROM SCore.EntityPropertiesForValidationV AS epfvv
        WHERE epfvv.[Schema] = N'SFin'
          AND epfvv.Hobt = N'InvoiceSchedules'
          AND epfvv.Name <> N'TriggerId'
          AND epfvv.Name <> N'DescriptionOfWork'
          AND epfvv.Name <> N'Name';
    END;

    /*
        =======================================
            RIBA STAGE-BASED
        =======================================
    */
    IF (@TriggerName = N'RIBA Stage-based')
    BEGIN
        INSERT @ValidationResult
            (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT
            epfvv.Guid,
            N'P',
            0,
            1,
            0,
            N''
        FROM SCore.EntityPropertiesForValidationV AS epfvv
        WHERE epfvv.[Schema] = N'SFin'
          AND epfvv.Hobt = N'InvoiceSchedules'
          AND epfvv.Name <> N'TriggerId'
          AND epfvv.Name NOT IN (N'Name', N'RibaOnCompletion', N'RibaOnPartCompletion');

        IF (@SelectedRIBACheckboxCount > 1)
            INSERT @ValidationResult
                (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
            SELECT
                epfvv.Guid,
                N'P',
                0,
                0,
                1,
                N'You can only select one option!'
            FROM SCore.EntityPropertiesForValidationV AS epfvv
            WHERE epfvv.[Schema] = N'SFin'
              AND epfvv.Hobt = N'InvoiceSchedules'
              AND epfvv.Name <> N'TriggerId'
              AND epfvv.Name <> N'DescriptionOfWork'
              AND epfvv.Name IN (N'RibaOnCompletion', N'RibaOnPartCompletion');
    END;

    /*
        =======================================
            ACTIVITY/MILESTONE BASED
        =======================================
    */
    IF (@TriggerName = N'Activity/Milestone-based')
    BEGIN
        INSERT @ValidationResult
            (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT
            epfvv.Guid,
            N'P',
            0,
            1,
            0,
            N''
        FROM SCore.EntityPropertiesForValidationV AS epfvv
        WHERE epfvv.[Schema] = N'SFin'
          AND epfvv.Hobt = N'InvoiceSchedules'
          AND epfvv.Name <> N'TriggerId'
          AND epfvv.Name NOT IN (N'Name', N'OnActivityCompletion', N'OnMilestoneCompletion', N'OnActivityAndMilestonCompletion');

        IF (@SelectedActivityCheckboxCount > 1)
            INSERT @ValidationResult
                (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
            SELECT
                epfvv.Guid,
                N'P',
                0,
                0,
                1,
                N'You can only select one option!'
            FROM SCore.EntityPropertiesForValidationV AS epfvv
            WHERE epfvv.[Schema] = N'SFin'
              AND epfvv.Hobt = N'InvoiceSchedules'
              AND epfvv.Name <> N'TriggerId'
              AND epfvv.Name <> N'DescriptionOfWork'
              AND epfvv.Name IN (N'OnActivityCompletion', N'OnMilestoneCompletion', N'OnActivityAndMilestonCompletion');
    END;

    RETURN;
END;
GO