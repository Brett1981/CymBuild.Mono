SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
/* =========================================================================================
   SSop.EnquiriesUpsert  (instrumented)
   - Adds step-level TRY/CATCH + PRINT logging (shows exactly which call fails)
   - Ensures DataObjects rows exist BEFORE calling DataObjectTransitionUpsert
   - Uses UpsertDataObject for the Enquiry + Transition
   - Does NOT change business logic except for:
       * GUID hardening for @Guid
       * Safe/diagnostic wrappers around ProjectsUpsert, UpsertDataObject, TransitionUpsert
   ========================================================================================= */
CREATE PROCEDURE [SSop].[EnquiriesUpsert]
(
    @OrganisationalUnitGuid UNIQUEIDENTIFIER,
    @Date DATETIME2,
    @CreatedByUserGuid UNIQUEIDENTIFIER,
    @PropertyGuid UNIQUEIDENTIFIER,
    @PropertyNameNumber NVARCHAR(100),
    @PropertyAddressLine1 NVARCHAR(255),
    @PropertyAddressLine2 NVARCHAR(255),
    @PropertyAddressLine3 NVARCHAR(255),
    @PropertyCountyGuid UNIQUEIDENTIFIER,
    @PropertyPostCode NVARCHAR(30),
    @PropertyCountryGuid UNIQUEIDENTIFIER,

    @ClientAccountGuid UNIQUEIDENTIFIER,
    @ClientAddressGuid UNIQUEIDENTIFIER,
    @ClientAccountContactGuid UNIQUEIDENTIFIER,
    @ClientName NVARCHAR(250),
    @ClientAddressNameNumber NVARCHAR(100),
    @ClientAddressLine1 NVARCHAR(255),
    @ClientAddressLine2 NVARCHAR(255),
    @ClientAddressLine3 NVARCHAR(255),
    @ClientAddressCountyGuid UNIQUEIDENTIFIER,
    @ClientAddressPostCode NVARCHAR(30),
    @ClientAddressCountryGuid UNIQUEIDENTIFIER,
    @ClientContactDisplayName NVARCHAR(250),
    @ClientContactDetailTypeGuid UNIQUEIDENTIFIER,
    @ClientContactDetailTypeName NVARCHAR(100),
    @ClientContactDetailTypeValue NVARCHAR(250),

    @AgentAccountGuid UNIQUEIDENTIFIER,
    @AgentAddressGuid UNIQUEIDENTIFIER,
    @AgentAccountContactGuid UNIQUEIDENTIFIER,
    @AgentName NVARCHAR(250),
    @AgentAddressNameNumber NVARCHAR(100),
    @AgentAddressLine1 NVARCHAR(255),
    @AgentAddressLine2 NVARCHAR(255),
    @AgentAddressLine3 NVARCHAR(255),
    @AgentAddressCountyGuid UNIQUEIDENTIFIER,
    @AgentAddressPostCode NVARCHAR(30),
    @AgentAddressCountryGuid UNIQUEIDENTIFIER,
    @AgentContactDisplayName NVARCHAR(250),
    @AgentContactDetailTypeGuid UNIQUEIDENTIFIER,
    @AgentContactDetailTypeName NVARCHAR(100),
    @AgentContactDetailTypeValue NVARCHAR(250),

    @DescriptionOfWorks NVARCHAR(4000),
    @ValueOfWork DECIMAL(19,2),
    @CurrentProjectRobaStageGuid UNIQUEIDENTIFIER,
    @RibaStage0Months INT,
    @RibaStage1Months INT,
    @RibaStage2Months INT,
    @RibaStage3Months INT,
    @RibaStage4Months INT,
    @RibaStage5Months INT,
    @RibaStage6Months INT,
    @RibaStage7Months INT,
    @PreConstructionStageMonths INT,
    @ConstructionStageMonths INT,
    @SendInfoToClient BIT,
    @SendInfoToAgent BIT,
    @KeyDates NVARCHAR(2000),
    @ExpectedProcurementRoute NVARCHAR(200),
    @Notes NVARCHAR(MAX),
    @EnquirySourceGuid UNIQUEIDENTIFIER,
    @IsReadyForQuoteReview BIT,
    @QuotingDeadlineDate DATE,
    @DeclinedToQuoteDate DATE,
    @DeclinedToQuoteReason NVARCHAR(4000),
    @ExternalReference NVARCHAR(50),
    @ProjectGuid UNIQUEIDENTIFIER,
    @IsSubjectToNDA BIT,
    @DeadDate DATE,
    @ChaseDate1 DATE,
    @ChaseDate2 DATE,

    @FinanceAccountGuid UNIQUEIDENTIFIER,
    @FinanceAddressGuid UNIQUEIDENTIFIER,
    @FinanceContactGuid UNIQUEIDENTIFIER,
    @FinanceAccountName NVARCHAR(250),
    @FinanceAddressNameNumber NVARCHAR(100),
    @FinanceAddressLine1 NVARCHAR(255),
    @FinanceAddressLine2 NVARCHAR(255),
    @FinanceAddressLine3 NVARCHAR(255),
    @FinanceCountyGuid UNIQUEIDENTIFIER,
    @FinancePostCode NVARCHAR(30),
    @FinanceContactDisplayName NVARCHAR(250),
    @FinanceContactDetailTypeGuid UNIQUEIDENTIFIER,
    @FinanceContactDetailTypeName NVARCHAR(100),
    @FinanceContactDetailTypeValue NVARCHAR(250),

    @EnterNewClientDetails BIT,
    @EnterNewAgentDetails BIT,
    @EnterNewFinanceDetails BIT,
    @EnterNewStructureDetails BIT,
    @IsClientFinanceAccount BIT,
    @SignatoryIdentityGuid UNIQUEIDENTIFIER,
    @ProposalLetter NVARCHAR(MAX),
    @Guid UNIQUEIDENTIFIER,

    @ContractGuid UNIQUEIDENTIFIER,
    @AgentContractGuid UNIQUEIDENTIFIER,

	@AssetJSONDetails NVARCHAR(500)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @TraceId UNIQUEIDENTIFIER = NEWID(),
        @ProcName SYSNAME = OBJECT_SCHEMA_NAME(@@PROCID) + N'.' + OBJECT_NAME(@@PROCID);

    BEGIN TRY
        PRINT N'[' + @ProcName + N'] TraceId=' + CONVERT(NVARCHAR(36), @TraceId) + N' START';

        -------------------------------------------------------------------------
        -- FIX: Ensure a new record has a real GUID before any DataObject upsert.
        -------------------------------------------------------------------------
        IF (@Guid IS NULL OR @Guid = '00000000-0000-0000-0000-000000000000')
        BEGIN
            SET @Guid = NEWID();
            PRINT N'[' + @ProcName + N'] TraceId=' + CONVERT(NVARCHAR(36), @TraceId)
                + N' Generated new Enquiry Guid=' + CONVERT(NVARCHAR(36), @Guid);
        END

        DECLARE @OrganisationalUnitId INT = -1,
                @CreatedByUserId INT = -1,
                @PropertyId INT = -1,
                @PropertyCountyId INT = -1,
                @PropertyCountryId INT = -1,
                @ClientAccountId INT = -1,
                @ClientAddressId INT = -1,
                @ClientAccountContactId INT = -1,
                @ClientAddressCountyId INT = -1,
                @ClientAddressCountryId INT = -1,
                @AgentAccountId INT = -1,
                @AgentAddressId INT = -1,
                @AgentAccountContactId INT = -1,
                @AgentAddressCountyId INT = -1,
                @AgentAddressCountryId INT = -1,
                @FinanceAccountId INT = -1,
                @FinanceAddressId INT = -1,
                @FinanceAccountContactId INT = -1,
                @FinanceAddressCountyId INT = -1,
                @CurrentProjectRibaStageId INT = -1,
                @IsInsert BIT = 0,
                @EnquiryId INT = NULL,
                @EnquiryNumber INT = NULL,
                @EnquirySourceId INT = -1,
                @ProjectId INT = -1,
                @SignatoryIdentityId INT = -1,
                @NewProject BIT = 0,
                @ProjectDescription NVARCHAR(MAX) = N'Auto Generated Project for Enquiry ' + N'[[number]] - ' + @DescriptionOfWorks,
                @ClientContactDetailTypeId INT = -1,
                @AgentContactDetailTypeId INT = -1,
                @FinanceContactDetailTypeId INT = -1,
                @ContractId INT = -1,
                @AgentContractId INT = -1;

        -------------------------------------------------------------------------
        -- Resolve IDs
        -------------------------------------------------------------------------
        SELECT @OrganisationalUnitId = ID
        FROM SCore.OrganisationalUnits
        WHERE (Guid = @OrganisationalUnitGuid);

        -------------------------------------------------------------------------
        -- Auto-create Project (instrumented)
        -------------------------------------------------------------------------
        IF (@ProjectGuid = '00000000-0000-0000-0000-000000000000')
        BEGIN
            SET @ProjectGuid = NEWID();
            SET @NewProject = 1;

            PRINT N'[' + @ProcName + N'] TraceId=' + CONVERT(NVARCHAR(36), @TraceId)
                + N' Creating Project. ProjectGuid=' + CONVERT(NVARCHAR(36), @ProjectGuid);

            BEGIN TRY
                EXEC SSop.ProjectsUpsert
                     @ExternalReference = N'',
                     @ProjectDescription = @ProjectDescription,
                     @ProjectProjectedStartDate = NULL,
                     @ProjectProjectedEndDate = NULL,
                     @ProjectCompleted = NULL,
                     @IsSubjectToNDA = @IsSubjectToNDA,
                     @Guid = @ProjectGuid;

                PRINT N'[' + @ProcName + N'] TraceId=' + CONVERT(NVARCHAR(36), @TraceId)
                    + N' ProjectsUpsert OK. ProjectGuid=' + CONVERT(NVARCHAR(36), @ProjectGuid);
            END TRY
            BEGIN CATCH
                DECLARE @m_proj NVARCHAR(MAX) =
                    N'[' + @ProcName + N'] TraceId=' + CONVERT(NVARCHAR(36), @TraceId)
                    + N' ProjectsUpsert FAILED. ProjectGuid=' + CONVERT(NVARCHAR(36), @ProjectGuid)
                    + N' | ' + ERROR_MESSAGE();
                ;THROW 60001, @m_proj, 1;
            END CATCH
        END

        SELECT @ContractId = ID
        FROM SSop.Contracts
        WHERE (Guid = @ContractGuid);

        SELECT @AgentContractId = ID
        FROM SSop.Contracts
        WHERE (Guid = @AgentContractGuid);

        SELECT @ProjectId = ID
        FROM SSop.Projects
        WHERE (Guid = @ProjectGuid);

        SELECT @SignatoryIdentityId = ID
        FROM SCore.Identities AS i
        WHERE (Guid = @SignatoryIdentityGuid);

        SELECT @CreatedByUserId = ID
        FROM SCore.Identities
        WHERE (Guid = @CreatedByUserGuid);

        SELECT @ClientAccountId = ID
        FROM SCrm.Accounts
        WHERE (Guid = @ClientAccountGuid);

        SELECT @ClientAddressId = ID
        FROM SCrm.AccountAddresses
        WHERE (Guid = @ClientAddressGuid);

        SELECT @ClientAccountContactId = ID
        FROM SCrm.AccountContacts
        WHERE (Guid = @ClientAccountContactGuid);

        SELECT @AgentAccountId = ID
        FROM SCrm.Accounts
        WHERE (Guid = @AgentAccountGuid);

        SELECT @AgentAddressId = ID
        FROM SCrm.AccountAddresses
        WHERE (Guid = @AgentAddressGuid);

        SELECT @AgentAccountContactId = ID
        FROM SCrm.AccountContacts
        WHERE (Guid = @AgentAccountContactGuid);

        SELECT @FinanceAccountId = ID
        FROM SCrm.Accounts
        WHERE (Guid = @FinanceAccountGuid);

        SELECT @FinanceAddressId = ID
        FROM SCrm.AccountAddresses
        WHERE (Guid = @FinanceAddressGuid);

        SELECT @FinanceAccountContactId = ID
        FROM SCrm.AccountContacts
        WHERE (Guid = @FinanceContactGuid);

        SELECT @PropertyId = ID
        FROM SJob.Assets
        WHERE (Guid = @PropertyGuid);

        SELECT @CurrentProjectRibaStageId = ID
        FROM SJob.RibaStages
        WHERE (Guid = @CurrentProjectRobaStageGuid);

        SELECT @EnquirySourceId = ID
        FROM SSop.QuoteSources
        WHERE (Guid = @EnquirySourceGuid);

        -------------------------------------------------------------------------
        -- Preserve existing “enter new … details” blocks
        -------------------------------------------------------------------------
        IF (@EnterNewStructureDetails = 0)
        BEGIN
            SET @PropertyNameNumber = N'';
            SET @PropertyAddressLine1 = N'';
            SET @PropertyAddressLine2 = N'';
            SET @PropertyAddressLine3 = N'';
            SET @PropertyPostCode = N'';
            SET @PropertyCountyId = -1;
            SET @PropertyCountryId = -1;
        END
        ELSE
        BEGIN
            SELECT @PropertyCountyId = ID
            FROM SCrm.Counties
            WHERE (Guid = @PropertyCountyGuid);

            SELECT @PropertyCountryId = ID
            FROM SCrm.Countries
            WHERE (Guid = @PropertyCountryGuid);
        END

        IF (@EnterNewClientDetails = 0)
        BEGIN
            SET @ClientName = N'';
            SET @ClientAddressNameNumber = N'';
            SET @ClientAddressLine1 = N'';
            SET @ClientAddressLine2 = N'';
            SET @ClientAddressLine3 = N'';
            SET @ClientAddressPostCode = N'';
            SET @ClientAddressCountyId = -1;
            SET @ClientAddressCountryId = -1;
            SET @ClientContactDisplayName = N'';
            SET @ClientContactDetailTypeGuid = '00000000-0000-0000-0000-000000000000';
            SET @ClientContactDetailTypeName = N'';
            SET @ClientContactDetailTypeValue = N'';
        END
        ELSE
        BEGIN
            SELECT @ClientAddressCountyId = ID
            FROM SCrm.Counties
            WHERE (Guid = @ClientAddressCountyGuid);

            SELECT @ClientAddressCountryId = ID
            FROM SCrm.Countries
            WHERE (Guid = @ClientAddressCountryGuid);

            SELECT @ClientContactDetailTypeId = ID
            FROM SCrm.ContactDetailTypes
            WHERE (Guid = @ClientContactDetailTypeGuid);
        END

        IF (@EnterNewAgentDetails = 0)
        BEGIN
            SET @AgentName = N'';
            SET @AgentAddressNameNumber = N'';
            SET @AgentAddressLine1 = N'';
            SET @AgentAddressLine2 = N'';
            SET @AgentAddressLine3 = N'';
            SET @AgentAddressPostCode = N'';
            SET @AgentAddressCountyId = -1;
            SET @AgentAddressCountryId = -1;
            SET @AgentContactDisplayName = N'';
            SET @AgentContactDetailTypeGuid = '00000000-0000-0000-0000-000000000000';
            SET @AgentContactDetailTypeName = N'';
            SET @AgentContactDetailTypeValue = N'';
        END
        ELSE
        BEGIN
            SELECT @FinanceAddressCountyId = ID
            FROM SCrm.Counties
            WHERE (Guid = @FinanceCountyGuid);

            SELECT @AgentAddressCountryId = ID
            FROM SCrm.Countries
            WHERE (Guid = @AgentAddressCountryGuid);

            SELECT @AgentContactDetailTypeId = ID
            FROM SCrm.ContactDetailTypes
            WHERE (Guid = @AgentContactDetailTypeGuid);
        END

        IF (@EnterNewFinanceDetails = 0)
        BEGIN
            SET @FinanceAccountName = N'';
            SET @FinanceAddressNameNumber = N'';
            SET @FinanceAddressLine1 = N'';
            SET @FinanceAddressLine2 = N'';
            SET @FinanceAddressLine3 = N'';
            SET @FinancePostCode = N'';
            SET @FinanceAddressCountyId = -1;
            SET @FinanceContactDisplayName = N'';
            SET @FinanceContactDetailTypeGuid = '00000000-0000-0000-0000-000000000000';
            SET @FinanceContactDetailTypeName = N'';
            SET @FinanceContactDetailTypeValue = N'';
        END
        ELSE
        BEGIN
            SELECT @AgentAddressCountyId = ID
            FROM SCrm.Counties
            WHERE (Guid = @AgentAddressCountyGuid);

            SELECT @FinanceContactDetailTypeId = ID
            FROM SCrm.ContactDetailTypes
            WHERE (Guid = @FinanceContactDetailTypeGuid);
        END

        -------------------------------------------------------------------------
        -- Upsert DataObject for Enquiry (instrumented)
        -------------------------------------------------------------------------
        PRINT N'[' + @ProcName + N'] TraceId=' + CONVERT(NVARCHAR(36), @TraceId)
            + N' Calling SCore.UpsertDataObject for Enquiry. EnquiryGuid=' + CONVERT(NVARCHAR(36), @Guid);

        BEGIN TRY
            EXEC SCore.UpsertDataObject
                 @Guid = @Guid,
                 @SchemeName = N'SSop',
                 @ObjectName = N'Enquiries',
                 @IsInsert = @IsInsert OUTPUT;

            PRINT N'[' + @ProcName + N'] TraceId=' + CONVERT(NVARCHAR(36), @TraceId)
                + N' SCore.UpsertDataObject OK. IsInsert=' + CONVERT(NVARCHAR(5), @IsInsert);
        END TRY
        BEGIN CATCH
            DECLARE @m_do NVARCHAR(MAX) =
                N'[' + @ProcName + N'] TraceId=' + CONVERT(NVARCHAR(36), @TraceId)
                + N' SCore.UpsertDataObject FAILED (Enquiry). EnquiryGuid=' + CONVERT(NVARCHAR(36), @Guid)
                + N' | ' + ERROR_MESSAGE();
            ;THROW 60002, @m_do, 1;
        END CATCH

        -------------------------------------------------------------------------
        -- Insert / Update SSop.Enquiries
        -------------------------------------------------------------------------
        IF (@IsInsert = 1)
        BEGIN
            INSERT SSop.Enquiries
            (
                RowStatus,
                Guid,
                OrganisationalUnitID,
                Date,
                CreatedByUserId,
                Number,
                PropertyId,
                PropertyNameNumber,
                PropertyAddressLine1,
                PropertyAddressLine2,
                PropertyAddressLine3,
                PropertyCountyId,
                PropertyPostCode,
                PropertyCountryId,
                ClientAccountId,
                ClientAddressId,
                ClientAccountContactId,
                ClientName,
                ClientAddressNameNumber,
                ClientAddressLine1,
                ClientAddressLine2,
                ClientAddressLine3,
                ClientAddressCountyId,
                ClientAddressPostCode,
                ClientAddressCountryId,
                ClientContactDisplayName,
                ClientContactDetailType,
                ClientContactDetailTypeName,
                ClientContactDetailTypeValue,
                AgentAccountId,
                AgentAddressId,
                AgentAccountContactId,
                AgentName,
                AgentAddressNameNumber,
                AgentAddressLine1,
                AgentAddressLine2,
                AgentAddressLine3,
                AgentCountyId,
                AgentAddressPostCode,
                AgentCountryId,
                AgentContactDisplayName,
                AgentContactDetailType,
                AgentContactDetailTypeName,
                AgentContactDetailTypeValue,
                DescriptionOfWorks,
                ValueOfWork,
                CurrentProjectRibaStageID,
                RibaStage0Months,
                RibaStage1Months,
                RibaStage2Months,
                RibaStage3Months,
                RibaStage4Months,
                RibaStage5Months,
                RibaStage6Months,
                RibaStage7Months,
                PreConstructionStageMonths,
                ConstructionStageMonths,
                SendInfoToClient,
                SendInfoToAgent,
                KeyDates,
                ExpectedProcurementRoute,
                Notes,
                IsReadyForQuoteReview,
                EnquirySourceId,
                QuotingDeadlineDate,
                DeclinedToQuoteDate,
                DeclinedToQuoteReason,
                ExternalReference,
                ProjectId,
                IsSubjectToNDA,
                DeadDate,
                ChaseDate1,
                ChaseDate2,
                FinanceAccountId,
                FinanceAddressId,
                FinanceContactId,
                FinanceAccountName,
                FinanceAddressNameNumber,
                FinanceAddressLine1,
                FinanceAddressLine2,
                FinanceAddressLine3,
                FinanceCountyId,
                FinancePostCode,
                FinanceContactDisplayName,
                FinanceContactDetailType,
                FinanceContactDetailTypeName,
                FinanceContactDetailTypeValue,
                EnterNewClientDetails,
                EnterNewAgentDetails,
                EnterNewFinanceDetails,
                EnterNewStructureDetails,
                IsClientFinanceAccount,
                SignatoryIdentityId,
                ProposalLetter,
                ContractID,
                AgentContractID,
				AssetJSONDetails
            )
            VALUES
            (
                1,
                @Guid,
                @OrganisationalUnitId,
                @Date,
                @CreatedByUserId,
                0,
                @PropertyId,
                @PropertyNameNumber,
                @PropertyAddressLine1,
                @PropertyAddressLine2,
                @PropertyAddressLine3,
                @PropertyCountyId,
                @PropertyPostCode,
                @PropertyCountryId,
                @ClientAccountId,
                @ClientAddressId,
                @ClientAccountContactId,
                @ClientName,
                @ClientAddressNameNumber,
                @ClientAddressLine1,
                @ClientAddressLine2,
                @ClientAddressLine3,
                @ClientAddressCountyId,
                @ClientAddressPostCode,
                @ClientAddressCountryId,
                @ClientContactDisplayName,
                @ClientContactDetailTypeId,
                @ClientContactDetailTypeName,
                @ClientContactDetailTypeValue,
                @AgentAccountId,
                @AgentAddressId,
                @AgentAccountContactId,
                @AgentName,
                @AgentAddressNameNumber,
                @AgentAddressLine1,
                @AgentAddressLine2,
                @AgentAddressLine3,
                @AgentAddressCountyId,
                @AgentAddressPostCode,
                @AgentAddressCountryId,
                @AgentContactDisplayName,
                @AgentContactDetailTypeId,
                @AgentContactDetailTypeName,
                @AgentContactDetailTypeValue,
                @DescriptionOfWorks,
                @ValueOfWork,
                @CurrentProjectRibaStageId,
                @RibaStage0Months,
                @RibaStage1Months,
                @RibaStage2Months,
                @RibaStage3Months,
                @RibaStage4Months,
                @RibaStage5Months,
                @RibaStage6Months,
                @RibaStage7Months,
                @PreConstructionStageMonths,
                @ConstructionStageMonths,
                @SendInfoToClient,
                @SendInfoToAgent,
                @KeyDates,
                @ExpectedProcurementRoute,
                @Notes,
                @IsReadyForQuoteReview,
                @EnquirySourceId,
                @QuotingDeadlineDate,
                @DeclinedToQuoteDate,
                @DeclinedToQuoteReason,
                @ExternalReference,
                @ProjectId,
                @IsSubjectToNDA,
                @DeadDate,
                @ChaseDate1,
                @ChaseDate2,
                @FinanceAccountId,
                @FinanceAddressId,
                @FinanceAccountContactId,
                @FinanceAccountName,
                @FinanceAddressNameNumber,
                @FinanceAddressLine1,
                @FinanceAddressLine2,
                @FinanceAddressLine3,
                @FinanceAddressCountyId,
                @FinancePostCode,
                @FinanceContactDisplayName,
                @FinanceContactDetailTypeId,
                @FinanceContactDetailTypeName,
                @FinanceContactDetailTypeValue,
                @EnterNewClientDetails,
                @EnterNewAgentDetails,
                @EnterNewFinanceDetails,
                @EnterNewStructureDetails,
                @IsClientFinanceAccount,
                @SignatoryIdentityId,
                @ProposalLetter,
                @ContractId,
                @AgentContractId,
				@AssetJSONDetails
            );

            UPDATE SSop.Projects
            SET IsSubjectToNDA = @IsSubjectToNDA
            WHERE ID = @ProjectId;

            ---------------------------------------------------------------------
            -- Add "New" workflow status to the record upon creation (instrumented)
            ---------------------------------------------------------------------
            DECLARE @DynamicNewStatusForEnquiries UNIQUEIDENTIFIER = NULL;
            DECLARE @DataObjectTransitionGuid UNIQUEIDENTIFIER = NEWID();

            SELECT @DynamicNewStatusForEnquiries = Guid
            FROM SCore.WorkflowStatus
            WHERE (RowStatus NOT IN (0,254))
              AND (ShowInEnquiries = 1)
              AND (Name = N'New')
              AND (Description = N'Automatically generated status');

            PRINT N'[' + @ProcName + N'] TraceId=' + CONVERT(NVARCHAR(36), @TraceId)
                + N' Preparing initial status. TransitionGuid=' + CONVERT(NVARCHAR(36), @DataObjectTransitionGuid)
                + N' NewStatusGuid=' + ISNULL(CONVERT(NVARCHAR(36), @DynamicNewStatusForEnquiries), N'<NULL>');

            IF (@DynamicNewStatusForEnquiries IS NOT NULL)
            BEGIN
                -- DataObject must exist BEFORE transition upsert.
                DECLARE @IsTransitionInsert BIT = 0;

                BEGIN TRY
                    PRINT N'[' + @ProcName + N'] TraceId=' + CONVERT(NVARCHAR(36), @TraceId)
                        + N' Calling SCore.UpsertDataObject for Transition. TransitionGuid=' + CONVERT(NVARCHAR(36), @DataObjectTransitionGuid);

                    EXEC SCore.UpsertDataObject
                        @Guid       = @DataObjectTransitionGuid,
                        @SchemeName = N'SCore',
                        @ObjectName = N'DataObjectTransition',
                        @IsInsert   = @IsTransitionInsert OUTPUT;

                    PRINT N'[' + @ProcName + N'] TraceId=' + CONVERT(NVARCHAR(36), @TraceId)
                        + N' Transition DataObject OK. IsInsert=' + CONVERT(NVARCHAR(5), @IsTransitionInsert);
                END TRY
                BEGIN CATCH
                    DECLARE @m_trdo NVARCHAR(MAX) =
                        N'[' + @ProcName + N'] TraceId=' + CONVERT(NVARCHAR(36), @TraceId)
                        + N' SCore.UpsertDataObject FAILED (Transition). TransitionGuid=' + CONVERT(NVARCHAR(36), @DataObjectTransitionGuid)
                        + N' | EnquiryGuid=' + CONVERT(NVARCHAR(36), @Guid)
                        + N' | ' + ERROR_MESSAGE();
                    ;THROW 60004, @m_trdo, 1;
                END CATCH

                BEGIN TRY
                    PRINT N'[' + @ProcName + N'] TraceId=' + CONVERT(NVARCHAR(36), @TraceId)
                        + N' Calling SCore.DataObjectTransitionUpsert. TransitionGuid=' + CONVERT(NVARCHAR(36), @DataObjectTransitionGuid)
                        + N' EnquiryGuid=' + CONVERT(NVARCHAR(36), @Guid);

                    EXEC SCore.DataObjectTransitionUpsert
                        @Guid = @DataObjectTransitionGuid,
                        @OldStatusGuid = '00000000-0000-0000-0000-000000000000',
                        @StatusGuid = @DynamicNewStatusForEnquiries,
                        @Comment = N'System Imported.',
                        @CreatedByUserGuid = '00000000-0000-0000-0000-000000000000',
                        @SurveyorUserGuid = '00000000-0000-0000-0000-000000000000',
                        @DataObjectGuid = @Guid,
                        @IsImported = 1;

                    PRINT N'[' + @ProcName + N'] TraceId=' + CONVERT(NVARCHAR(36), @TraceId)
                        + N' DataObjectTransitionUpsert OK.';
                END TRY
                BEGIN CATCH
                    DECLARE @m_tr NVARCHAR(MAX) =
                        N'[' + @ProcName + N'] TraceId=' + CONVERT(NVARCHAR(36), @TraceId)
                        + N' DataObjectTransitionUpsert FAILED. TransitionGuid=' + CONVERT(NVARCHAR(36), @DataObjectTransitionGuid)
                        + N' | EnquiryGuid=' + CONVERT(NVARCHAR(36), @Guid)
                        + N' | ' + ERROR_MESSAGE();
                    ;THROW 60003, @m_tr, 1;
                END CATCH
            END
            ELSE
            BEGIN
                PRINT N'[' + @ProcName + N'] TraceId=' + CONVERT(NVARCHAR(36), @TraceId)
                    + N' WARNING: Could not resolve "New" workflow status GUID. No initial transition inserted.';
            END

            SELECT @EnquiryId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE SSop.Enquiries
            SET
                OrganisationalUnitID = @OrganisationalUnitId,
                PropertyId = @PropertyId,
                PropertyNameNumber = @PropertyNameNumber,
                PropertyAddressLine1 = @PropertyAddressLine1,
                PropertyAddressLine2 = @PropertyAddressLine2,
                PropertyAddressLine3 = @PropertyAddressLine3,
                PropertyCountyId = @PropertyCountyId,
                PropertyPostCode = @PropertyPostCode,
                PropertyCountryId = @PropertyCountryId,
                ClientAccountId = @ClientAccountId,
                ClientAddressId = @ClientAddressId,
                ClientAccountContactId = @ClientAccountContactId,
                ClientName = @ClientName,
                ClientAddressNameNumber = @ClientAddressNameNumber,
                ClientAddressLine1 = @ClientAddressLine1,
                ClientAddressLine2 = @ClientAddressLine2,
                ClientAddressLine3 = @ClientAddressLine3,
                ClientAddressCountyId = @ClientAddressCountyId,
                ClientAddressPostCode = @ClientAddressPostCode,
                ClientAddressCountryId = @ClientAddressCountryId,
                ClientContactDisplayName = @ClientContactDisplayName,
                ClientContactDetailType = @ClientContactDetailTypeId,
                ClientContactDetailTypeName = @ClientContactDetailTypeName,
                ClientContactDetailTypeValue = @ClientContactDetailTypeValue,
                AgentAccountId = @AgentAccountId,
                AgentAddressId = @AgentAddressId,
                AgentAccountContactId = @AgentAccountContactId,
                AgentName = @AgentName,
                AgentAddressNameNumber = @AgentAddressNameNumber,
                AgentAddressLine1 = @AgentAddressLine1,
                AgentAddressLine2 = @AgentAddressLine2,
                AgentAddressLine3 = @AgentAddressLine3,
                AgentCountyId = @AgentAddressCountyId,
                AgentAddressPostCode = @AgentAddressPostCode,
                AgentCountryId = @AgentAddressCountryId,
                AgentContactDisplayName = @AgentContactDisplayName,
                AgentContactDetailType = @AgentContactDetailTypeId,
                AgentContactDetailTypeName = @AgentContactDetailTypeName,
                AgentContactDetailTypeValue = @AgentContactDetailTypeValue,
                DescriptionOfWorks = @DescriptionOfWorks,
                ValueOfWork = @ValueOfWork,
                CurrentProjectRibaStageID = @CurrentProjectRibaStageId,
                RibaStage0Months = @RibaStage0Months,
                RibaStage1Months = @RibaStage1Months,
                RibaStage2Months = @RibaStage2Months,
                RibaStage3Months = @RibaStage3Months,
                RibaStage4Months = @RibaStage4Months,
                RibaStage5Months = @RibaStage5Months,
                RibaStage6Months = @RibaStage6Months,
                RibaStage7Months = @RibaStage7Months,
                PreConstructionStageMonths = @PreConstructionStageMonths,
                ConstructionStageMonths = @ConstructionStageMonths,
                SendInfoToClient = @SendInfoToClient,
                SendInfoToAgent = @SendInfoToAgent,
                KeyDates = @KeyDates,
                ExpectedProcurementRoute = @ExpectedProcurementRoute,
                Notes = @Notes,
                IsReadyForQuoteReview = @IsReadyForQuoteReview,
                EnquirySourceId = @EnquirySourceId,
                QuotingDeadlineDate = @QuotingDeadlineDate,
                DeclinedToQuoteDate = @DeclinedToQuoteDate,
                DeclinedToQuoteReason = @DeclinedToQuoteReason,
                ExternalReference = @ExternalReference,
                ProjectId = @ProjectId,
                IsSubjectToNDA = @IsSubjectToNDA,
                DeadDate = @DeadDate,
                ChaseDate1 = @ChaseDate1,
                ChaseDate2 = @ChaseDate2,
                FinanceAccountId = @FinanceAccountId,
                FinanceAddressId = @FinanceAddressId,
                FinanceContactId = @FinanceAccountContactId,
                FinanceAccountName = @FinanceAccountName,
                FinanceAddressNameNumber = @FinanceAddressNameNumber,
                FinanceAddressLine1 = @FinanceAddressLine1,
                FinanceAddressLine2 = @FinanceAddressLine2,
                FinanceAddressLine3 = @FinanceAddressLine3,
                FinanceCountyId = @FinanceAddressCountyId,
                FinancePostCode = @FinancePostCode,
                FinanceContactDisplayName = @FinanceContactDisplayName,
                FinanceContactDetailType = @FinanceContactDetailTypeId,
                FinanceContactDetailTypeName = @FinanceContactDetailTypeName,
                FinanceContactDetailTypeValue = @FinanceContactDetailTypeValue,
                EnterNewClientDetails = @EnterNewClientDetails,
                EnterNewAgentDetails = @EnterNewAgentDetails,
                EnterNewFinanceDetails = @EnterNewFinanceDetails,
                EnterNewStructureDetails = @EnterNewStructureDetails,
                IsClientFinanceAccount = @IsClientFinanceAccount,
                SignatoryIdentityId = @SignatoryIdentityId,
                ProposalLetter = @ProposalLetter,
                ContractID = @ContractId,
                AgentContractID = @AgentContractId,
				AssetJSONDetails = @AssetJSONDetails 
            WHERE (Guid = @Guid);

            UPDATE SSop.Projects
            SET IsSubjectToNDA = @IsSubjectToNDA
            WHERE ID = @ProjectId;
        END

        -------------------------------------------------------------------------
        -- Post-insert number assignment
        -------------------------------------------------------------------------
        IF (@IsInsert = 1)
        BEGIN
            SELECT @EnquiryNumber = NEXT VALUE FOR SSop.EnquiryNumber;

            UPDATE SSop.Enquiries
            SET
                Number = @EnquiryNumber,
                RowStatus = 1
                --QuotingDeadlineDate =
                --    CASE
                --        WHEN DATENAME(WEEKDAY, GETDATE()) IN ('Monday','Tuesday','Wednesday','Thursday') THEN DATEADD(DAY, 6, GETDATE())
                --        WHEN DATENAME(WEEKDAY, GETDATE()) = 'Friday' THEN DATEADD(DAY, 6, GETDATE())
                --        WHEN DATENAME(WEEKDAY, GETDATE()) = 'Saturday' THEN DATEADD(DAY, 5, GETDATE())
                --        WHEN DATENAME(WEEKDAY, GETDATE()) = 'Sunday' THEN DATEADD(DAY, 5, GETDATE())
                --    END
            WHERE (ID = @EnquiryId);

            IF (@NewProject = 1)
            BEGIN
                UPDATE SSop.Projects
                SET ProjectDescription = REPLACE(@ProjectDescription, '[[number]]', CONVERT(NVARCHAR(MAX), @EnquiryNumber))
                WHERE (Guid = @ProjectGuid);
            END
        END

        -------------------------------------------------------------------------
        -- TargetObjectUpsert
        -------------------------------------------------------------------------
        DECLARE @FilingObjectName NVARCHAR(250),
                @FilingLocation NVARCHAR(MAX);

        SELECT
            @FilingLocation =
            (
                SELECT ss.SiteIdentifier, spf.FolderPath
                FROM SCore.ObjectSharePointFolder AS spf
                JOIN SCore.SharepointSites ss ON (ss.ID = spf.SharepointSiteId)
                WHERE (spf.ObjectGuid = @Guid)
                FOR JSON PATH
            );

        DECLARE @EnquiryNumberString NVARCHAR(30);

        SELECT
            @FilingObjectName =
                e.Number + N' ' +
                CASE WHEN p.Id > 0 THEN p.FormattedAddressComma ELSE e.PropertyNameNumber + N' ' + e.PropertyAddressLine1 END +
                N' - ' +
                CASE WHEN client.ID > 0 THEN client.Name ELSE e.ClientName END +
                N' / ' +
                CASE WHEN agent.ID > 0 THEN agent.Name ELSE e.AgentName END +
                N' - ' + e.DescriptionOfWorks,
            @EnquiryNumberString = e.Number
        FROM SSop.Enquiries AS e
        JOIN SJob.Assets AS p ON (p.ID = e.PropertyId)
        JOIN SCrm.Accounts AS client ON (client.ID = e.ClientAccountId)
        JOIN SCrm.Accounts AS agent ON (agent.ID = e.AgentAccountId)
        WHERE (e.Guid = @Guid);

        EXEC SOffice.TargetObjectUpsert
            @EntityTypeGuid = N'3B4F2DF9-B6CF-4A49-9EED-2206473867A1',
            @RecordGuid     = @Guid,
            @Number         = @EnquiryNumberString,
            @Name           = @FilingObjectName,
            @FilingLocation = @FilingLocation;

        PRINT N'[' + @ProcName + N'] TraceId=' + CONVERT(NVARCHAR(36), @TraceId) + N' END OK';
    END TRY
    BEGIN CATCH
        DECLARE @FinalMessage NVARCHAR(MAX) =
            N'[' + OBJECT_SCHEMA_NAME(@@PROCID) + N'.' + OBJECT_NAME(@@PROCID) + N'] '
            + N'TraceId=' + CONVERT(NVARCHAR(36), @TraceId)
            + N' FAILED | ' + ERROR_MESSAGE();

        -- Preserve the original error number if it is one of our thrown ones,
        -- otherwise raise a consistent wrapper.
        IF (ERROR_NUMBER() BETWEEN 60000 AND 60099)
        BEGIN
            ;THROW;
        END
        ELSE
        BEGIN
            ;THROW 60099, @FinalMessage, 1;
        END
    END CATCH
END;
GO