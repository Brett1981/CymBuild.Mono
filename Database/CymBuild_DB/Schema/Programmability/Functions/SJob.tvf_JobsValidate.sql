SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SJob].[tvf_JobsValidate]')
GO
CREATE FUNCTION [SJob].[tvf_JobsValidate]
(
    @Guid UNIQUEIDENTIFIER,
    @JobCompleted DATETIME2,
    @JobCancelled DATETIME2,
    @DeadDate DATE, 
    @JobTypeGuid UNIQUEIDENTIFIER,
    @CannotBeInvoiced BIT,
    @CannotBeInvoicedReason NVARCHAR(MAX),
    @ContractGuid UNIQUEIDENTIFIER,
    @AgentContractGuid UNIQUEIDENTIFIER
)
RETURNS @ValidationResult TABLE
(
    ID INT IDENTITY(1, 1) NOT NULL,
    TargetGuid UNIQUEIDENTIFIER NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
    TargetType CHAR(1) NOT NULL DEFAULT (''),
    IsReadOnly BIT NOT NULL DEFAULT ((0)),
    IsHidden BIT NOT NULL DEFAULT ((0)),
    IsInvalid BIT NOT NULL DEFAULT ((0)),
    IsInformationOnly BIT NOT NULL DEFAULT((0)),
    Message NVARCHAR(2000) NOT NULL DEFAULT ('')
)
AS
BEGIN
    DECLARE @JobTypeName NVARCHAR(250);
    DECLARE @LatestStatusGuid UNIQUEIDENTIFIER;
    DECLARE @LatestIsCompleteStatus BIT = 0;

    DECLARE @CancelledStatus UNIQUEIDENTIFIER = '18D8E36B-43BE-4BDE-9D0B-1F34B460AD64';
    DECLARE @CompletedStatus UNIQUEIDENTIFIER = '20D22623-283B-4088-9CEB-D944AC3E6516';
    DECLARE @DeadStatus UNIQUEIDENTIFIER = '8C7F7526-559F-4CCF-8FC2-DB0DA67E793D';

    SELECT TOP (1)
        @LatestStatusGuid = ws.Guid,
        @LatestIsCompleteStatus = ISNULL(ws.IsCompleteStatus, 0)
    FROM SCore.DataObjectTransition AS dot
    JOIN SCore.WorkflowStatus AS ws
        ON ws.ID = dot.StatusID
    WHERE dot.DataObjectGuid = @Guid
      AND dot.RowStatus NOT IN (0,254)
      AND ws.RowStatus NOT IN (0,254)
    ORDER BY dot.ID DESC;

    SELECT @JobTypeName = jt.Name
    FROM SJob.JobTypes AS jt
    WHERE jt.Guid = @JobTypeGuid
      AND jt.RowStatus NOT IN (0,254);

    IF (@JobTypeName NOT IN (N'CDM PD', N'CDM PD (Construction Phase Only)', N'CDM PD (Pre-Construction Phase Only)')) 
    BEGIN
        INSERT @ValidationResult
        (
            TargetGuid,
            TargetType,
            IsReadOnly,
            IsHidden,
            IsInvalid,
            Message
        )
        SELECT
            epfv.Guid,
            N'P',
            0,
            1,
            0,
            N''
        FROM SCore.EntityPropertiesForValidationV AS epfv
        WHERE epfv.Name = N'ClientAppointmentReceived'
          AND epfv.Hobt = N'Jobs'
          AND epfv.[Schema] = N'SJob';
    END;

    /*
        Lock only when the latest workflow status is final/dead/cancelled/complete.
        Historical Complete is no longer enough because reopened jobs move:
        Complete -> Reopened -> Job Started.
    */
    IF
    (
        @LatestStatusGuid IN (@CompletedStatus, @CancelledStatus, @DeadStatus)
        OR @LatestIsCompleteStatus = 1
    )
    BEGIN
        INSERT @ValidationResult
        (
            TargetGuid,
            TargetType,
            IsReadOnly,
            IsHidden,
            IsInvalid,
            Message
        )
        SELECT
            epfv.Guid,
            N'P',
            1,
            0,
            0,
            N''
        FROM SCore.EntityPropertiesForValidationV AS epfv
        WHERE epfv.[Schema] = N'SJob'
          AND epfv.Hobt = N'Jobs';
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SJob.Jobs AS j
        WHERE j.Guid = @Guid
          AND j.RowStatus NOT IN (0,254)
    )
    BEGIN
        INSERT @ValidationResult
        (
            TargetGuid,
            TargetType,
            IsReadOnly,
            IsHidden,
            IsInvalid,
            Message
        )
        SELECT
            epfv.Guid,
            N'P',
            1,
            0,
            0,
            N''
        FROM SCore.EntityPropertiesForValidationV AS epfv
        WHERE epfv.Name IN
        (
            N'JobCancelled',
            N'JobDormant',
            N'JobCompleted',
            N'CurrentRibaStageId',
            N'IsCompleteForReview',
            N'ReviewedByUserId',
            N'ReviewedDateTimeUTC'
        )
          AND epfv.Hobt = N'Jobs'
          AND epfv.[Schema] = N'SJob';
    END;

    IF (@CannotBeInvoiced = 0)
    BEGIN
        INSERT @ValidationResult
        (
            TargetGuid,
            TargetType,
            IsReadOnly,
            IsHidden,
            IsInvalid,
            Message
        )
        SELECT
            epfv.Guid,
            N'P',
            1,
            0,
            0,
            N''
        FROM SCore.EntityPropertiesForValidationV AS epfv
        WHERE epfv.Name = N'CannotBeInvoicedReason'
          AND epfv.Hobt = N'Jobs'
          AND epfv.[Schema] = N'SJob';
    END;

    IF (@CannotBeInvoiced = 1 AND ISNULL(@CannotBeInvoicedReason, N'') = N'')
    BEGIN
        INSERT @ValidationResult
        (
            TargetGuid,
            TargetType,
            IsReadOnly,
            IsHidden,
            IsInvalid,
            Message
        )
        SELECT
            epfv.Guid,
            N'P',
            0,
            0,
            1,
            N'Please, provide a reason why the job cannot be invoiced.'
        FROM SCore.EntityPropertiesForValidationV AS epfv
        WHERE epfv.Name = N'CannotBeInvoicedReason'
          AND epfv.Hobt = N'Jobs'
          AND epfv.[Schema] = N'SJob';
    END;

    IF (@ContractGuid <> '00000000-0000-0000-0000-000000000000')
    BEGIN
        INSERT @ValidationResult
        (
            TargetGuid,
            TargetType,
            IsReadOnly,
            IsHidden,
            IsInvalid,
            Message
        )
        SELECT
            epfv.Guid,
            N'P',
            0,
            1,
            0,
            N''
        FROM SCore.EntityPropertiesForValidationV AS epfv
        WHERE epfv.Name = N'AgentContractID'
          AND epfv.Hobt = N'Jobs'
          AND epfv.[Schema] = N'SJob';
    END;
    ELSE IF (@AgentContractGuid <> '00000000-0000-0000-0000-000000000000')
    BEGIN
        INSERT @ValidationResult
        (
            TargetGuid,
            TargetType,
            IsReadOnly,
            IsHidden,
            IsInvalid,
            Message
        )
        SELECT
            epfv.Guid,
            N'P',
            0,
            1,
            0,
            N''
        FROM SCore.EntityPropertiesForValidationV AS epfv
        WHERE epfv.Name = N'ContractID'
          AND epfv.Hobt = N'Jobs'
          AND epfv.[Schema] = N'SJob';
    END;

    RETURN;
END;
GO