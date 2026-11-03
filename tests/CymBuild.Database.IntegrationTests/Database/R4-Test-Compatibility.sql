SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() NOT LIKE N'CymBuild[_]Test[_]%'
   AND DB_NAME() <> TRY_CONVERT(nvarchar(128), SESSION_CONTEXT(N'CYMBUILD_SQL_TEST_ALLOWED_DATABASE'))
BEGIN
    THROW 62030, N'R4 compatibility schema is restricted to CymBuild_Test_* databases.', 1;
END;

/*
    These empty compatibility tables satisfy deferred references in the current
    canonical SCore.UpsertDataObject and SCore.DataObjectTransitionUpsert bodies.
    The 22 R4 cases never enter these legacy Quote, Job, Enquiry, or default
    security branches. No business fixture rows are inserted into these tables.
*/

IF OBJECT_ID(N'SCore.ObjectSecurity', N'U') IS NULL
BEGIN
    CREATE TABLE SCore.ObjectSecurity
    (
        ID bigint IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL,
        Guid uniqueidentifier NOT NULL,
        ObjectGuid uniqueidentifier NOT NULL,
        UserId int NOT NULL,
        GroupId int NOT NULL,
        CanRead bit NOT NULL,
        DenyRead bit NOT NULL,
        CanWrite bit NOT NULL,
        DenyWrite bit NOT NULL
    );
END;

IF OBJECT_ID(N'SJob.Jobs', N'U') IS NULL
BEGIN
    CREATE TABLE SJob.Jobs
    (
        ID int IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL,
        Guid uniqueidentifier NOT NULL,
        Number nvarchar(50) NOT NULL,
        SurveyorID int NOT NULL,
        JobDescription nvarchar(1000) NOT NULL,
        BillingInstruction nvarchar(max) NULL,
        OrganisationalUnitId int NULL,
        JobDormant datetime2 NULL,
        JobCompleted datetime2 NULL,
        JobCancelled datetime2 NULL,
        DeadDate datetime2 NULL
    );
END;

/*
    R4-CYB-361-Outbox: minimal compatibility stub for SCore.OrganisationalUnits.
    SJob.usp_JobClosureDecision (added for the JobClosureDecision outbox-atomicity
    case) reads only ID/Name/RowStatus; the real table's hierarchyid/generated
    columns and record-history trigger are intentionally not reproduced here.
*/
IF OBJECT_ID(N'SCore.OrganisationalUnits', N'U') IS NULL
BEGIN
    CREATE TABLE SCore.OrganisationalUnits
    (
        ID int IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL,
        Name nvarchar(250) NOT NULL
    );
END;

/*
    R4-CYB-361-Outbox: minimal compatibility stubs for SCore.Workflow and
    SCore.WorkflowTransition. SJob.usp_JobClosureDecision resolves an optional
    notification WorkflowId/WorkflowName from these tables; the 24 R4 cases
    never seed matching rows, so an empty table is sufficient for the query
    to execute and correctly resolve no match.
*/
IF OBJECT_ID(N'SCore.Workflow', N'U') IS NULL
BEGIN
    CREATE TABLE SCore.Workflow
    (
        ID int IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL,
        OrganisationalUnitId int NOT NULL,
        EntityTypeID int NOT NULL,
        Name nvarchar(100) NOT NULL,
        Enabled bit NOT NULL
    );
END;

IF OBJECT_ID(N'SCore.WorkflowTransition', N'U') IS NULL
BEGIN
    CREATE TABLE SCore.WorkflowTransition
    (
        ID int IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL,
        WorkflowID int NOT NULL,
        ToStatusID int NOT NULL,
        Enabled bit NOT NULL
    );
END;

IF OBJECT_ID(N'SSop.Enquiries', N'U') IS NULL
BEGIN
    CREATE TABLE SSop.Enquiries
    (
        ID int IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL,
        Guid uniqueidentifier NOT NULL
    );
END;

IF OBJECT_ID(N'SSop.EnquiryServices', N'U') IS NULL
BEGIN
    CREATE TABLE SSop.EnquiryServices
    (
        ID int IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL,
        Guid uniqueidentifier NOT NULL,
        EnquiryId int NOT NULL
    );
END;

IF OBJECT_ID(N'SSop.Quotes', N'U') IS NULL
BEGIN
    CREATE TABLE SSop.Quotes
    (
        ID int IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL,
        Guid uniqueidentifier NOT NULL,
        EnquiryServiceID int NOT NULL
    );
END;

IF OBJECT_ID(N'SSop.QuoteItems', N'U') IS NULL
BEGIN
    CREATE TABLE SSop.QuoteItems
    (
        ID int IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL,
        QuoteId int NOT NULL,
        CreatedJobId int NULL
    );
END;

IF OBJECT_ID(N'SSop.QuoteItemTotals', N'U') IS NULL
BEGIN
    CREATE TABLE SSop.QuoteItemTotals
    (
        ID int NOT NULL,
        LineNet decimal(19, 2) NULL
    );
END;

/*
    R4-CYB-501-Finance: minimal compatibility stubs for the tables that
    SFin.Transaction_InvoiceMergeInfo (the view backing the invoice preview
    repository) joins against. The Finance test cases never assert on values
    derived from these tables (VAT code text, address blocks, organisational
    unit contact details); they only need the objects to exist so the view
    compiles and its LEFT JOIN/OUTER APPLY branches resolve to no match.
*/
IF OBJECT_ID(N'SCrm.Accounts', N'U') IS NULL
BEGIN
    CREATE TABLE SCrm.Accounts
    (
        ID int IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL CONSTRAINT DF_Test_Accounts_RowStatus DEFAULT (1),
        Name nvarchar(250) NOT NULL CONSTRAINT DF_Test_Accounts_Name DEFAULT (N''),
        MainAccountAddressId int NOT NULL CONSTRAINT DF_Test_Accounts_MainAccountAddressId DEFAULT (-1)
    );
END;

IF OBJECT_ID(N'SFin.VatCodes', N'U') IS NULL
BEGIN
    CREATE TABLE SFin.VatCodes
    (
        ID int IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL CONSTRAINT DF_Test_VatCodes_RowStatus DEFAULT (1),
        SageVatNo nvarchar(20) NOT NULL CONSTRAINT DF_Test_VatCodes_SageVatNo DEFAULT (N'')
    );
END;

IF OBJECT_ID(N'SCrm.AccountAddresses', N'U') IS NULL
BEGIN
    CREATE TABLE SCrm.AccountAddresses
    (
        ID int IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL CONSTRAINT DF_Test_AccountAddresses_RowStatus DEFAULT (1),
        AccountID int NOT NULL CONSTRAINT DF_Test_AccountAddresses_AccountID DEFAULT (-1),
        AddressID int NOT NULL CONSTRAINT DF_Test_AccountAddresses_AddressID DEFAULT (-1),
        IsMain bit NOT NULL CONSTRAINT DF_Test_AccountAddresses_IsMain DEFAULT (0)
    );
END;

IF OBJECT_ID(N'SCrm.Addresses', N'U') IS NULL
BEGIN
    CREATE TABLE SCrm.Addresses
    (
        ID int IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL CONSTRAINT DF_Test_Addresses_RowStatus DEFAULT (1),
        Name nvarchar(250) NOT NULL CONSTRAINT DF_Test_Addresses_Name DEFAULT (N''),
        FormattedAddressCR nvarchar(600) NOT NULL CONSTRAINT DF_Test_Addresses_FormattedAddressCR DEFAULT (N'')
    );
END;

/*
    SSop.EnquiriesUpsert resolves Country / ContactDetailType Guids when an inline
    "enter new … details" block is entered. Only ID/Guid/RowStatus/Name are read.
*/
IF OBJECT_ID(N'SCrm.Countries', N'U') IS NULL
BEGIN
    CREATE TABLE SCrm.Countries
    (
        ID int IDENTITY NOT NULL,
        Guid uniqueidentifier NOT NULL CONSTRAINT DF_Test_Countries_Guid DEFAULT (NEWID()),
        RowStatus tinyint NOT NULL CONSTRAINT DF_Test_Countries_RowStatus DEFAULT (1),
        Name nvarchar(100) NOT NULL CONSTRAINT DF_Test_Countries_Name DEFAULT (N'')
    );
END;

IF OBJECT_ID(N'SCrm.ContactDetailTypes', N'U') IS NULL
BEGIN
    CREATE TABLE SCrm.ContactDetailTypes
    (
        ID int IDENTITY NOT NULL,
        Guid uniqueidentifier NOT NULL CONSTRAINT DF_Test_ContactDetailTypes_Guid DEFAULT (NEWID()),
        RowStatus tinyint NOT NULL CONSTRAINT DF_Test_ContactDetailTypes_RowStatus DEFAULT (1),
        Name nvarchar(100) NOT NULL CONSTRAINT DF_Test_ContactDetailTypes_Name DEFAULT (N'')
    );
END;

IF OBJECT_ID(N'SFin.CreditTerms', N'U') IS NULL
BEGIN
    CREATE TABLE SFin.CreditTerms
    (
        ID int IDENTITY NOT NULL,
        Name nvarchar(50) NOT NULL CONSTRAINT DF_Test_CreditTerms_Name DEFAULT (N'')
    );
END;

/*
    The canonical SCrm.Contact_MergeInfo object is a VIEW over
    SCrm.Contacts/ContactDetails/ContactDetailTypes. SFin.Transaction_InvoiceMergeInfo
    only reads its ID/Email/Phone columns, and SQL Server does not distinguish a
    table from a view when resolving a JOIN, so a minimal table stub satisfies the
    dependency without reproducing the contact-detail lookup chain.
*/
IF OBJECT_ID(N'SCrm.Contact_MergeInfo', N'U') IS NULL
BEGIN
    CREATE TABLE SCrm.Contact_MergeInfo
    (
        ID int IDENTITY NOT NULL,
        Email nvarchar(255) NULL,
        Phone nvarchar(50) NULL
    );
END;

/*
    R4-CYB-501-Finance: SFin.Transaction_InvoiceMergeInfo also reads
    SJob.Jobs.FinanceAccountID/FinanceAddressID/ExternalReference and
    SCore.OrganisationalUnits.CostCentreCode/OfficialAddressId/OfficialContactId.
    These columns were not part of the original CYB-361-Outbox stubs above, so a
    database provisioned before CYB-501 has those tables without them. Add the
    columns idempotently rather than changing the CREATE TABLE bodies above, which
    only run when the table is missing entirely.
*/
IF COL_LENGTH(N'SJob.Jobs', N'FinanceAccountID') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD FinanceAccountID int NOT NULL CONSTRAINT DF_Test_Jobs_FinanceAccountID DEFAULT (-1);
END;

IF COL_LENGTH(N'SJob.Jobs', N'FinanceAddressID') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD FinanceAddressID int NOT NULL CONSTRAINT DF_Test_Jobs_FinanceAddressID DEFAULT (-1);
END;

IF COL_LENGTH(N'SJob.Jobs', N'ExternalReference') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD ExternalReference nvarchar(50) NOT NULL CONSTRAINT DF_Test_Jobs_ExternalReference DEFAULT (N'');
END;

IF COL_LENGTH(N'SCore.OrganisationalUnits', N'CostCentreCode') IS NULL
BEGIN
    ALTER TABLE SCore.OrganisationalUnits ADD CostCentreCode nvarchar(50) NOT NULL CONSTRAINT DF_Test_OrganisationalUnits_CostCentreCode DEFAULT (N'');
END;

IF COL_LENGTH(N'SCore.OrganisationalUnits', N'OfficialAddressId') IS NULL
BEGIN
    ALTER TABLE SCore.OrganisationalUnits ADD OfficialAddressId int NOT NULL CONSTRAINT DF_Test_OrganisationalUnits_OfficialAddressId DEFAULT (-1);
END;

IF COL_LENGTH(N'SCore.OrganisationalUnits', N'OfficialContactId') IS NULL
BEGIN
    ALTER TABLE SCore.OrganisationalUnits ADD OfficialContactId int NOT NULL CONSTRAINT DF_Test_OrganisationalUnits_OfficialContactId DEFAULT (-1);
END;

/*
    R5 slice 1 (QuoteItems -> Job outbox enqueue): minimal compatibility stub for
    SSop.Projects. SCore.IntegrationOutbox_EnqueueJobCreatedFromProposal reads only
    ProjectDescription via an optional JOIN on SJob.Jobs.ProjectId; the real table's
    RecordHistory trigger and remaining columns are intentionally not reproduced here.
*/
IF OBJECT_ID(N'SSop.Projects', N'U') IS NULL
BEGIN
    CREATE TABLE SSop.Projects
    (
        ID int IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL CONSTRAINT DF_Test_Projects_RowStatus DEFAULT (1),
        ProjectDescription nvarchar(max) NOT NULL CONSTRAINT DF_Test_Projects_ProjectDescription DEFAULT (N'')
    );
END;

/*
    R5 slice 2 (Enquiry authorisation-routing, real SSop.EnquiriesUpsert): minimal
    compatibility stubs for the objects EnquiriesUpsert reads unconditionally but whose
    values the Enquiry/authorisation-queue test cases never assert on - a Quote source
    lookup and the SharePoint filing-location subquery that always runs regardless of
    whether a filing folder actually exists for the record.
*/
IF OBJECT_ID(N'SSop.QuoteSources', N'U') IS NULL
BEGIN
    CREATE TABLE SSop.QuoteSources
    (
        ID int IDENTITY NOT NULL,
        Guid uniqueidentifier NOT NULL CONSTRAINT DF_Test_QuoteSources_Guid DEFAULT (NEWID())
    );
END;

IF OBJECT_ID(N'SCore.SharepointSites', N'U') IS NULL
BEGIN
    CREATE TABLE SCore.SharepointSites
    (
        ID int IDENTITY NOT NULL,
        SiteIdentifier nvarchar(250) NOT NULL CONSTRAINT DF_Test_SharepointSites_SiteIdentifier DEFAULT (N'')
    );
END;

IF OBJECT_ID(N'SCore.ObjectSharePointFolder', N'U') IS NULL
BEGIN
    CREATE TABLE SCore.ObjectSharePointFolder
    (
        ID int IDENTITY NOT NULL,
        ObjectGuid uniqueidentifier NOT NULL,
        SharepointSiteId int NOT NULL CONSTRAINT DF_Test_ObjectSharePointFolder_SharepointSiteId DEFAULT (-1),
        FolderPath nvarchar(500) NOT NULL CONSTRAINT DF_Test_ObjectSharePointFolder_FolderPath DEFAULT (N'')
    );
END;

/*
    R5 slice 1: SCore.IntegrationOutbox_EnqueueJobCreatedFromProposal also reads
    SJob.Jobs.ClientAccountID/ProjectId/CreatedOn and SSop.Quotes.Number/QuotingConsultantId.
    Add the columns idempotently rather than changing the CREATE TABLE bodies above, which
    only run when the table is missing entirely.
*/
IF COL_LENGTH(N'SJob.Jobs', N'ClientAccountID') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD ClientAccountID int NOT NULL CONSTRAINT DF_Test_Jobs_ClientAccountID DEFAULT (-1);
END;

IF COL_LENGTH(N'SJob.Jobs', N'ProjectId') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD ProjectId int NOT NULL CONSTRAINT DF_Test_Jobs_ProjectId DEFAULT (-1);
END;

IF COL_LENGTH(N'SJob.Jobs', N'CreatedOn') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD CreatedOn datetime2 NULL;
END;

IF COL_LENGTH(N'SSop.Quotes', N'Number') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD Number nvarchar(50) NOT NULL CONSTRAINT DF_Test_Quotes_Number DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Quotes', N'QuotingConsultantId') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD QuotingConsultantId int NOT NULL CONSTRAINT DF_Test_Quotes_QuotingConsultantId DEFAULT (-1);
END;

/*
    R4-CYB-361 (AuthorisationQueueCountsRegressionTests): SCore.tvf_WF_AuthorisationQueue,
    SCore.vw_WF_AuthorisationQueue_Display, and the SSop.Enquiry_MergeInfo/SSop.Quote_JobsSummary/
    SJob.Job_FeeDrawdown views it joins to read many more Jobs/Enquiries/Quotes/EnquiryServices/
    QuoteItems/Accounts/Addresses columns than the CYB-361-Outbox/R5 stubs above needed. This
    regression test never asserts on the business content of these columns (client/agent contact
    detail, addresses, RIBA staging) - it only compares aggregate row counts between the lean TVF
    and the full display view - so the objects only need to exist for the views/function to compile.
    Add the columns idempotently rather than changing the CREATE TABLE bodies above.
*/
IF COL_LENGTH(N'SJob.Jobs', N'JobTypeID') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD JobTypeID int NOT NULL CONSTRAINT DF_Test_Jobs_JobTypeID DEFAULT (-1);
END;

IF COL_LENGTH(N'SJob.Jobs', N'AgentAccountID') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD AgentAccountID int NOT NULL CONSTRAINT DF_Test_Jobs_AgentAccountID DEFAULT (-1);
END;

IF COL_LENGTH(N'SJob.Jobs', N'UprnID') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD UprnID int NOT NULL CONSTRAINT DF_Test_Jobs_UprnID DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'Number') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD Number nvarchar(50) NOT NULL CONSTRAINT DF_Test_Enquiries_Number DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ProposalLetter') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ProposalLetter nvarchar(max) NULL;
END;

IF COL_LENGTH(N'SSop.Enquiries', N'DescriptionOfWorks') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD DescriptionOfWorks nvarchar(max) NULL;
END;

IF COL_LENGTH(N'SSop.Enquiries', N'Date') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD [Date] datetime2 NULL;
END;

IF COL_LENGTH(N'SSop.Enquiries', N'OrganisationalUnitID') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD OrganisationalUnitID int NOT NULL CONSTRAINT DF_Test_Enquiries_OrganisationalUnitID DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'PropertyId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD PropertyId int NOT NULL CONSTRAINT DF_Test_Enquiries_PropertyId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ClientAccountId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ClientAccountId int NOT NULL CONSTRAINT DF_Test_Enquiries_ClientAccountId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ClientAddressId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ClientAddressId int NOT NULL CONSTRAINT DF_Test_Enquiries_ClientAddressId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ClientAccountContactId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ClientAccountContactId int NOT NULL CONSTRAINT DF_Test_Enquiries_ClientAccountContactId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'AgentAccountId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD AgentAccountId int NOT NULL CONSTRAINT DF_Test_Enquiries_AgentAccountId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'AgentAddressId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD AgentAddressId int NOT NULL CONSTRAINT DF_Test_Enquiries_AgentAddressId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'AgentAccountContactId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD AgentAccountContactId int NOT NULL CONSTRAINT DF_Test_Enquiries_AgentAccountContactId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'SignatoryIdentityId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD SignatoryIdentityId int NOT NULL CONSTRAINT DF_Test_Enquiries_SignatoryIdentityId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'SendInfoToClient') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD SendInfoToClient bit NOT NULL CONSTRAINT DF_Test_Enquiries_SendInfoToClient DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'RowVersion') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD RowVersion rowversion;
END;

IF COL_LENGTH(N'SSop.Enquiries', N'CurrentProjectRibaStageID') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD CurrentProjectRibaStageID int NOT NULL CONSTRAINT DF_Test_Enquiries_CurrentProjectRibaStageID DEFAULT (-1);
END;

IF COL_LENGTH(N'SCore.OrganisationalUnits', N'Guid') IS NULL
BEGIN
    ALTER TABLE SCore.OrganisationalUnits ADD Guid uniqueidentifier NOT NULL CONSTRAINT DF_Test_OrganisationalUnits_Guid DEFAULT (NEWID());
END;

/*
    CYB-543: SFin.TransactionsUpsert resolves an OrganisationalUnits row's
    DepartmentPrefix to build the new Transaction Number, a column the
    CYB-361-Outbox stub never needed.
*/
IF COL_LENGTH(N'SCore.OrganisationalUnits', N'DepartmentPrefix') IS NULL
BEGIN
    ALTER TABLE SCore.OrganisationalUnits ADD DepartmentPrefix nvarchar(10) NOT NULL CONSTRAINT DF_Test_OrganisationalUnits_DepartmentPrefix DEFAULT (N'');
END;

/*
    SSop.Quote_JobsSummary's DateAccepted subquery joins SCore.WorkflowTransition by Guid (a fixed
    status-transition literal), a column the CYB-361-Outbox SCore.WorkflowTransition stub above
    never needed.
*/
IF COL_LENGTH(N'SCore.WorkflowTransition', N'Guid') IS NULL
BEGIN
    ALTER TABLE SCore.WorkflowTransition ADD Guid uniqueidentifier NOT NULL CONSTRAINT DF_Test_WorkflowTransition_Guid DEFAULT (NEWID());
END;

IF COL_LENGTH(N'SFin.CreditTerms', N'DueDays') IS NULL
BEGIN
    ALTER TABLE SFin.CreditTerms ADD DueDays int NOT NULL CONSTRAINT DF_Test_CreditTerms_DueDays DEFAULT (0);
END;

/*
    CYB-543: SageInboundReceiptMaterialisationFallbackTests' invoice fixture
    resolves a CreditTerms row via `ct.RowStatus NOT IN (0,254)`, a column the
    original Finance stub never needed.
*/
IF COL_LENGTH(N'SFin.CreditTerms', N'RowStatus') IS NULL
BEGIN
    ALTER TABLE SFin.CreditTerms ADD RowStatus tinyint NOT NULL CONSTRAINT DF_Test_CreditTerms_RowStatus DEFAULT (1);
END;

/*
    CYB-543: SFin.TransactionsUpsert and SFin.SageInboundReceiptAndAllocation_Materialise
    both resolve a CreditTerms row by Guid, a column the original Finance stub never needed.
*/
IF COL_LENGTH(N'SFin.CreditTerms', N'Guid') IS NULL
BEGIN
    ALTER TABLE SFin.CreditTerms ADD Guid uniqueidentifier NOT NULL CONSTRAINT DF_Test_CreditTerms_Guid DEFAULT (NEWID());
END;

/*
    CYB-543: the same fixture resolves a VatCodes row via
    `vc.Active = 1`, a column the original Finance stub never needed.
*/
IF COL_LENGTH(N'SFin.VatCodes', N'Active') IS NULL
BEGIN
    ALTER TABLE SFin.VatCodes ADD Active bit NOT NULL CONSTRAINT DF_Test_VatCodes_Active DEFAULT (1);
END;

/*
    CYB-543: SFin.TransactionDetailsUpsert and
    SFin.SageInboundReceiptAndAllocation_Materialise both resolve a VatCodes
    row by Guid, a column the original Finance stub never needed.
*/
IF COL_LENGTH(N'SFin.VatCodes', N'Guid') IS NULL
BEGIN
    ALTER TABLE SFin.VatCodes ADD Guid uniqueidentifier NOT NULL CONSTRAINT DF_Test_VatCodes_Guid DEFAULT (NEWID());
END;

/*
    CYB-543: SFin.TransactionDetailsUpsert resolves the VAT rate to apply
    from VatCodes.VatPercentage, a column the original Finance stub never
    needed.
*/
IF COL_LENGTH(N'SFin.VatCodes', N'VatPercentage') IS NULL
BEGIN
    ALTER TABLE SFin.VatCodes ADD VatPercentage decimal(9, 4) NOT NULL CONSTRAINT DF_Test_VatCodes_VatPercentage DEFAULT (0);
END;

/*
    SJob.JobFinance and SJob.Job_FeeDrawdown read the Jobs legacy fixed-fee-bucket columns
    directly (pre-dating SJob.JobRibaStageFees' dynamic per-stage rows).
*/
IF COL_LENGTH(N'SJob.Jobs', N'AgreedFee') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD AgreedFee decimal(19, 2) NOT NULL CONSTRAINT DF_Test_Jobs_AgreedFee DEFAULT (0);
END;

IF COL_LENGTH(N'SJob.Jobs', N'FeeCap') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD FeeCap decimal(19, 2) NOT NULL CONSTRAINT DF_Test_Jobs_FeeCap DEFAULT (0);
END;

IF COL_LENGTH(N'SJob.Jobs', N'PreConstructionStageFee') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD PreConstructionStageFee decimal(19, 2) NOT NULL CONSTRAINT DF_Test_Jobs_PreConstructionStageFee DEFAULT (0);
END;

IF COL_LENGTH(N'SJob.Jobs', N'ConstructionStageFee') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD ConstructionStageFee decimal(19, 2) NOT NULL CONSTRAINT DF_Test_Jobs_ConstructionStageFee DEFAULT (0);
END;

IF COL_LENGTH(N'SJob.Jobs', N'RibaStage1Fee') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD RibaStage1Fee decimal(19, 2) NOT NULL CONSTRAINT DF_Test_Jobs_RibaStage1Fee DEFAULT (0);
END;

IF COL_LENGTH(N'SJob.Jobs', N'RibaStage2Fee') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD RibaStage2Fee decimal(19, 2) NOT NULL CONSTRAINT DF_Test_Jobs_RibaStage2Fee DEFAULT (0);
END;

IF COL_LENGTH(N'SJob.Jobs', N'RibaStage3Fee') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD RibaStage3Fee decimal(19, 2) NOT NULL CONSTRAINT DF_Test_Jobs_RibaStage3Fee DEFAULT (0);
END;

IF COL_LENGTH(N'SJob.Jobs', N'RibaStage4Fee') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD RibaStage4Fee decimal(19, 2) NOT NULL CONSTRAINT DF_Test_Jobs_RibaStage4Fee DEFAULT (0);
END;

IF COL_LENGTH(N'SJob.Jobs', N'RibaStage5Fee') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD RibaStage5Fee decimal(19, 2) NOT NULL CONSTRAINT DF_Test_Jobs_RibaStage5Fee DEFAULT (0);
END;

IF COL_LENGTH(N'SJob.Jobs', N'RibaStage6Fee') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD RibaStage6Fee decimal(19, 2) NOT NULL CONSTRAINT DF_Test_Jobs_RibaStage6Fee DEFAULT (0);
END;

IF COL_LENGTH(N'SJob.Jobs', N'RibaStage7Fee') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD RibaStage7Fee decimal(19, 2) NOT NULL CONSTRAINT DF_Test_Jobs_RibaStage7Fee DEFAULT (0);
END;

IF COL_LENGTH(N'SCrm.Contact_MergeInfo', N'DisplayName') IS NULL
BEGIN
    ALTER TABLE SCrm.Contact_MergeInfo ADD DisplayName nvarchar(250) NULL;
END;

IF COL_LENGTH(N'SCrm.Contact_MergeInfo', N'FirstName') IS NULL
BEGIN
    ALTER TABLE SCrm.Contact_MergeInfo ADD FirstName nvarchar(100) NULL;
END;

IF COL_LENGTH(N'SCrm.Contact_MergeInfo', N'Surname') IS NULL
BEGIN
    ALTER TABLE SCrm.Contact_MergeInfo ADD Surname nvarchar(100) NULL;
END;

IF COL_LENGTH(N'SCrm.Contact_MergeInfo', N'Mobile') IS NULL
BEGIN
    ALTER TABLE SCrm.Contact_MergeInfo ADD Mobile nvarchar(50) NULL;
END;

IF COL_LENGTH(N'SSop.Quotes', N'Overview') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD Overview nvarchar(max) NULL;
END;

IF COL_LENGTH(N'SSop.Quotes', N'IsSubjectToNDA') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD IsSubjectToNDA bit NOT NULL CONSTRAINT DF_Test_Quotes_IsSubjectToNDA DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Quotes', N'ExternalReference') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD ExternalReference nvarchar(50) NOT NULL CONSTRAINT DF_Test_Quotes_ExternalReference DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Quotes', N'FeeCap') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD FeeCap decimal(19, 2) NOT NULL CONSTRAINT DF_Test_Quotes_FeeCap DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Quotes', N'ValueOfWork') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD ValueOfWork decimal(19, 2) NOT NULL CONSTRAINT DF_Test_Quotes_ValueOfWork DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Quotes', N'OrganisationalUnitID') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD OrganisationalUnitID int NOT NULL CONSTRAINT DF_Test_Quotes_OrganisationalUnitID DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Quotes', N'ContractID') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD ContractID int NOT NULL CONSTRAINT DF_Test_Quotes_ContractID DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Quotes', N'AgentContractID') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD AgentContractID int NOT NULL CONSTRAINT DF_Test_Quotes_AgentContractID DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Quotes', N'AppointmentFromRibaStageId') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD AppointmentFromRibaStageId int NOT NULL CONSTRAINT DF_Test_Quotes_AppointmentFromRibaStageId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Quotes', N'RevisionNumber') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD RevisionNumber int NOT NULL CONSTRAINT DF_Test_Quotes_RevisionNumber DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Quotes', N'DeadDate') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD DeadDate datetime2 NULL;
END;

IF COL_LENGTH(N'SSop.Quotes', N'DateAccepted') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD DateAccepted datetime2 NULL;
END;

IF COL_LENGTH(N'SSop.Quotes', N'DateSent') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD DateSent datetime2 NULL;
END;

IF COL_LENGTH(N'SSop.Quotes', N'DateRejected') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD DateRejected datetime2 NULL;
END;

IF COL_LENGTH(N'SSop.Quotes', N'DateDeclinedToQuote') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD DateDeclinedToQuote datetime2 NULL;
END;

IF COL_LENGTH(N'SSop.Quotes', N'DeclinedToQuoteReason') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD DeclinedToQuoteReason nvarchar(max) NULL;
END;

IF COL_LENGTH(N'SSop.EnquiryServices', N'JobTypeId') IS NULL
BEGIN
    ALTER TABLE SSop.EnquiryServices ADD JobTypeId int NOT NULL CONSTRAINT DF_Test_EnquiryServices_JobTypeId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.EnquiryServices', N'RowVersion') IS NULL
BEGIN
    ALTER TABLE SSop.EnquiryServices ADD RowVersion rowversion;
END;

IF COL_LENGTH(N'SSop.QuoteItems', N'ProvideAtStageID') IS NULL
BEGIN
    ALTER TABLE SSop.QuoteItems ADD ProvideAtStageID int NOT NULL CONSTRAINT DF_Test_QuoteItems_ProvideAtStageID DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.QuoteItems', N'ProductId') IS NULL
BEGIN
    ALTER TABLE SSop.QuoteItems ADD ProductId int NOT NULL CONSTRAINT DF_Test_QuoteItems_ProductId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.QuoteItems', N'Quantity') IS NULL
BEGIN
    ALTER TABLE SSop.QuoteItems ADD Quantity decimal(19, 2) NOT NULL CONSTRAINT DF_Test_QuoteItems_Quantity DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.QuoteItems', N'DoNotConsolidateJob') IS NULL
BEGIN
    ALTER TABLE SSop.QuoteItems ADD DoNotConsolidateJob bit NOT NULL CONSTRAINT DF_Test_QuoteItems_DoNotConsolidateJob DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.QuoteItems', N'Net') IS NULL
BEGIN
    ALTER TABLE SSop.QuoteItems ADD Net decimal(19, 2) NOT NULL CONSTRAINT DF_Test_QuoteItems_Net DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.QuoteItems', N'NumberOfMeetings') IS NULL
BEGIN
    ALTER TABLE SSop.QuoteItems ADD NumberOfMeetings int NOT NULL CONSTRAINT DF_Test_QuoteItems_NumberOfMeetings DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.QuoteItems', N'NumberOfSiteVisits') IS NULL
BEGIN
    ALTER TABLE SSop.QuoteItems ADD NumberOfSiteVisits int NOT NULL CONSTRAINT DF_Test_QuoteItems_NumberOfSiteVisits DEFAULT (0);
END;

IF COL_LENGTH(N'SCrm.Accounts', N'CompanyRegistrationNumber') IS NULL
BEGIN
    ALTER TABLE SCrm.Accounts ADD CompanyRegistrationNumber nvarchar(50) NOT NULL CONSTRAINT DF_Test_Accounts_CompanyRegistrationNumber DEFAULT (N'');
END;

/*
    CYB-543: SFin.TransactionsUpsert resolves an Accounts row by Guid, a
    column the original Finance stub never needed.
*/
IF COL_LENGTH(N'SCrm.Accounts', N'Guid') IS NULL
BEGIN
    ALTER TABLE SCrm.Accounts ADD Guid uniqueidentifier NOT NULL CONSTRAINT DF_Test_Accounts_Guid DEFAULT (NEWID());
END;

IF COL_LENGTH(N'SCrm.Addresses', N'AddressLine1') IS NULL
BEGIN
    ALTER TABLE SCrm.Addresses ADD AddressLine1 nvarchar(250) NOT NULL CONSTRAINT DF_Test_Addresses_AddressLine1 DEFAULT (N'');
END;

IF COL_LENGTH(N'SCrm.Addresses', N'AddressLine2') IS NULL
BEGIN
    ALTER TABLE SCrm.Addresses ADD AddressLine2 nvarchar(250) NOT NULL CONSTRAINT DF_Test_Addresses_AddressLine2 DEFAULT (N'');
END;

IF COL_LENGTH(N'SCrm.Addresses', N'AddressLine3') IS NULL
BEGIN
    ALTER TABLE SCrm.Addresses ADD AddressLine3 nvarchar(250) NOT NULL CONSTRAINT DF_Test_Addresses_AddressLine3 DEFAULT (N'');
END;

IF COL_LENGTH(N'SCrm.Addresses', N'Town') IS NULL
BEGIN
    ALTER TABLE SCrm.Addresses ADD Town nvarchar(100) NOT NULL CONSTRAINT DF_Test_Addresses_Town DEFAULT (N'');
END;

IF COL_LENGTH(N'SCrm.Addresses', N'CountyID') IS NULL
BEGIN
    ALTER TABLE SCrm.Addresses ADD CountyID int NOT NULL CONSTRAINT DF_Test_Addresses_CountyID DEFAULT (-1);
END;

IF COL_LENGTH(N'SCrm.Addresses', N'Postcode') IS NULL
BEGIN
    ALTER TABLE SCrm.Addresses ADD Postcode nvarchar(20) NOT NULL CONSTRAINT DF_Test_Addresses_Postcode DEFAULT (N'');
END;

IF COL_LENGTH(N'SCrm.Addresses', N'FormattedAddressComma') IS NULL
BEGIN
    ALTER TABLE SCrm.Addresses ADD FormattedAddressComma nvarchar(600) NOT NULL CONSTRAINT DF_Test_Addresses_FormattedAddressComma DEFAULT (N'');
END;

/*
    R5 slice 2 (Enquiry authorisation-routing, real SSop.EnquiriesUpsert/ProjectsUpsert):
    the R5-slice-1 SSop.Projects stub only carried ProjectDescription; the real
    SSop.ProjectsUpsert/EnquiriesUpsert procedures resolve/maintain the full column set.
*/
IF COL_LENGTH(N'SSop.Projects', N'Guid') IS NULL
BEGIN
    ALTER TABLE SSop.Projects ADD Guid uniqueidentifier NOT NULL CONSTRAINT DF_Test_Projects_Guid DEFAULT (NEWID());
END;

IF COL_LENGTH(N'SSop.Projects', N'Number') IS NULL
BEGIN
    ALTER TABLE SSop.Projects ADD Number int NOT NULL CONSTRAINT DF_Test_Projects_Number DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Projects', N'ExternalReference') IS NULL
BEGIN
    ALTER TABLE SSop.Projects ADD ExternalReference nvarchar(50) NOT NULL CONSTRAINT DF_Test_Projects_ExternalReference DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Projects', N'ProjectProjectsStartDate') IS NULL
BEGIN
    ALTER TABLE SSop.Projects ADD ProjectProjectsStartDate date NULL;
END;

IF COL_LENGTH(N'SSop.Projects', N'ProjectProjectedEndDate') IS NULL
BEGIN
    ALTER TABLE SSop.Projects ADD ProjectProjectedEndDate date NULL;
END;

IF COL_LENGTH(N'SSop.Projects', N'ProjectCompleted') IS NULL
BEGIN
    ALTER TABLE SSop.Projects ADD ProjectCompleted date NULL;
END;

IF COL_LENGTH(N'SSop.Projects', N'IsSubjectToNDA') IS NULL
BEGIN
    ALTER TABLE SSop.Projects ADD IsSubjectToNDA bit NOT NULL CONSTRAINT DF_Test_Projects_IsSubjectToNDA DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Projects', N'DataClassificationID') IS NULL
BEGIN
    ALTER TABLE SSop.Projects ADD DataClassificationID int NOT NULL CONSTRAINT DF_Test_Projects_DataClassificationID DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Projects', N'SecurityClassificationID') IS NULL
BEGIN
    ALTER TABLE SSop.Projects ADD SecurityClassificationID int NOT NULL CONSTRAINT DF_Test_Projects_SecurityClassificationID DEFAULT (-1);
END;

/*
    R5 slice 2: SSop.ProjectsUpsert unconditionally re-points SSop.Quotes/SJob.Jobs
    classification columns for the upserted project's existing Quotes/Jobs (a no-op
    UPDATE...FROM when none exist yet, as in these test cases, but the columns must
    exist for the statement to compile).
*/
IF COL_LENGTH(N'SSop.Quotes', N'ProjectId') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD ProjectId int NOT NULL CONSTRAINT DF_Test_Quotes_ProjectId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Quotes', N'DataClassificationID') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD DataClassificationID int NOT NULL CONSTRAINT DF_Test_Quotes_DataClassificationID DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Quotes', N'SecurityClassificationID') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD SecurityClassificationID int NOT NULL CONSTRAINT DF_Test_Quotes_SecurityClassificationID DEFAULT (-1);
END;

IF COL_LENGTH(N'SJob.Jobs', N'DataClassificationID') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD DataClassificationID int NOT NULL CONSTRAINT DF_Test_Jobs_DataClassificationID DEFAULT (-1);
END;

IF COL_LENGTH(N'SJob.Jobs', N'SecurityClassificationID') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD SecurityClassificationID int NOT NULL CONSTRAINT DF_Test_Jobs_SecurityClassificationID DEFAULT (-1);
END;

/*
    R5 slice 2: SSop.EnquiriesUpsert resolves Client/Agent/Finance address rows by Guid,
    a column the CYB-501-Finance AccountAddresses stub never needed.
*/
IF COL_LENGTH(N'SCrm.AccountAddresses', N'Guid') IS NULL
BEGIN
    ALTER TABLE SCrm.AccountAddresses ADD Guid uniqueidentifier NOT NULL CONSTRAINT DF_Test_AccountAddresses_Guid DEFAULT (NEWID());
END;

/*
    R5 slice 2 (Enquiry authorisation-routing): the real SSop.EnquiriesUpsert's INSERT
    references the full production Enquiries column set. Every addition below mirrors
    Database/CymBuild_DB/Schema/Tables/SSop.Enquiries.sql exactly (name, type, default).
*/
IF COL_LENGTH(N'SSop.Enquiries', N'CreatedByUserId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD CreatedByUserId int NOT NULL CONSTRAINT DF_Test_Enquiries_CreatedByUserId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'PropertyNameNumber') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD PropertyNameNumber nvarchar(100) NOT NULL CONSTRAINT DF_Test_Enquiries_PropertyNameNumber DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'PropertyAddressLine1') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD PropertyAddressLine1 nvarchar(255) NOT NULL CONSTRAINT DF_Test_Enquiries_PropertyAddressLine1 DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'PropertyAddressLine2') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD PropertyAddressLine2 nvarchar(255) NOT NULL CONSTRAINT DF_Test_Enquiries_PropertyAddressLine2 DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'PropertyAddressLine3') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD PropertyAddressLine3 nvarchar(255) NOT NULL CONSTRAINT DF_Test_Enquiries_PropertyAddressLine3 DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'PropertyCountyId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD PropertyCountyId int NOT NULL CONSTRAINT DF_Test_Enquiries_PropertyCountyId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'PropertyPostCode') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD PropertyPostCode nvarchar(30) NOT NULL CONSTRAINT DF_Test_Enquiries_PropertyPostCode DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'PropertyCountryId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD PropertyCountryId int NOT NULL CONSTRAINT DF_Test_Enquiries_PropertyCountryId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ClientName') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ClientName nvarchar(250) NOT NULL CONSTRAINT DF_Test_Enquiries_ClientName DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ClientAddressNameNumber') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ClientAddressNameNumber nvarchar(100) NOT NULL CONSTRAINT DF_Test_Enquiries_ClientAddressNameNumber DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ClientAddressLine1') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ClientAddressLine1 nvarchar(255) NOT NULL CONSTRAINT DF_Test_Enquiries_ClientAddressLine1 DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ClientAddressLine2') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ClientAddressLine2 nvarchar(255) NOT NULL CONSTRAINT DF_Test_Enquiries_ClientAddressLine2 DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ClientAddressLine3') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ClientAddressLine3 nvarchar(255) NOT NULL CONSTRAINT DF_Test_Enquiries_ClientAddressLine3 DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ClientAddressCountyId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ClientAddressCountyId int NOT NULL CONSTRAINT DF_Test_Enquiries_ClientAddressCountyId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ClientAddressPostCode') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ClientAddressPostCode nvarchar(30) NOT NULL CONSTRAINT DF_Test_Enquiries_ClientAddressPostCode DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ClientAddressCountryId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ClientAddressCountryId int NOT NULL CONSTRAINT DF_Test_Enquiries_ClientAddressCountryId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ClientContactDisplayName') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ClientContactDisplayName nvarchar(250) NOT NULL DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ClientContactDetailType') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ClientContactDetailType smallint NOT NULL DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ClientContactDetailTypeName') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ClientContactDetailTypeName nvarchar(100) NOT NULL DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ClientContactDetailTypeValue') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ClientContactDetailTypeValue nvarchar(250) NOT NULL DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'AgentName') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD AgentName nvarchar(250) NOT NULL CONSTRAINT DF_Test_Enquiries_AgentName DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'AgentAddressNameNumber') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD AgentAddressNameNumber nvarchar(100) NOT NULL CONSTRAINT DF_Test_Enquiries_AgentAddressNameNumber DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'AgentAddressLine1') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD AgentAddressLine1 nvarchar(255) NOT NULL CONSTRAINT DF_Test_Enquiries_AgentAddressLine1 DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'AgentAddressLine2') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD AgentAddressLine2 nvarchar(255) NOT NULL CONSTRAINT DF_Test_Enquiries_AgentAddressLine2 DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'AgentAddressLine3') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD AgentAddressLine3 nvarchar(255) NOT NULL CONSTRAINT DF_Test_Enquiries_AgentAddressLine3 DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'AgentCountyId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD AgentCountyId int NOT NULL CONSTRAINT DF_Test_Enquiries_AgentCountyId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'AgentAddressPostCode') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD AgentAddressPostCode nvarchar(30) NOT NULL CONSTRAINT DF_Test_Enquiries_AgentAddressPostCode DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'AgentCountryId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD AgentCountryId int NOT NULL CONSTRAINT DF_Test_Enquiries_AgentCountryId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'AgentContactDisplayName') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD AgentContactDisplayName nvarchar(250) NOT NULL DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'AgentContactDetailType') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD AgentContactDetailType smallint NOT NULL DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'AgentContactDetailTypeName') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD AgentContactDetailTypeName nvarchar(100) NOT NULL DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'AgentContactDetailTypeValue') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD AgentContactDetailTypeValue nvarchar(250) NOT NULL DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ValueOfWork') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ValueOfWork decimal(19, 2) NOT NULL CONSTRAINT DF_Test_Enquiries_ValueOfWork DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'RibaStage0Months') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD RibaStage0Months int NOT NULL CONSTRAINT DF_Test_Enquiries_RibaStage0Months DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'RibaStage1Months') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD RibaStage1Months int NOT NULL CONSTRAINT DF_Test_Enquiries_RibaStage1Months DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'RibaStage2Months') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD RibaStage2Months int NOT NULL CONSTRAINT DF_Test_Enquiries_RibaStage2Months DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'RibaStage3Months') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD RibaStage3Months int NOT NULL CONSTRAINT DF_Test_Enquiries_RibaStage3Months DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'RibaStage4Months') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD RibaStage4Months int NOT NULL CONSTRAINT DF_Test_Enquiries_RibaStage4Months DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'RibaStage5Months') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD RibaStage5Months int NOT NULL CONSTRAINT DF_Test_Enquiries_RibaStage5Months DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'RibaStage6Months') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD RibaStage6Months int NOT NULL CONSTRAINT DF_Test_Enquiries_RibaStage6Months DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'RibaStage7Months') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD RibaStage7Months int NOT NULL CONSTRAINT DF_Test_Enquiries_RibaStage7Months DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'PreConstructionStageMonths') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD PreConstructionStageMonths int NOT NULL CONSTRAINT DF_Test_Enquiries_PreConstructionStageMonths DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ConstructionStageMonths') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ConstructionStageMonths int NOT NULL CONSTRAINT DF_Test_Enquiries_ConstructionStageMonths DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'SendInfoToAgent') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD SendInfoToAgent bit NOT NULL CONSTRAINT DF_Test_Enquiries_SendInfoToAgent DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'KeyDates') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD KeyDates nvarchar(2000) NOT NULL CONSTRAINT DF_Test_Enquiries_KeyDates DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ExpectedProcurementRoute') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ExpectedProcurementRoute nvarchar(200) NOT NULL CONSTRAINT DF_Test_Enquiries_ExpectedProcurementRoute DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'Notes') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD Notes nvarchar(max) NOT NULL CONSTRAINT DF_Test_Enquiries_Notes DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'IsReadyForQuoteReview') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD IsReadyForQuoteReview bit NOT NULL CONSTRAINT DF_Test_Enquiries_IsReadyForQuoteReview DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'EnquirySourceId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD EnquirySourceId int NOT NULL CONSTRAINT DF_Test_Enquiries_EnquirySourceId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'QuotingDeadlineDate') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD QuotingDeadlineDate date NULL;
END;

IF COL_LENGTH(N'SSop.Enquiries', N'DeclinedToQuoteDate') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD DeclinedToQuoteDate date NULL;
END;

IF COL_LENGTH(N'SSop.Enquiries', N'DeclinedToQuoteReason') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD DeclinedToQuoteReason nvarchar(4000) NOT NULL CONSTRAINT DF_Test_Enquiries_DeclinedToQuoteReason DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ExternalReference') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ExternalReference nvarchar(50) NOT NULL CONSTRAINT DF_Test_Enquiries_ExternalReference DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ProjectId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ProjectId int NOT NULL CONSTRAINT DF_Test_Enquiries_ProjectId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'IsSubjectToNDA') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD IsSubjectToNDA bit NOT NULL CONSTRAINT DF_Test_Enquiries_IsSubjectToNDA DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'DeadDate') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD DeadDate date NULL;
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ChaseDate1') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ChaseDate1 date NULL;
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ChaseDate2') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ChaseDate2 date NULL;
END;

IF COL_LENGTH(N'SSop.Enquiries', N'FinanceAccountId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD FinanceAccountId int NOT NULL CONSTRAINT DF_Test_Enquiries_FinanceAccountId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'FinanceAddressId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD FinanceAddressId int NOT NULL CONSTRAINT DF_Test_Enquiries_FinanceAddressId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'FinanceContactId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD FinanceContactId int NOT NULL CONSTRAINT DF_Test_Enquiries_FinanceContactId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'FinanceAccountName') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD FinanceAccountName nvarchar(250) NOT NULL CONSTRAINT DF_Test_Enquiries_FinanceAccountName DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'FinanceAddressNameNumber') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD FinanceAddressNameNumber nvarchar(100) NOT NULL CONSTRAINT DF_Test_Enquiries_FinanceAddressNameNumber DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'FinanceAddressLine1') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD FinanceAddressLine1 nvarchar(255) NOT NULL CONSTRAINT DF_Test_Enquiries_FinanceAddressLine1 DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'FinanceAddressLine2') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD FinanceAddressLine2 nvarchar(255) NOT NULL CONSTRAINT DF_Test_Enquiries_FinanceAddressLine2 DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'FinanceAddressLine3') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD FinanceAddressLine3 nvarchar(255) NOT NULL CONSTRAINT DF_Test_Enquiries_FinanceAddressLine3 DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'FinanceCountyId') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD FinanceCountyId int NOT NULL CONSTRAINT DF_Test_Enquiries_FinanceCountyId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'FinancePostCode') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD FinancePostCode nvarchar(30) NOT NULL CONSTRAINT DF_Test_Enquiries_FinancePostCode DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'FinanceContactDisplayName') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD FinanceContactDisplayName nvarchar(250) NOT NULL DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'FinanceContactDetailType') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD FinanceContactDetailType smallint NOT NULL DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'FinanceContactDetailTypeName') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD FinanceContactDetailTypeName nvarchar(100) NOT NULL DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'FinanceContactDetailTypeValue') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD FinanceContactDetailTypeValue nvarchar(250) NOT NULL DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'EnterNewClientDetails') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD EnterNewClientDetails bit NOT NULL CONSTRAINT DF_Test_Enquiries_EnterNewClientDetails DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'EnterNewAgentDetails') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD EnterNewAgentDetails bit NOT NULL CONSTRAINT DF_Test_Enquiries_EnterNewAgentDetails DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'EnterNewFinanceDetails') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD EnterNewFinanceDetails bit NOT NULL CONSTRAINT DF_Test_Enquiries_EnterNewFinanceDetails DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'EnterNewStructureDetails') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD EnterNewStructureDetails bit NOT NULL CONSTRAINT DF_Test_Enquiries_EntityNewStructureDetails DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'IsClientFinanceAccount') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD IsClientFinanceAccount bit NOT NULL CONSTRAINT DF_Test_Enquiries_IsClientFinanceAccount DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ContractID') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ContractID int NOT NULL CONSTRAINT DF_Test_Enquiries_ContractID DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'AgentContractID') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD AgentContractID int NOT NULL CONSTRAINT DF_Test_Enquiries_AgentContractID DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Enquiries', N'AssetJSONDetails') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD AssetJSONDetails nvarchar(500) NOT NULL CONSTRAINT DF_Test_Enquiries_AssetJSONDetails DEFAULT (N'');
END;

/*
    SSop.EnquiriesUpsert now persists the inline "enter new … details" Town fields.
    Mirrors Database/CymBuild_DB/Schema/Tables/SSop.Enquiries.sql (name, type, default).
*/
IF COL_LENGTH(N'SSop.Enquiries', N'PropertyTown') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD PropertyTown nvarchar(255) NOT NULL CONSTRAINT DF_Test_Enquiries_PropertyTown DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'ClientAddressTown') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD ClientAddressTown nvarchar(255) NOT NULL CONSTRAINT DF_Test_Enquiries_ClientAddressTown DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'AgentTown') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD AgentTown nvarchar(255) NOT NULL CONSTRAINT DF_Test_Enquiries_AgentTown DEFAULT (N'');
END;

IF COL_LENGTH(N'SSop.Enquiries', N'FinanceTown') IS NULL
BEGIN
    ALTER TABLE SSop.Enquiries ADD FinanceTown nvarchar(255) NOT NULL CONSTRAINT DF_Test_Enquiries_FinanceTown DEFAULT (N'');
END;

/*
    CYB-462: SSop.tvf_QuotesValidate reads OriginalQuoteId (superseded-revision
    lock), LegacyId and QuotingUserId (Ready-to-Send legacy exception), columns
    the earlier SSop.Quotes stubs never needed.
*/
IF COL_LENGTH(N'SSop.Quotes', N'OriginalQuoteId') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD OriginalQuoteId int NOT NULL CONSTRAINT DF_Test_Quotes_OriginalQuoteId DEFAULT (-1);
END;

IF COL_LENGTH(N'SSop.Quotes', N'LegacyId') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD LegacyId int NULL;
END;

IF COL_LENGTH(N'SSop.Quotes', N'QuotingUserId') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD QuotingUserId int NOT NULL CONSTRAINT DF_Test_Quotes_QuotingUserId DEFAULT (-1);
END;
/*
    26.4 fee-amendment approval: SJob.Job_FeeDrawdown now only counts fee amendments
    whose FeeAmendmentStatusID resolves to the zero-Guid (-1) or agreed status. The
    column comes from Migrations/Generated/Tables/SJob.FeeAmendment.alter.sql, which
    the R4 manifest does not apply, so add it here with the same -1 default and seed
    the -1 sentinel row; existing fixture amendments then keep counting as before.
*/
IF COL_LENGTH(N'SJob.FeeAmendment', N'FeeAmendmentStatusID') IS NULL
BEGIN
    ALTER TABLE SJob.FeeAmendment ADD FeeAmendmentStatusID int NOT NULL CONSTRAINT DF_Test_FeeAmendment_FeeAmendmentStatusID DEFAULT (-1);
END;

IF NOT EXISTS (SELECT 1 FROM SJob.FeeAmendmentStatus WHERE ID = -1)
BEGIN
    SET IDENTITY_INSERT SJob.FeeAmendmentStatus ON;
    INSERT INTO SJob.FeeAmendmentStatus (ID, Guid) VALUES (-1, '00000000-0000-0000-0000-000000000000');
    SET IDENTITY_INSERT SJob.FeeAmendmentStatus OFF;
END;

/*
    CYB-237: SJob.FeeAmendmentsUpsert writes the rest of the fee-amendment lifecycle
    columns, also only in Migrations/Generated/Tables/SJob.FeeAmendment.alter.sql.
    Same types and defaults as that migration.
*/
IF COL_LENGTH(N'SJob.FeeAmendment', N'AgreedStatusByUserID') IS NULL
    ALTER TABLE SJob.FeeAmendment ADD AgreedStatusByUserID int NOT NULL CONSTRAINT DF_Test_FeeAmendment_AgreedStatusByUserID DEFAULT (-1);
IF COL_LENGTH(N'SJob.FeeAmendment', N'Comments') IS NULL
    ALTER TABLE SJob.FeeAmendment ADD Comments nvarchar(max) NOT NULL CONSTRAINT DF_Test_FeeAmendment_Comments DEFAULT (N'');
IF COL_LENGTH(N'SJob.FeeAmendment', N'DateAgreed') IS NULL
    ALTER TABLE SJob.FeeAmendment ADD DateAgreed date NULL;
IF COL_LENGTH(N'SJob.FeeAmendment', N'DateReceivedRequest') IS NULL
    ALTER TABLE SJob.FeeAmendment ADD DateReceivedRequest date NOT NULL CONSTRAINT DF_Test_FeeAmendment_DateReceivedRequest DEFAULT (CONVERT(date, GETUTCDATE()));
IF COL_LENGTH(N'SJob.FeeAmendment', N'NewTotalAgreedFee') IS NULL
    ALTER TABLE SJob.FeeAmendment ADD NewTotalAgreedFee decimal(19, 2) NOT NULL CONSTRAINT DF_Test_FeeAmendment_NewTotalAgreedFee DEFAULT (0);
IF COL_LENGTH(N'SJob.FeeAmendment', N'OriginalAgreedFee') IS NULL
    ALTER TABLE SJob.FeeAmendment ADD OriginalAgreedFee decimal(19, 2) NOT NULL CONSTRAINT DF_Test_FeeAmendment_OriginalAgreedFee DEFAULT (0);
IF COL_LENGTH(N'SJob.FeeAmendment', N'RejectionReason') IS NULL
    ALTER TABLE SJob.FeeAmendment ADD RejectionReason nvarchar(max) NULL;
IF COL_LENGTH(N'SJob.FeeAmendment', N'RequestedByUserID') IS NULL
    ALTER TABLE SJob.FeeAmendment ADD RequestedByUserID int NOT NULL CONSTRAINT DF_Test_FeeAmendment_RequestedByUserID DEFAULT (-1);
IF COL_LENGTH(N'SJob.FeeAmendment', N'SentToContactID') IS NULL
    ALTER TABLE SJob.FeeAmendment ADD SentToContactID int NOT NULL CONSTRAINT DF_Test_FeeAmendment_SentToContactID DEFAULT (-1);
/*
    CYB-333 activity-based fee amendments: the "Is part of the agreed fee?" answer and the
    amendment-to-activity link. Same types and defaults as
    Scripts/CYB-333/CYB-333_ActivityFeeAmendment_DevSchema.sql.
*/
IF COL_LENGTH(N'SJob.Activities', N'IsPartOfAgreedFee') IS NULL
    ALTER TABLE SJob.Activities ADD IsPartOfAgreedFee bit NOT NULL CONSTRAINT DF_Test_Activities_IsPartOfAgreedFee DEFAULT (1);
IF COL_LENGTH(N'SJob.FeeAmendment', N'ActivityID') IS NULL
    ALTER TABLE SJob.FeeAmendment ADD ActivityID bigint NOT NULL CONSTRAINT DF_Test_FeeAmendment_ActivityID DEFAULT (-1);
/*
    CYB-461 quote/enquiry auto-expiry: SSop.Quote_CalculatedFields reads these
    SSop.Quotes columns. Defaults match the real table (ExpiryDate is NOT NULL
    there; tests always set it explicitly).
*/
IF COL_LENGTH(N'SSop.Quotes', N'ExpiryDate') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD ExpiryDate date NOT NULL CONSTRAINT DF_Test_Quotes_ExpiryDate DEFAULT (GETDATE());
END;

IF COL_LENGTH(N'SSop.Quotes', N'IsFinal') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD IsFinal bit NOT NULL CONSTRAINT DF_Test_Quotes_IsFinal DEFAULT (0);
END;

IF COL_LENGTH(N'SSop.Quotes', N'ChaseDate1') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD ChaseDate1 date NULL;
END;

IF COL_LENGTH(N'SSop.Quotes', N'ChaseDate2') IS NULL
BEGIN
    ALTER TABLE SSop.Quotes ADD ChaseDate2 date NULL;
END;
/*
    CYB-572 Request Invoice: SFin.InvoiceRequestUpsert writes isWIP/WIPReason. Both
    come from Migrations/Generated/Tables/SFin.InvoiceRequests.alter.sql, which the R4
    manifest does not apply, so add them here with the real defaults. The procedure
    resolves @PaymentStatusGuid = zero-Guid, so seed the -1 sentinel row as well.
*/
IF COL_LENGTH(N'SFin.InvoiceRequests', N'isWIP') IS NULL
BEGIN
    ALTER TABLE SFin.InvoiceRequests ADD isWIP bit NOT NULL CONSTRAINT DF_Test_InvoiceRequests_IsWIP DEFAULT (0);
END;

IF COL_LENGTH(N'SFin.InvoiceRequests', N'WIPReason') IS NULL
BEGIN
    ALTER TABLE SFin.InvoiceRequests ADD WIPReason nvarchar(max) NOT NULL CONSTRAINT DF_Test_InvoiceRequests_WIPReason DEFAULT (N'');
END;

IF NOT EXISTS (SELECT 1 FROM SFin.InvoicePaymentStatus WHERE ID = -1)
BEGIN
    SET IDENTITY_INSERT SFin.InvoicePaymentStatus ON;
    INSERT INTO SFin.InvoicePaymentStatus (ID, RowStatus, Guid) VALUES (-1, 1, '00000000-0000-0000-0000-000000000000');
    SET IDENTITY_INSERT SFin.InvoicePaymentStatus OFF;
END;
/*
    CYB-572 follow-up: SFin.StagePaymentCreateInvoice reads the Job's purchase order
    number and the finance account's code and default credit terms. Same types and
    defaults as the real tables.
*/
IF COL_LENGTH(N'SJob.Jobs', N'PurchaseOrderNumber') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD PurchaseOrderNumber nvarchar(28) NOT NULL CONSTRAINT DF_Test_Jobs_PurchaseOrderNumber DEFAULT (N'');
END;

/*
    CYB-572 unbilled activities: SJob.tvf_UnBilledActivities filters on the Job's
    sector and legacy marker. Same types and defaults as the real table.
*/
IF COL_LENGTH(N'SJob.Jobs', N'SectorId') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD SectorId int NOT NULL CONSTRAINT DF_Test_Jobs_SectorId DEFAULT (-1);
END;

IF COL_LENGTH(N'SJob.Jobs', N'LegacyID') IS NULL
BEGIN
    ALTER TABLE SJob.Jobs ADD LegacyID int NULL;
END;

IF COL_LENGTH(N'SCrm.Accounts', N'Code') IS NULL
BEGIN
    ALTER TABLE SCrm.Accounts ADD Code nvarchar(10) NOT NULL CONSTRAINT DF_Test_Accounts_Code DEFAULT (N'');
END;

IF COL_LENGTH(N'SCrm.Accounts', N'DefaultCreditTermsId') IS NULL
BEGIN
    ALTER TABLE SCrm.Accounts ADD DefaultCreditTermsId int NOT NULL CONSTRAINT DF_Test_Accounts_DefaultCreditTermsId DEFAULT (-1);
END;
/*
    CYB-576 QuoteTemplatesCreateQuote: the quote is created through the real SSop.QuotesUpsert
    and SSop.QuoteItemsUpsert. These are the columns they write (and QuotesUpsert's filing-name
    query reads) that the earlier stubs never needed. Types and defaults match the real tables.
*/
IF COL_LENGTH(N'SSop.Quotes', N'Date') IS NULL
    ALTER TABLE SSop.Quotes ADD [Date] date NOT NULL CONSTRAINT DF_Test_Quotes_Date DEFAULT (GETDATE());
IF COL_LENGTH(N'SSop.Quotes', N'RejectionReason') IS NULL
    ALTER TABLE SSop.Quotes ADD RejectionReason nvarchar(max) NOT NULL CONSTRAINT DF_Test_Quotes_RejectionReason DEFAULT (N'');
IF COL_LENGTH(N'SSop.Quotes', N'CurrentRibaStageId') IS NULL
    ALTER TABLE SSop.Quotes ADD CurrentRibaStageId int NOT NULL CONSTRAINT DF_Test_Quotes_CurrentRibaStageId DEFAULT (-1);
IF COL_LENGTH(N'SSop.Quotes', N'JobTypeId') IS NULL
    ALTER TABLE SSop.Quotes ADD JobTypeId int NULL;
IF COL_LENGTH(N'SSop.Quotes', N'DescriptionOfWorks') IS NULL
    ALTER TABLE SSop.Quotes ADD DescriptionOfWorks nvarchar(4000) NOT NULL CONSTRAINT DF_Test_Quotes_DescriptionOfWorks DEFAULT (N'');
IF COL_LENGTH(N'SSop.Quotes', N'ExclusionsAndLimitations') IS NULL
    ALTER TABLE SSop.Quotes ADD ExclusionsAndLimitations nvarchar(max) NOT NULL CONSTRAINT DF_Test_Quotes_ExclusionsAndLimitations DEFAULT (N'');
IF COL_LENGTH(N'SSop.Quotes', N'SectorId') IS NULL
    ALTER TABLE SSop.Quotes ADD SectorId int NOT NULL CONSTRAINT DF_Test_Quotes_SectorId DEFAULT (-1);
IF COL_LENGTH(N'SSop.Quotes', N'MarketId') IS NULL
    ALTER TABLE SSop.Quotes ADD MarketId int NOT NULL CONSTRAINT DF_Test_Quotes_MarketId DEFAULT (-1);
IF COL_LENGTH(N'SSop.Quotes', N'UprnId') IS NULL
    ALTER TABLE SSop.Quotes ADD UprnId int NOT NULL CONSTRAINT DF_Test_Quotes_UprnId DEFAULT (-1);
IF COL_LENGTH(N'SSop.Quotes', N'ClientAccountId') IS NULL
    ALTER TABLE SSop.Quotes ADD ClientAccountId int NOT NULL CONSTRAINT DF_Test_Quotes_ClientAccountId DEFAULT (-1);
IF COL_LENGTH(N'SSop.Quotes', N'AgentAccountId') IS NULL
    ALTER TABLE SSop.Quotes ADD AgentAccountId int NOT NULL CONSTRAINT DF_Test_Quotes_AgentAccountId DEFAULT (-1);

IF COL_LENGTH(N'SSop.QuoteItems', N'Guid') IS NULL
    ALTER TABLE SSop.QuoteItems ADD Guid uniqueidentifier NOT NULL CONSTRAINT DF_Test_QuoteItems_Guid DEFAULT (NEWID());
IF COL_LENGTH(N'SSop.QuoteItems', N'Details') IS NULL
    ALTER TABLE SSop.QuoteItems ADD Details nvarchar(2000) NOT NULL CONSTRAINT DF_Test_QuoteItems_Details DEFAULT (N'');
IF COL_LENGTH(N'SSop.QuoteItems', N'VatRate') IS NULL
    ALTER TABLE SSop.QuoteItems ADD VatRate decimal(9, 2) NOT NULL CONSTRAINT DF_Test_QuoteItems_VatRate DEFAULT (0);
IF COL_LENGTH(N'SSop.QuoteItems', N'SortOrder') IS NULL
    ALTER TABLE SSop.QuoteItems ADD SortOrder int NOT NULL CONSTRAINT DF_Test_QuoteItems_SortOrder DEFAULT (0);
IF COL_LENGTH(N'SSop.QuoteItems', N'InvoicingSchedule') IS NULL
    ALTER TABLE SSop.QuoteItems ADD InvoicingSchedule int NOT NULL CONSTRAINT DF_Test_QuoteItems_InvoicingSchedule DEFAULT (-1);

IF COL_LENGTH(N'SSop.EnquiryServices', N'StartRibaStageId') IS NULL
    ALTER TABLE SSop.EnquiryServices ADD StartRibaStageId int NOT NULL CONSTRAINT DF_Test_EnquiryServices_StartRibaStageId DEFAULT (-1);
IF COL_LENGTH(N'SSop.Quotes', N'ClientAddressId') IS NULL
    ALTER TABLE SSop.Quotes ADD [ClientAddressId] int NOT NULL CONSTRAINT DF_Test_Quotes_ClientAddressId DEFAULT (-1);
IF COL_LENGTH(N'SSop.Quotes', N'ClientContactId') IS NULL
    ALTER TABLE SSop.Quotes ADD [ClientContactId] int NOT NULL CONSTRAINT DF_Test_Quotes_ClientContactId DEFAULT (-1);
IF COL_LENGTH(N'SSop.Quotes', N'AgentAddressId') IS NULL
    ALTER TABLE SSop.Quotes ADD [AgentAddressId] int NOT NULL CONSTRAINT DF_Test_Quotes_AgentAddressId DEFAULT (-1);
IF COL_LENGTH(N'SSop.Quotes', N'AgentContactId') IS NULL
    ALTER TABLE SSop.Quotes ADD [AgentContactId] int NOT NULL CONSTRAINT DF_Test_Quotes_AgentContactId DEFAULT (-1);

/*
    CYB-580: columns read by SFin.tvf_InvoiceAutomation_Phase3Detections so the trigger-instance
    invoice automation (SFin.InvoiceAutomation_CreateInvoiceRequests_FromTriggerInstances) can run.
    Defaults mirror the canonical tables (InvoiceProcessingMode 1 is manual, i.e. blocked).
*/
IF COL_LENGTH(N'SJob.Jobs', N'InvoiceProcessingMode') IS NULL
    ALTER TABLE SJob.Jobs ADD InvoiceProcessingMode tinyint NOT NULL CONSTRAINT DF_Test_Jobs_InvoiceProcessingMode DEFAULT (1);
IF COL_LENGTH(N'SJob.Jobs', N'CannotBeInvoiced') IS NULL
    ALTER TABLE SJob.Jobs ADD CannotBeInvoiced bit NOT NULL CONSTRAINT DF_Test_Jobs_CannotBeInvoiced DEFAULT (0);
IF COL_LENGTH(N'SCrm.Accounts', N'AccountStatusID') IS NULL
    ALTER TABLE SCrm.Accounts ADD AccountStatusID int NOT NULL CONSTRAINT DF_Test_Accounts_AccountStatusID DEFAULT (-1);
