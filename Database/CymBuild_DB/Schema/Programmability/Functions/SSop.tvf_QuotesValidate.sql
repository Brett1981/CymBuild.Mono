SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_QuotesValidate]
(
    @Guid UNIQUEIDENTIFIER,
    @DateSent DATE,
    @DeadDate DATE,
    @DateRejected DATE,
    @IsFinal BIT,
    @RevisionNumber INT,
    @OrganisationalUnitGuid UNIQUEIDENTIFIER,
    @DateDeclinedToQuote DATE,
    @DeclinedToQuoteReason NVARCHAR(MAX),
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
    IsInformationOnly BIT NOT NULL DEFAULT ((0)),
    Message NVARCHAR(2000) NOT NULL DEFAULT ('')
)
AS
BEGIN
    DECLARE @EntityTypeGuid UNIQUEIDENTIFIER = '1c4794c1-f956-4c32-b886-5500ac778a56';
    DECLARE @Final      BIT = 0;
    DECLARE @IsSent     BIT = 0;
    DECLARE @IsAccepted BIT = 0;
    DECLARE @IsRejected BIT = 0;
    DECLARE @IsDead     BIT = 0;
    DECLARE @IsReopened BIT = 0;
    DECLARE @ReadyForQuote UNIQUEIDENTIFIER = 'EB867FA0-9608-4CC7-93BE-CC8E8140E8F0';
    -- Ready to Send (replaces legacy IsFinal checkbox meaning)
    DECLARE @FinalStatus    UNIQUEIDENTIFIER = '02A2237F-2AE7-4E05-926F-38E8B7D050A0';
    -- Corrected GUIDs
    DECLARE @SentStatus     UNIQUEIDENTIFIER = '25D5491C-42A8-4B04-B3AC-D648AF0F8032';
    DECLARE @AcceptedStatus UNIQUEIDENTIFIER = '21A29AEE-2D99-4DA3-8182-F31813B0C498';
    DECLARE @RejectedStatus UNIQUEIDENTIFIER = '0A6A71F7-B39F-4213-997E-2B3A13B6144C';
    DECLARE @DeadStatus     UNIQUEIDENTIFIER = '8C7F7526-559F-4CCF-8FC2-DB0DA67E793D';
    DECLARE @Reopened UNIQUEIDENTIFIER;

    -- Make deterministic + rowstatus-safe (optional but recommended)
    SELECT TOP (1) @Reopened = Guid
    FROM SCore.WorkflowStatus
    WHERE RowStatus NOT IN (0,254)
      AND Name LIKE N'%Reopened%'
    ORDER BY ID;
    -------------------------------------------------------------------------
    -- Determine flags based on the LATEST workflow transition for this Quote (latest-only)
    -------------------------------------------------------------------------
DECLARE
      @LatestWorkflowStatusGuid UNIQUEIDENTIFIER = NULL
    , @LatestIsActiveStatus     BIT              = NULL
    , @LatestIsCompleteStatus   BIT              = NULL;
 
	;WITH LatestEffective AS
	(
		SELECT TOP (1)
			  wfs.Guid             AS LatestWorkflowStatusGuid
			, wfs.IsActiveStatus   AS LatestIsActiveStatus
			, wfs.IsCompleteStatus AS LatestIsCompleteStatus
		FROM SCore.DataObjectTransition dot
		JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
		WHERE dot.RowStatus NOT IN (0,254)
		  AND wfs.RowStatus NOT IN (0,254)
		  AND dot.DataObjectGuid = @Guid
		ORDER BY
			dot.ID DESC
	)
	SELECT
		  @LatestWorkflowStatusGuid = LatestWorkflowStatusGuid
		, @LatestIsActiveStatus     = LatestIsActiveStatus
		, @LatestIsCompleteStatus   = LatestIsCompleteStatus
	FROM LatestEffective;

    -- Latest-only flags
    SET @Final      = CASE WHEN @LatestWorkflowStatusGuid = @FinalStatus    THEN 1 ELSE 0 END;
    SET @IsSent     = CASE WHEN @LatestWorkflowStatusGuid = @SentStatus     THEN 1 ELSE 0 END;
    SET @IsAccepted = CASE WHEN @LatestWorkflowStatusGuid = @AcceptedStatus THEN 1 ELSE 0 END;
    SET @IsRejected = CASE WHEN @LatestWorkflowStatusGuid = @RejectedStatus THEN 1 ELSE 0 END;
    SET @IsDead     = CASE WHEN @LatestWorkflowStatusGuid = @DeadStatus     THEN 1 ELSE 0 END;
    SET @IsReopened = CASE WHEN @LatestWorkflowStatusGuid = @Reopened       THEN 1 ELSE 0 END;
    -------------------------------------------------------------------------
    -- Prevent changing Quote if Enquiry not ready for quote review
    -------------------------------------------------------------------------
    IF EXISTS
    (
        SELECT 1
        FROM SSop.Quotes q
        JOIN SSop.EnquiryServices es ON es.ID = q.EnquiryServiceID
        JOIN SSop.Enquiries e ON e.ID = es.EnquiryId
        WHERE q.Guid = @Guid
          AND e.IsReadyForQuoteReview = 0
          AND NOT EXISTS
          (
              SELECT 1
              FROM SCore.DataObjectTransition dob
              JOIN SCore.WorkflowStatus wfs ON dob.StatusID = wfs.ID
              WHERE dob.RowStatus NOT IN (0,254)
                AND wfs.RowStatus NOT IN (0,254)
                AND dob.DataObjectGuid = e.Guid
                AND wfs.Guid = @ReadyForQuote
          )
    )
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT ep.Guid, N'P', 1, 0, 0, N''
        FROM SCore.EntityProperties ep
        JOIN SCore.EntityHobts eh ON eh.ID = ep.EntityHoBTID
        JOIN SCore.EntityTypes et ON et.ID = eh.EntityTypeID
        WHERE et.Name = N'Quotes';
        RETURN;
    END;
    -------------------------------------------------------------------------
    -- Lock quote when jobs exist or dead
    -------------------------------------------------------------------------
    IF EXISTS
    (
        SELECT 1
        FROM SSop.QuoteItems qi
        JOIN SSop.Quotes q ON q.ID = qi.QuoteId
        WHERE q.Guid = @Guid
          AND qi.RowStatus NOT IN (0,254)
          AND qi.CreatedJobId > 0
    )
    OR (@IsDead = 1 OR @DeadDate IS NOT NULL)
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        VALUES (@EntityTypeGuid, N'E', 1, 0, 0, N'');
        RETURN;
    END;
    -------------------------------------------------------------------------
    -- CDM FeeCap hide
    -------------------------------------------------------------------------
    IF EXISTS
    (
        SELECT 1
        FROM SCore.OrganisationalUnits ou
        WHERE ou.Guid = @OrganisationalUnitGuid
          AND ou.Name LIKE N'CDM%'
          AND ou.RowStatus NOT IN (0,254)
    )
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 0, 1, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quotes'
          AND epfvv.Name = N'FeeCap';
    END;
    -------------------------------------------------------------------------
    -- RevisionNumber rule
    -------------------------------------------------------------------------
    IF (@RevisionNumber < 1)
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 1, 1, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quotes'
          AND epfvv.Name = N'RevisionNumber';
    END;
    -------------------------------------------------------------------------
    -- Don’t allow progress beyond Send until quote is Sent
    -------------------------------------------------------------------------
    IF ((@DateSent IS NULL) AND (@IsSent = 0))
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 1, 1, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quotes'
          AND epfvv.Name IN (N'DateAccepted', N'DateRejected', N'RejectionReason', N'ChaseDate1', N'ChaseDate2');
    END;
    -------------------------------------------------------------------------
    -- Sent => IsFinal locked (legacy field still locked, but NO net error now)
    -------------------------------------------------------------------------
    IF ((@IsSent = 1) OR (@DateSent IS NOT NULL))
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 1, 0, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quotes'
          AND epfvv.Name = N'IsFinal';
    END;
    -------------------------------------------------------------------------
    -- Block DateSent until workflow status is Ready to Send
    -------------------------------------------------------------------------
    IF (@Final = 0)
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 1, 1, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quotes'
          AND epfvv.Name = N'DateSent';
    END;
    -------------------------------------------------------------------------
    -- Rejected locking (latest-only + reopen exception)
    -------------------------------------------------------------------------
    IF (((@IsRejected = 1) OR (@DateRejected IS NOT NULL)) AND @IsReopened = 0)
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 1, 0, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quotes';
    END;
    -------------------------------------------------------------------------
    -- Hide AgentContractID if ContractID set, and vice versa
    -------------------------------------------------------------------------
    IF (@ContractGuid <> '00000000-0000-0000-0000-000000000000')
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 0, 1, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quotes'
          AND epfvv.Name = N'AgentContractID';
    END
    ELSE IF (@AgentContractGuid <> '00000000-0000-0000-0000-000000000000')
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 0, 1, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quotes'
          AND epfvv.Name = N'ContractID';
    END;
    -------------------------------------------------------------------------
    -- Final/Ready-to-Send lockdown of fields (KEEP) but NO net value error here
    -------------------------------------------------------------------------
    IF (@Final = 1)
       AND NOT EXISTS
       (
           SELECT 1
           FROM SSop.Quotes q
           WHERE q.Guid = @Guid
             AND q.LegacyId IS NOT NULL
             AND
             (
                 q.OrganisationalUnitID  < 0
              OR q.QuotingUserId         < 0
              OR q.QuotingConsultantId   < 0
             )
       )
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 1, 0, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quotes'
          AND epfvv.Name NOT IN
          (
              N'ChaseDate2', N'ChaseDate1', N'RejectionReason', N'DateRejected', N'DateAccepted',
              N'IsFinal', N'DateSent'
          );
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 1, 0, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt = N'Quote_ExtendedInfo';
    END;
    -------------------------------------------------------------------------
    -- Complete-status lock (latest-only)
    -------------------------------------------------------------------------
    IF (@LatestIsCompleteStatus = 1)
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT epfvv.Guid, N'P', 1, 0, 0, N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SSop'
          AND epfvv.Hobt     = N'Quotes';
    END;
    RETURN;
END;
GO