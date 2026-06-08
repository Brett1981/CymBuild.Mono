SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create procedure [SSop].[QuotesUpsert]')
GO
PRINT (N'Create procedure [SSop].[QuotesUpsert]')
GO

CREATE PROCEDURE [SSop].[QuotesUpsert]
(
    @OrganisationalUnitGuid UNIQUEIDENTIFIER,
    @QuotingUserGuid UNIQUEIDENTIFIER,
    @ContractGuid UNIQUEIDENTIFIER,
    @Date DATE,
    @Overview NVARCHAR(MAX),
    @ExpiryDate DATE,
    @DateSent DATE,
    @DateAccepted DATE,
    @DateRejected DATE,
    @RejectionReason NVARCHAR(MAX),
    @FeeCap DECIMAL(19, 2),
    @IsFinal BIT,
    @ExternalReference NVARCHAR(50),
    @QuotingConsultantGuid UNIQUEIDENTIFIER,
    @AppointmentFromRibaStageGuid UNIQUEIDENTIFIER,
    @CurrentStageGuid UNIQUEIDENTIFIER,
    @DeadDate DATE,
    @EnquiryServiceGuid UNIQUEIDENTIFIER,
    @ProjectGuid UNIQUEIDENTIFIER,
    @Guid UNIQUEIDENTIFIER,
    @JobType UNIQUEIDENTIFIER,
    @DeclinedToQuoteReason NVARCHAR(MAX),
    @DescriptionOfWorks NVARCHAR(MAX),
    @ExclusionsAndLimitations NVARCHAR(MAX),
    @AgentContractGuid UNIQUEIDENTIFIER,
    @IsSubjectToNDA BIT,
    @SectorGuid UNIQUEIDENTIFIER,
    @MarketGuid UNIQUEIDENTIFIER,
    @DataClassificationGuid UNIQUEIDENTIFIER,
    @SecurityClassificationGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    DECLARE @OrganisationalUnitId INT = -1,
            @QuotingUserId INT,
            @ContractId INT = -1,
            @IsInsert BIT = 0,
            @QuoteId INT,
            @QuoteNumber INT,
            @QuotingConsultantId INT,
            @AppointmentFromRibaStageId INT,
            @CurrentStageId INT,
            @EnquiryServiceID INT,
            @ProjectID INT,
            @JobTypeId INT,
            @AgentContractID INT = -1,
            @SectorId INT = -1,
            @MarketId INT = -1,
            @DataClassificationId INT = -1,
            @SecurityClassificationId INT = -1;

    SELECT @OrganisationalUnitId = ID
    FROM SCore.OrganisationalUnits
    WHERE Guid = @OrganisationalUnitGuid;

    SELECT @QuotingUserId = ID
    FROM SCore.Identities
    WHERE Guid = @QuotingUserGuid;

    SELECT @QuotingConsultantId = ID
    FROM SCore.Identities
    WHERE Guid = @QuotingConsultantGuid;

    SELECT @ContractId = ID
    FROM SSop.Contracts
    WHERE Guid = @ContractGuid;

    SELECT @AppointmentFromRibaStageId = ID
    FROM SJob.RibaStages
    WHERE Guid = @AppointmentFromRibaStageGuid;

    SELECT @EnquiryServiceID = es.ID
    FROM SSop.EnquiryServices AS es
    WHERE es.Guid = @EnquiryServiceGuid;

    SELECT @CurrentStageId = ID
    FROM SJob.RibaStages
    WHERE Guid = @CurrentStageGuid;

    SELECT @ProjectID = p.ID
    FROM SSop.Projects AS p
    WHERE p.Guid = @ProjectGuid;

    SELECT @JobTypeId = jt.ID
    FROM SJob.JobTypes AS jt
    WHERE jt.Guid = @JobType;

    SELECT @AgentContractID = ID
    FROM SSop.Contracts
    WHERE Guid = @AgentContractGuid;

    SELECT @SectorId = ID
    FROM SCore.Sectors
    WHERE Guid = @SectorGuid;

    SELECT @MarketId = ID
    FROM SCore.Markets
    WHERE Guid = @MarketGuid;

    SELECT @DataClassificationId = dc.ID
    FROM SCore.DataClassifications AS dc
    WHERE dc.Guid = @DataClassificationGuid
      AND dc.RowStatus NOT IN (0,254);

    SELECT @SecurityClassificationId = sc.ID
    FROM SCore.SecurityClassifications AS sc
    WHERE sc.Guid = @SecurityClassificationGuid
      AND sc.RowStatus NOT IN (0,254);

    SET @DataClassificationId = ISNULL(@DataClassificationId, -1);
    SET @SecurityClassificationId = ISNULL(@SecurityClassificationId, -1);

    EXEC sys.sp_set_session_context
        @key = N'new_entity_type_guid',
        @value = '1c4794c1-f956-4c32-b886-5500ac778a56',
        @read_only = 0;

    EXEC sys.sp_set_session_context
        @key = N'record_guid',
        @value = @EnquiryServiceGuid,
        @read_only = 0;

    EXEC SCore.UpsertDataObject
        @Guid = @Guid,
        @SchemeName = N'SSop',
        @ObjectName = N'Quotes',
        @IsInsert = @IsInsert OUTPUT;

    EXEC sys.sp_set_session_context @key = N'new_entity_type_guid', @value = NULL, @read_only = 0;
    EXEC sys.sp_set_session_context @key = N'record_guid', @value = NULL, @read_only = 0;

    IF (@IsInsert = 1)
    BEGIN
        IF (@DateSent IS NOT NULL OR @DateAccepted IS NOT NULL)
            THROW 60031, N'CYB-101: Cannot set DateSent/DateAccepted on quote creation until at least one Quote Item exists.', 1;

        INSERT SSop.Quotes
        (
            RowStatus,
            Guid,
            OrganisationalUnitID,
            QuotingUserId,
            ContractID,
            Date,
            Overview,
            ExpiryDate,
            DateSent,
            DateAccepted,
            DateRejected,
            RejectionReason,
            FeeCap,
            IsFinal,
            ExternalReference,
            QuotingConsultantId,
            AppointmentFromRibaStageId,
            CurrentRibaStageId,
            DeadDate,
            EnquiryServiceID,
            ProjectId,            
            JobTypeId,
            DeclinedToQuoteReason,
            DescriptionOfWorks,
            ExclusionsAndLimitations,
            AgentContractID,
            IsSubjectToNDA,
            SectorId,
            MarketId,
            DataClassificationID,
            SecurityClassificationID
        )
        VALUES
        (
            0,
            @Guid,
            @OrganisationalUnitId,
            @QuotingUserId,
            @ContractId,
            @Date,
            @Overview,
            @ExpiryDate,
            @DateSent,
            @DateAccepted,
            @DateRejected,
            @RejectionReason,
            @FeeCap,
            @IsFinal,
            @ExternalReference,
            @QuotingConsultantId,
            @AppointmentFromRibaStageId,
            @CurrentStageId,
            @DeadDate,
            @EnquiryServiceID,
            @ProjectID,
            @JobTypeId,
            @DeclinedToQuoteReason,
            @DescriptionOfWorks,
            @ExclusionsAndLimitations,
            @AgentContractID,
            @IsSubjectToNDA,
            @SectorId,
            @MarketId,
            @DataClassificationId,
            @SecurityClassificationId
        );

        DECLARE @DynamicQuotingStatusForQuotes UNIQUEIDENTIFIER;
        DECLARE @DataObjectTransitionQuoteGuid UNIQUEIDENTIFIER = NEWID();

        SELECT @DynamicQuotingStatusForQuotes = Guid
        FROM SCore.WorkflowStatus
        WHERE RowStatus NOT IN (0,254)
          AND ShowInQuotes = 1
          AND Name = N'Quoting'
          AND Description = N'Automatically generated status';

        EXEC SCore.DataObjectTransitionUpsert
            @Guid = @DataObjectTransitionQuoteGuid,
            @OldStatusGuid = '00000000-0000-0000-0000-000000000000',
            @StatusGuid = @DynamicQuotingStatusForQuotes,
            @Comment = N'System Imported.',
            @CreatedByUserGuid = '00000000-0000-0000-0000-000000000000',
            @SurveyorUserGuid = '00000000-0000-0000-0000-000000000000',
            @DataObjectGuid = @Guid,
            @IsImported = 1;

        DECLARE @EnquiryGuid UNIQUEIDENTIFIER;
        DECLARE @DataObjectTransitionEnquiryGuid UNIQUEIDENTIFIER = NEWID();

        SELECT TOP (1) @EnquiryGuid = e.Guid
        FROM SSop.EnquiryServices AS es
        LEFT JOIN SSop.Enquiries AS e ON e.ID = es.EnquiryId
        WHERE es.ID = @EnquiryServiceID;

        EXEC SCore.DataObjectTransitionUpsert
            @Guid = @DataObjectTransitionEnquiryGuid,
            @OldStatusGuid = '00000000-0000-0000-0000-000000000000',
            @StatusGuid = @DynamicQuotingStatusForQuotes,
            @Comment = N'System Imported.',
            @CreatedByUserGuid = '00000000-0000-0000-0000-000000000000',
            @SurveyorUserGuid = '00000000-0000-0000-0000-000000000000',
            @DataObjectGuid = @EnquiryGuid,
            @IsImported = 1;

        SELECT @QuoteId = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        DECLARE @_quotingConsultant INT,
                @_isFinal BIT,
                @_emailRecipient NVARCHAR(MAX),
                @_emailBody NVARCHAR(MAX),
                @_emailSubject NVARCHAR(MAX),
                @_quoteNumber NVARCHAR(MAX);

        SELECT @_quotingConsultant = QuotingConsultantId,
               @_isFinal = IsFinal,
               @_quoteNumber = Number
        FROM SSop.Quotes
        WHERE Guid = @Guid;

        IF (@DateSent IS NOT NULL OR @DateAccepted IS NOT NULL)
        BEGIN
            DECLARE @QuoteItemCount INT = 0;

            SELECT @QuoteItemCount = COUNT(1)
            FROM SSop.QuoteItems AS qi
            JOIN SSop.Quotes AS q ON q.ID = qi.QuoteId
            WHERE q.Guid = @Guid
              AND q.RowStatus NOT IN (0,254)
              AND qi.RowStatus NOT IN (0,254);

            IF (ISNULL(@QuoteItemCount, 0) <= 0)
                THROW 60032, N'CYB-101: Cannot set Quote to Sent/Accepted (DateSent/DateAccepted) until at least one Quote Item exists.', 1;
        END;

        UPDATE SSop.Quotes
        SET OrganisationalUnitID = @OrganisationalUnitId,
            QuotingUserId = @QuotingUserId,
            ContractID = @ContractId,
            Date = @Date,
            Overview = @Overview,
            ExpiryDate = @ExpiryDate,
            DateSent = @DateSent,
            DateAccepted = @DateAccepted,
            DateRejected = @DateRejected,
            RejectionReason = @RejectionReason,
            FeeCap = @FeeCap,
            IsFinal = @IsFinal,
            ExternalReference = @ExternalReference,
            QuotingConsultantId = @QuotingConsultantId,
            AppointmentFromRibaStageId = @AppointmentFromRibaStageId,
            CurrentRibaStageId = @CurrentStageId,
            DeadDate = @DeadDate,
            EnquiryServiceID = @EnquiryServiceID,
            ProjectId = @ProjectID,
            JobTypeId = @JobTypeId,
            DeclinedToQuoteReason = @DeclinedToQuoteReason,
            DescriptionOfWorks = @DescriptionOfWorks,
            ExclusionsAndLimitations = @ExclusionsAndLimitations,
            AgentContractID = @AgentContractID,
            IsSubjectToNDA = @IsSubjectToNDA,
            SectorId = @SectorId,
            MarketId = @MarketId,
            DataClassificationID = @DataClassificationId,
            SecurityClassificationID = @SecurityClassificationId
        WHERE Guid = @Guid;

        IF (@QuotingConsultantId <> @_quotingConsultant)
        BEGIN
            SELECT @_emailRecipient = i.EmailAddress
            FROM SCore.Identities AS i
            WHERE i.ID = @QuotingConsultantId;

            SET @_emailBody = N'You have been assigned as the consultant for quote <a href="'
                + SCore.GetCurrentApplicationUrl() + N'/QuoteDetail/' + CONVERT(NVARCHAR(MAX), @Guid)
                + N'/%7b%22DataObjectGuid%22%3a%22' + CONVERT(NVARCHAR(MAX), @Guid)
                + N'%22%2c%22EntityTypeGuid%22%3a%221c4794c1-f956-4c32-b886-5500ac778a56%22%7d/https%3a%2f%2fbre.socotec.co.uk%3a9602%2f" taget="_blank">'
                + @_quoteNumber + N'</a>. Please take a moment to review this record.';

            SET @_emailSubject = N'CymBuild: Quote ' + @_quoteNumber + N' assigned to your user.';

            EXEC SAlert.CreateNotification
                @Recipients = @_emailRecipient,
                @Subject = @_emailSubject,
                @Body = @_emailBody,
                @BodyFormat = N'TEXT',
                @Importance = N'NORMAL';
        END;

        IF (@IsFinal <> @_isFinal)
           AND (@IsFinal = 1)
           AND (@DateSent IS NULL)
        BEGIN
            SELECT @_emailRecipient = STRING_AGG(i.EmailAddress, N';')
            FROM SCore.Identities AS i
            JOIN SCore.UserGroups AS ug ON ug.IdentityID = i.ID
            JOIN SCore.Groups AS g ON g.ID = ug.GroupID
            WHERE g.Code = N'CDMSA';

            SET @_emailBody = N'Quote <a href="' + SCore.GetCurrentApplicationUrl() + N'/QuoteDetail/'
                + CONVERT(NVARCHAR(MAX), @Guid)
                + N'/%7b%22DataObjectGuid%22%3a%22' + CONVERT(NVARCHAR(MAX), @Guid)
                + N'%22%2c%22EntityTypeGuid%22%3a%221c4794c1-f956-4c32-b886-5500ac778a56%22%7d/https%3a%2f%2fbre.socotec.co.uk%3a9602%2f" taget="_blank">'
                + @_quoteNumber
                + N'</a> has been marked as final. Please review this record and send out the quote.';

            SET @_emailSubject = N'CymBuild: Quote ' + @_quoteNumber + N' ready to send.';

            EXEC SAlert.CreateNotification
                @Recipients = @_emailRecipient,
                @Subject = @_emailSubject,
                @Body = @_emailBody,
                @BodyFormat = N'TEXT',
                @Importance = N'NORMAL';
        END;
    END;

    IF (@IsInsert = 1)
    BEGIN
        SELECT @QuoteNumber = NEXT VALUE FOR SSop.QuoteNumber;

        UPDATE SSop.Quotes
        SET Number = @QuoteNumber,
            RowStatus = 1
        WHERE ID = @QuoteId;
    END;

    DECLARE @FilingObjectName NVARCHAR(250),
            @FilingLocation NVARCHAR(MAX);

    SELECT @FilingLocation =
    (
        SELECT ss.SiteIdentifier,
               spf.FolderPath
        FROM SCore.ObjectSharePointFolder AS spf
        JOIN SCore.SharepointSites AS ss ON ss.ID = spf.SharepointSiteId
        WHERE spf.ObjectGuid = @Guid
        FOR JSON PATH
    );

    DECLARE @QuoteNumberString NVARCHAR(30);

    SELECT @FilingObjectName = q.Number + N' ' + p.FormattedAddressComma + N' - ' + client.Name + N' / ' + agent.Name
                               + N' - ' + q.Overview,
           @QuoteNumberString = q.Number
    FROM SSop.Quotes AS q
    JOIN SJob.Assets AS p ON p.ID = q.UprnId
    JOIN SCrm.Accounts AS client ON client.ID = q.ClientAccountId
    JOIN SCrm.Accounts AS agent ON agent.ID = q.AgentAccountId
    WHERE q.Guid = @Guid;

    EXEC SOffice.TargetObjectUpsert
        @EntityTypeGuid = N'1c4794c1-f956-4c32-b886-5500ac778a56',
        @RecordGuid = @Guid,
        @Number = @QuoteNumberString,
        @Name = @FilingObjectName,
        @FilingLocation = @FilingLocation;
END;
GO