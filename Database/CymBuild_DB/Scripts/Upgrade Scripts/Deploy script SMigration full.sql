
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO
/* ================================================================================================
   FULL RESET OF SMigration ONBOARDING FRAMEWORK
   Drops procedures first, then tables, so the script can recreate everything from fresh.
   ================================================================================================ */

IF EXISTS
(
    SELECT 1
    FROM sys.schemas
    WHERE name = N'SMigration'
)
BEGIN
    /* ------------------------------------------------------------------------
       Drop procedures
       ------------------------------------------------------------------------ */
    IF OBJECT_ID(N'SMigration.OnboardingImport_Apply', N'P') IS NOT NULL
        DROP PROCEDURE SMigration.OnboardingImport_Apply;

    IF OBJECT_ID(N'SMigration.OnboardingReport', N'P') IS NOT NULL
        DROP PROCEDURE SMigration.OnboardingReport;

    IF OBJECT_ID(N'SMigration.OnboardingValidate', N'P') IS NOT NULL
        DROP PROCEDURE SMigration.OnboardingValidate;

    IF OBJECT_ID(N'SMigration.OnboardingStage_LoadFromSource', N'P') IS NOT NULL
        DROP PROCEDURE SMigration.OnboardingStage_LoadFromSource;

    IF OBJECT_ID(N'SMigration.OnboardingStage_Reset', N'P') IS NOT NULL
        DROP PROCEDURE SMigration.OnboardingStage_Reset;

    IF OBJECT_ID(N'SMigration.OnboardingLog_Add', N'P') IS NOT NULL
        DROP PROCEDURE SMigration.OnboardingLog_Add;

    /* ------------------------------------------------------------------------
       Drop tables in reverse dependency order
       ------------------------------------------------------------------------ */
    IF OBJECT_ID(N'SMigration.Onboarding_ProductJobActivities', N'U') IS NOT NULL
        DROP TABLE SMigration.Onboarding_ProductJobActivities;

    IF OBJECT_ID(N'SMigration.Onboarding_Products', N'U') IS NOT NULL
        DROP TABLE SMigration.Onboarding_Products;

    IF OBJECT_ID(N'SMigration.Onboarding_JobTypeMilestoneTemplates', N'U') IS NOT NULL
        DROP TABLE SMigration.Onboarding_JobTypeMilestoneTemplates;

    IF OBJECT_ID(N'SMigration.Onboarding_JobTypeActivityTypes', N'U') IS NOT NULL
        DROP TABLE SMigration.Onboarding_JobTypeActivityTypes;

    IF OBJECT_ID(N'SMigration.Onboarding_MilestoneTypes', N'U') IS NOT NULL
        DROP TABLE SMigration.Onboarding_MilestoneTypes;

    IF OBJECT_ID(N'SMigration.Onboarding_ActivityTypes', N'U') IS NOT NULL
        DROP TABLE SMigration.Onboarding_ActivityTypes;

    IF OBJECT_ID(N'SMigration.Onboarding_JobTypes', N'U') IS NOT NULL
        DROP TABLE SMigration.Onboarding_JobTypes;

    IF OBJECT_ID(N'SMigration.Onboarding_WorkflowStatusNotificationGroups', N'U') IS NOT NULL
        DROP TABLE SMigration.Onboarding_WorkflowStatusNotificationGroups;

    IF OBJECT_ID(N'SMigration.Onboarding_UserGroups', N'U') IS NOT NULL
        DROP TABLE SMigration.Onboarding_UserGroups;

    IF OBJECT_ID(N'SMigration.Onboarding_Identities', N'U') IS NOT NULL
        DROP TABLE SMigration.Onboarding_Identities;

    IF OBJECT_ID(N'SMigration.Onboarding_Contacts', N'U') IS NOT NULL
        DROP TABLE SMigration.Onboarding_Contacts;

    IF OBJECT_ID(N'SMigration.Onboarding_Addresses', N'U') IS NOT NULL
        DROP TABLE SMigration.Onboarding_Addresses;

    IF OBJECT_ID(N'SMigration.Onboarding_OrganisationalUnits', N'U') IS NOT NULL
        DROP TABLE SMigration.Onboarding_OrganisationalUnits;

    IF OBJECT_ID(N'SMigration.Onboarding_Groups', N'U') IS NOT NULL
        DROP TABLE SMigration.Onboarding_Groups;

    IF OBJECT_ID(N'SMigration.Onboarding_ExecutionLog', N'U') IS NOT NULL
        DROP TABLE SMigration.Onboarding_ExecutionLog;

    IF OBJECT_ID(N'SMigration.Onboarding_ValidationIssues', N'U') IS NOT NULL
        DROP TABLE SMigration.Onboarding_ValidationIssues;

    IF OBJECT_ID(N'SMigration.Onboarding_Run', N'U') IS NOT NULL
        DROP TABLE SMigration.Onboarding_Run;
END
GO

/*************************************************************************************************
CymBuild Onboarding Promotion Framework (verified against Database.zip extract on 2026-04-08)

VERIFIED TABLE SHAPES USED
--------------------------
SCore.Groups
SCore.OrganisationalUnits
SCore.Identities
SCore.UserGroups
SCore.Workflow
SCore.WorkflowStatusNotificationGroups
SCrm.Addresses
SCrm.Contacts
SJob.JobTypes
SJob.ActivityTypes
SJob.MilestoneTypes
SJob.JobTypeActivityTypes
SJob.JobTypeMilestoneTemplates
SJob.ProductJobActivities
SProd.Products

IMPORTANT VERIFIED DIFFERENCES VS EARLIER DRAFT
-----------------------------------------------
1) SJob.ActivityTypes has NO OrganisationalUnitID column.
2) SJob.MilestoneTypes has NO OrganisationalUnitID / Description column.
   It uses:
      Code, Name, IsActive, IsInvoiceTrigger, IsReviewRequired, HelpText,
      HasQuotedHours, HasDescription, HasReference, IsCompulsory,
      IncludeStart, IncludeSchedule, IncludeDueDate, HasExternalSubmission
3) SProd.Products has:
      Code, Description, CreatedJobType, NeverConsolidate, RibaStageId
   It does NOT have Name or IsActive.
4) SJob.JobTypeActivityTypes has only:
      JobTypeID, ActivityTypeID
5) SJob.JobTypeMilestoneTemplates has:
      JobTypeID, MilestoneTypeID, Description, SortOrder
6) SJob.ProductJobActivities has:
      ProductId, JobTypeActivityTypeId, ActivityTitle,
      OffsetDays, OffsetWeeks, OffsetMonths,
      JobTypeMilestoneTemplateId, PercentageOfProductValue

SCOPE / DESIGN
--------------
This framework stages a business-unit onboarding package from a source DB (normally UAT)
into SMigration staging tables, validates dependencies, and imports into the current target DB
while preserving GUID identity and resolving all FK IDs in the target.

INCLUDED ENTITY SET
-------------------
Core onboarding package:
- Groups
- OrganisationalUnits
- Addresses (referenced by OU / contacts)
- Contacts (referenced by identities / OU)
- Identities
- UserGroups
- WorkflowStatusNotificationGroups
- JobTypes
- ActivityTypes
- MilestoneTypes
- JobTypeActivityTypes
- JobTypeMilestoneTemplates
- Products
- ProductJobActivities

OUT-OF-SCOPE / EXPECTED TO ALREADY EXIST IN TARGET
--------------------------------------------------
The framework VALIDATES but does not create:
- SCrm.Accounts
- SCrm.ContactTitles
- SCrm.ContactPositions
- SCrm.Counties
- SCrm.Countries
- SJob.RibaStages
- any higher-level parent OU above the staged subtree if not included in the source selection

GENERAL RULES
-------------
- GUIDs are the cross-environment identity
- IDs are environment-local only
- source IDs are never copied directly
- rowversion/timestamp columns are ignored
- DataObjects are ensured through SCore.UpsertDataObject before inserts
- preview mode performs validation/reporting with no data changes

How to run it
____________________________________________________________________________
Step A — load from source

Run this in the target database we want to import into.

Use the source database name and the business unit group guid from UAT.
____________________________________________________________________________

DECLARE @RunGuid UNIQUEIDENTIFIER = NEWID();

EXEC SMigration.OnboardingStage_LoadFromSource
    @SourceDatabase = N'CymBuild_Dev',
    @BusinessUnitGroupGuid = '315CF5D4-37EB-4966-AB77-4CCAB627A613', -- example Fire Engineering
    @RunGuid = @RunGuid,
    @Notes = N'Initial onboarding promotion from UAT';

SELECT @RunGuid AS RunGuid;

----------------------------------------------------------------------------
Preview mode:
      EXEC SMigration.OnboardingImport_Apply @RunGuid = ..., @PreviewOnly = 1;
   validates and reports, but does not change data.

____________________________________________________________________________

Step B — validate
____________________________________________________________________________
EXEC SMigration.OnboardingValidate
    @RunGuid = 'PUT-RUN-GUID-HERE';

SELECT *
FROM SMigration.Onboarding_ValidationIssues
WHERE RunGuid = 'PUT-RUN-GUID-HERE'
ORDER BY ID;
____________________________________________________________________________

Step C — import
____________________________________________________________________________
EXEC SMigration.OnboardingImport_Apply
    @RunGuid = 'PUT-RUN-GUID-HERE',
    @AllowWarnings = 1;

____________________________________________________________________________

*************************************************************************************************/

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'SMigration')
BEGIN
    EXEC(N'CREATE SCHEMA SMigration AUTHORIZATION dbo;');
END
GO

/* ================================================================================================
   Header / log / issues
   ================================================================================================ */
IF OBJECT_ID(N'SMigration.Onboarding_Run', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_Run
    (
        RunGuid                         UNIQUEIDENTIFIER NOT NULL
            CONSTRAINT PK_SMigration_Onboarding_Run PRIMARY KEY,
        CreatedUtc                      DATETIME2(3)     NOT NULL
            CONSTRAINT DF_SMigration_Onboarding_Run_CreatedUtc DEFAULT (SYSUTCDATETIME()),
        SourceDatabase                  SYSNAME          NOT NULL,
        SourceBusinessUnitGroupGuid     UNIQUEIDENTIFIER NOT NULL,
        SourceBusinessUnitOrganisationalUnitGuid UNIQUEIDENTIFIER NULL,
        Notes                           NVARCHAR(1000)   NOT NULL
            CONSTRAINT DF_SMigration_Onboarding_Run_Notes DEFAULT (N''),
        CreatedBy                       NVARCHAR(250)    NOT NULL
            CONSTRAINT DF_SMigration_Onboarding_Run_CreatedBy DEFAULT (SUSER_SNAME())
    );
END
GO

IF OBJECT_ID(N'SMigration.Onboarding_ValidationIssues', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_ValidationIssues
    (
        ID                  BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_SMigration_Onboarding_ValidationIssues PRIMARY KEY,
        RunGuid             UNIQUEIDENTIFIER     NOT NULL,
        EntityName          NVARCHAR(200)        NOT NULL,
        StageTable          NVARCHAR(200)        NOT NULL,
        StageGuid           UNIQUEIDENTIFIER     NULL,
        Severity            NVARCHAR(20)         NOT NULL,
        IssueCode           NVARCHAR(100)        NOT NULL,
        IssueMessage        NVARCHAR(2000)       NOT NULL,
        CreatedUtc          DATETIME2(3)         NOT NULL
            CONSTRAINT DF_SMigration_Onboarding_ValidationIssues_CreatedUtc DEFAULT (SYSUTCDATETIME())
    );

    CREATE INDEX IX_SMigration_Onboarding_ValidationIssues_RunGuid
        ON SMigration.Onboarding_ValidationIssues (RunGuid, Severity, EntityName, IssueCode);
END
GO

IF OBJECT_ID(N'SMigration.Onboarding_ExecutionLog', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_ExecutionLog
    (
        ID                  BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_SMigration_Onboarding_ExecutionLog PRIMARY KEY,
        RunGuid             UNIQUEIDENTIFIER     NOT NULL,
        StepName            NVARCHAR(200)        NOT NULL,
        EntityName          NVARCHAR(200)        NOT NULL,
        ActionName          NVARCHAR(50)         NOT NULL,
        AffectedCount       INT                  NOT NULL
            CONSTRAINT DF_SMigration_Onboarding_ExecutionLog_AffectedCount DEFAULT (0),
        Details             NVARCHAR(2000)       NOT NULL
            CONSTRAINT DF_SMigration_Onboarding_ExecutionLog_Details DEFAULT (N''),
        LoggedUtc           DATETIME2(3)         NOT NULL
            CONSTRAINT DF_SMigration_Onboarding_ExecutionLog_LoggedUtc DEFAULT (SYSUTCDATETIME())
    );

    CREATE INDEX IX_SMigration_Onboarding_ExecutionLog_RunGuid
        ON SMigration.Onboarding_ExecutionLog (RunGuid, StepName, EntityName, ActionName);
END
GO

/* ================================================================================================
   Stage tables
   ================================================================================================ */
IF OBJECT_ID(N'SMigration.Onboarding_Groups', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_Groups
    (
        RunGuid             UNIQUEIDENTIFIER NOT NULL,
        GroupGuid           UNIQUEIDENTIFIER NOT NULL,
        RowStatus           TINYINT          NOT NULL,
        DirectoryId         NVARCHAR(100)    NOT NULL,
        Code                NVARCHAR(30)     NOT NULL,
        Name                NVARCHAR(250)    NOT NULL,
        Source              NVARCHAR(250)    NOT NULL,
        IsBusinessUnitGroup BIT              NOT NULL,
        CONSTRAINT PK_SMigration_Onboarding_Groups PRIMARY KEY CLUSTERED (RunGuid, GroupGuid)
    );
END
GO

IF OBJECT_ID(N'SMigration.Onboarding_OrganisationalUnits', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_OrganisationalUnits
    (
        RunGuid                     UNIQUEIDENTIFIER NOT NULL,
        OrganisationalUnitGuid      UNIQUEIDENTIFIER NOT NULL,
        RowStatus                   TINYINT          NOT NULL,
        Name                        NVARCHAR(250)    NOT NULL,
        ParentOrganisationalUnitGuid UNIQUEIDENTIFIER NULL,
        AddressGuid                 UNIQUEIDENTIFIER NOT NULL,
        ContactGuid                 UNIQUEIDENTIFIER NOT NULL,
        OfficialAddressGuid         UNIQUEIDENTIFIER NOT NULL,
        OfficialContactGuid         UNIQUEIDENTIFIER NOT NULL,
        DepartmentPrefix            NVARCHAR(10)     NOT NULL,
        CostCentreCode              NVARCHAR(50)     NOT NULL,
        DefaultSecurityGroupGuid    UNIQUEIDENTIFIER NOT NULL,
        QuoteThreshold              DECIMAL(19,2)    NULL,
        OrgLevel                    INT              NULL,
        CONSTRAINT PK_SMigration_Onboarding_OrganisationalUnits PRIMARY KEY CLUSTERED (RunGuid, OrganisationalUnitGuid)
    );
END
GO

IF OBJECT_ID(N'SMigration.Onboarding_Addresses', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_Addresses
    (
        RunGuid                 UNIQUEIDENTIFIER NOT NULL,
        AddressGuid             UNIQUEIDENTIFIER NOT NULL,
        RowStatus               TINYINT          NOT NULL,
        AddressNumber           INT              NOT NULL,
        Name                    NVARCHAR(100)    NOT NULL,
        Number                  NVARCHAR(50)     NOT NULL,
        AddressLine1            NVARCHAR(255)    NOT NULL,
        AddressLine2            NVARCHAR(255)    NOT NULL,
        AddressLine3            NVARCHAR(255)    NOT NULL,
        Town                    NVARCHAR(255)    NOT NULL,
        CountyGuid              UNIQUEIDENTIFIER NULL,
        Postcode                NVARCHAR(50)     NOT NULL,
        CountryGuid             UNIQUEIDENTIFIER NULL,
        LegacySystemID          INT              NOT NULL,
        CONSTRAINT PK_SMigration_Onboarding_Addresses PRIMARY KEY CLUSTERED (RunGuid, AddressGuid)
    );
END
GO

IF OBJECT_ID(N'SMigration.Onboarding_Contacts', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_Contacts
    (
        RunGuid                 UNIQUEIDENTIFIER NOT NULL,
        ContactGuid             UNIQUEIDENTIFIER NOT NULL,
        RowStatus               TINYINT          NOT NULL,
        PrimaryAccountGuid      UNIQUEIDENTIFIER NULL,
        PrimaryAddressGuid      UNIQUEIDENTIFIER NOT NULL,
        FirstName               NVARCHAR(250)    NOT NULL,
        Initials                NVARCHAR(10)     NOT NULL,
        Surname                 NVARCHAR(250)    NOT NULL,
        PostNominals            NVARCHAR(250)    NOT NULL,
        TitleGuid               UNIQUEIDENTIFIER NULL,
        DisplayName             NVARCHAR(250)    NOT NULL,
        IsPerson                BIT              NOT NULL,
        PositionGuid            UNIQUEIDENTIFIER NULL,
        LegacySystemID          INT              NOT NULL,
        CONSTRAINT PK_SMigration_Onboarding_Contacts PRIMARY KEY CLUSTERED (RunGuid, ContactGuid)
    );
END
GO

IF OBJECT_ID(N'SMigration.Onboarding_Identities', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_Identities
    (
        RunGuid                 UNIQUEIDENTIFIER NOT NULL,
        IdentityGuid            UNIQUEIDENTIFIER NOT NULL,
        RowStatus               TINYINT          NOT NULL,
        FullName                NVARCHAR(250)    NOT NULL,
        EmailAddress            NVARCHAR(150)    NOT NULL,
        UserGuid                UNIQUEIDENTIFIER NOT NULL,
        JobTitle                NVARCHAR(50)     NOT NULL,
        OrganisationalUnitGuid  UNIQUEIDENTIFIER NOT NULL,
        IsActive                BIT              NOT NULL,
        ContactGuid             UNIQUEIDENTIFIER NOT NULL,
        BillableRate            DECIMAL(19,2)    NOT NULL,
        Signature               VARBINARY(MAX)   NOT NULL,
        CONSTRAINT PK_SMigration_Onboarding_Identities PRIMARY KEY CLUSTERED (RunGuid, IdentityGuid)
    );
END
GO

IF OBJECT_ID(N'SMigration.Onboarding_UserGroups', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_UserGroups
    (
        RunGuid             UNIQUEIDENTIFIER NOT NULL,
        UserGroupGuid       UNIQUEIDENTIFIER NOT NULL,
        RowStatus           TINYINT          NOT NULL,
        IdentityGuid        UNIQUEIDENTIFIER NOT NULL,
        GroupGuid           UNIQUEIDENTIFIER NOT NULL,
        CONSTRAINT PK_SMigration_Onboarding_UserGroups PRIMARY KEY CLUSTERED (RunGuid, UserGroupGuid)
    );
END
GO

IF OBJECT_ID(N'SMigration.Onboarding_WorkflowStatusNotificationGroups', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_WorkflowStatusNotificationGroups
    (
        RunGuid                         UNIQUEIDENTIFIER NOT NULL,
        WorkflowNotificationGroupGuid   UNIQUEIDENTIFIER NOT NULL,
        RowStatus                       TINYINT          NOT NULL,
        WorkflowGuid                    UNIQUEIDENTIFIER NOT NULL,
        WorkflowStatusGuid              UNIQUEIDENTIFIER NOT NULL,
        GroupGuid                       UNIQUEIDENTIFIER NOT NULL,
        CanAction                       BIT              NOT NULL,
        CONSTRAINT PK_SMigration_Onboarding_WSNG PRIMARY KEY CLUSTERED (RunGuid, WorkflowNotificationGroupGuid)
    );
END
GO

IF OBJECT_ID(N'SMigration.Onboarding_JobTypes', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_JobTypes
    (
        RunGuid                 UNIQUEIDENTIFIER NOT NULL,
        JobTypeGuid             UNIQUEIDENTIFIER NOT NULL,
        RowStatus               TINYINT          NOT NULL,
        Name                    NVARCHAR(50)     NOT NULL,
        IsActive                BIT              NOT NULL,
        SequenceID              INT              NOT NULL,
        UseTimeSheets           BIT              NOT NULL,
        UsePlanChecks           BIT              NOT NULL,
        OrganisationalUnitGuid  UNIQUEIDENTIFIER NOT NULL,
        CONSTRAINT PK_SMigration_Onboarding_JobTypes PRIMARY KEY CLUSTERED (RunGuid, JobTypeGuid)
    );
END
GO

IF OBJECT_ID(N'SMigration.Onboarding_ActivityTypes', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_ActivityTypes
    (
        RunGuid                 UNIQUEIDENTIFIER NOT NULL,
        ActivityTypeGuid        UNIQUEIDENTIFIER NOT NULL,
        RowStatus               TINYINT          NOT NULL,
        Name                    NVARCHAR(150)    NOT NULL,
        IsActive                BIT              NOT NULL,
        SortOrder               INT              NOT NULL,
        IsFeeTrigger            BIT              NOT NULL,
        IsLiveTrigger           BIT              NOT NULL,
        IsAdmin                 BIT              NOT NULL,
        IsScheduleItem          BIT              NOT NULL,
        Colour                  NVARCHAR(6)      NOT NULL,
        IsMeeting               BIT              NOT NULL,
        IsSiteVisit             BIT              NOT NULL,
        IsBillable              BIT              NOT NULL,
        IsCommencementTrigger   BIT              NOT NULL,
        CONSTRAINT PK_SMigration_Onboarding_ActivityTypes PRIMARY KEY CLUSTERED (RunGuid, ActivityTypeGuid)
    );
END
GO

IF OBJECT_ID(N'SMigration.Onboarding_MilestoneTypes', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_MilestoneTypes
    (
        RunGuid                 UNIQUEIDENTIFIER NOT NULL,
        MilestoneTypeGuid       UNIQUEIDENTIFIER NOT NULL,
        RowStatus               TINYINT          NOT NULL,
        Code                    NVARCHAR(20)     NOT NULL,
        Name                    NVARCHAR(250)    NOT NULL,
        IsActive                BIT              NOT NULL,
        IsInvoiceTrigger        BIT              NOT NULL,
        IsReviewRequired        BIT              NOT NULL,
        HelpText                NVARCHAR(2000)   NOT NULL,
        HasQuotedHours          BIT              NOT NULL,
        HasDescription          BIT              NOT NULL,
        HasReference            BIT              NOT NULL,
        IsCompulsory            BIT              NOT NULL,
        IncludeStart            BIT              NOT NULL,
        IncludeSchedule         BIT              NOT NULL,
        IncludeDueDate          BIT              NOT NULL,
        HasExternalSubmission   BIT              NOT NULL,
        CONSTRAINT PK_SMigration_Onboarding_MilestoneTypes PRIMARY KEY CLUSTERED (RunGuid, MilestoneTypeGuid)
    );
END
GO

IF OBJECT_ID(N'SMigration.Onboarding_JobTypeActivityTypes', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_JobTypeActivityTypes
    (
        RunGuid                 UNIQUEIDENTIFIER NOT NULL,
        JobTypeActivityTypeGuid UNIQUEIDENTIFIER NOT NULL,
        RowStatus               TINYINT          NOT NULL,
        JobTypeGuid             UNIQUEIDENTIFIER NOT NULL,
        ActivityTypeGuid        UNIQUEIDENTIFIER NOT NULL,
        CONSTRAINT PK_SMigration_Onboarding_JTAT PRIMARY KEY CLUSTERED (RunGuid, JobTypeActivityTypeGuid)
    );
END
GO

IF OBJECT_ID(N'SMigration.Onboarding_JobTypeMilestoneTemplates', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_JobTypeMilestoneTemplates
    (
        RunGuid                         UNIQUEIDENTIFIER NOT NULL,
        JobTypeMilestoneTemplateGuid    UNIQUEIDENTIFIER NOT NULL,
        RowStatus                       TINYINT          NOT NULL,
        JobTypeGuid                     UNIQUEIDENTIFIER NOT NULL,
        MilestoneTypeGuid               UNIQUEIDENTIFIER NOT NULL,
        Description                     NVARCHAR(500)    NOT NULL,
        SortOrder                       INT              NOT NULL,
        CONSTRAINT PK_SMigration_Onboarding_JTMT PRIMARY KEY CLUSTERED (RunGuid, JobTypeMilestoneTemplateGuid)
    );
END
GO

IF OBJECT_ID(N'SMigration.Onboarding_Products', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_Products
    (
        RunGuid                 UNIQUEIDENTIFIER NOT NULL,
        ProductGuid             UNIQUEIDENTIFIER NOT NULL,
        RowStatus               TINYINT          NOT NULL,
        Code                    NVARCHAR(30)     NOT NULL,
        Description             NVARCHAR(2000)   NOT NULL,
        CreatedJobTypeGuid      UNIQUEIDENTIFIER NOT NULL,
        NeverConsolidate        BIT              NOT NULL,
        RibaStageGuid           UNIQUEIDENTIFIER NULL,
        CONSTRAINT PK_SMigration_Onboarding_Products PRIMARY KEY CLUSTERED (RunGuid, ProductGuid)
    );
END
GO

IF OBJECT_ID(N'SMigration.Onboarding_ProductJobActivities', N'U') IS NULL
BEGIN
    CREATE TABLE SMigration.Onboarding_ProductJobActivities
    (
        RunGuid                         UNIQUEIDENTIFIER NOT NULL,
        ProductJobActivityGuid          UNIQUEIDENTIFIER NOT NULL,
        RowStatus                       TINYINT          NOT NULL,
        ProductGuid                     UNIQUEIDENTIFIER NOT NULL,
        JobTypeActivityTypeGuid         UNIQUEIDENTIFIER NOT NULL,
        ActivityTitle                   NVARCHAR(250)    NOT NULL,
        OffsetDays                      INT              NOT NULL,
        OffsetWeeks                     INT              NOT NULL,
        OffsetMonths                    INT              NOT NULL,
        JobTypeMilestoneTemplateGuid    UNIQUEIDENTIFIER NULL,
        PercentageOfProductValue        DECIMAL(5,2)     NOT NULL,
        CONSTRAINT PK_SMigration_Onboarding_PJA PRIMARY KEY CLUSTERED (RunGuid, ProductJobActivityGuid)
    );
END
GO

/* ================================================================================================
   Helper logger
   ================================================================================================ */
CREATE OR ALTER PROCEDURE SMigration.OnboardingLog_Add
    @RunGuid         UNIQUEIDENTIFIER,
    @StepName        NVARCHAR(200),
    @EntityName      NVARCHAR(200),
    @ActionName      NVARCHAR(50),
    @AffectedCount   INT = 0,
    @Details         NVARCHAR(2000) = N''
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO SMigration.Onboarding_ExecutionLog
    (
        RunGuid, StepName, EntityName, ActionName, AffectedCount, Details
    )
    VALUES
    (
        @RunGuid, @StepName, @EntityName, @ActionName, @AffectedCount, @Details
    );
END
GO

/* ================================================================================================
   Reset
   ================================================================================================ */
CREATE OR ALTER PROCEDURE SMigration.OnboardingStage_Reset
    @RunGuid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DELETE FROM SMigration.Onboarding_ValidationIssues WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_ExecutionLog WHERE RunGuid = @RunGuid;

    DELETE FROM SMigration.Onboarding_ProductJobActivities WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_Products WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_JobTypeMilestoneTemplates WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_JobTypeActivityTypes WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_MilestoneTypes WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_ActivityTypes WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_JobTypes WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_WorkflowStatusNotificationGroups WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_UserGroups WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_Identities WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_Contacts WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_Addresses WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_OrganisationalUnits WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_Groups WHERE RunGuid = @RunGuid;
    DELETE FROM SMigration.Onboarding_Run WHERE RunGuid = @RunGuid;
END
GO

/* ================================================================================================
   Load stage from source DB
   ================================================================================================ */
CREATE OR ALTER PROCEDURE SMigration.OnboardingStage_LoadFromSource
    @SourceDatabase SYSNAME,
    @BusinessUnitGroupGuid UNIQUEIDENTIFIER,
    @RunGuid UNIQUEIDENTIFIER = NULL,
    @Notes NVARCHAR(1000) = N''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RunGuid IS NULL
        SET @RunGuid = NEWID();

    EXEC SMigration.OnboardingStage_Reset @RunGuid = @RunGuid;

    DECLARE @SourceBusinessUnitOrganisationalUnitGuid UNIQUEIDENTIFIER = NULL;
    DECLARE @sql NVARCHAR(MAX);

    /* find source BU OU by matching default security group first, then name */
    SET @sql = N'
    SELECT TOP (1)
        @OutGuid = ou.Guid
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits ou
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
        ON g.ID = ou.DefaultSecurityGroupId
    WHERE g.Guid = @BusinessUnitGroupGuid
    ORDER BY ou.ID;';

    EXEC sp_executesql
        @sql,
        N'@BusinessUnitGroupGuid UNIQUEIDENTIFIER, @OutGuid UNIQUEIDENTIFIER OUTPUT',
        @BusinessUnitGroupGuid = @BusinessUnitGroupGuid,
        @OutGuid = @SourceBusinessUnitOrganisationalUnitGuid OUTPUT;

    IF @SourceBusinessUnitOrganisationalUnitGuid IS NULL
    BEGIN
        SET @sql = N'
        SELECT TOP (1)
            @OutGuid = ou.Guid
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits ou
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
            ON g.Guid = @BusinessUnitGroupGuid
        WHERE ou.Name = g.Name
        ORDER BY ou.ID;';

        EXEC sp_executesql
            @sql,
            N'@BusinessUnitGroupGuid UNIQUEIDENTIFIER, @OutGuid UNIQUEIDENTIFIER OUTPUT',
            @BusinessUnitGroupGuid = @BusinessUnitGroupGuid,
            @OutGuid = @SourceBusinessUnitOrganisationalUnitGuid OUTPUT;
    END

    INSERT INTO SMigration.Onboarding_Run
    (
        RunGuid, SourceDatabase, SourceBusinessUnitGroupGuid, SourceBusinessUnitOrganisationalUnitGuid, Notes
    )
    VALUES
    (
        @RunGuid, @SourceDatabase, @BusinessUnitGroupGuid, @SourceBusinessUnitOrganisationalUnitGuid, @Notes
    );

    IF @SourceBusinessUnitOrganisationalUnitGuid IS NULL
    BEGIN
        INSERT INTO SMigration.Onboarding_ValidationIssues
        (
            RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage
        )
        VALUES
        (
            @RunGuid, N'OrganisationalUnit', N'Stage', NULL, N'Error', N'SOURCE_BU_OU_NOT_FOUND',
            N'Unable to resolve the source Business Unit OrganisationalUnit from the supplied BusinessUnitGroupGuid.'
        );

        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Stage', N'All', N'Failed', 0, N'Could not resolve source business unit OU';
        RETURN;
    END

    SET @sql = N'
    DECLARE @BusinessUnitOrgNode hierarchyid;

    SELECT @BusinessUnitOrgNode = ou.OrgNode
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits ou
    WHERE ou.Guid = @BusinessUnitOuGuid;

    ;WITH StageOU AS
    (
        SELECT
            ou.ID,
            ou.Guid,
            ou.RowStatus,
            ou.Name,
            parent.Guid AS ParentGuid,
            a.Guid AS AddressGuid,
            c.Guid AS ContactGuid,
            oa.Guid AS OfficialAddressGuid,
            oc.Guid AS OfficialContactGuid,
            ou.DepartmentPrefix,
            ou.CostCentreCode,
            g.Guid AS DefaultSecurityGroupGuid,
            ou.QuoteThreshold,
            ou.OrgNode.GetLevel() AS OrgLevel
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits ou
        LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits parent
            ON parent.ID = ou.ParentID
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Addresses a
            ON a.ID = ou.AddressId
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts c
            ON c.ID = ou.ContactId
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Addresses oa
            ON oa.ID = ou.OfficialAddressId
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts oc
            ON oc.ID = ou.OfficialContactId
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
            ON g.ID = ou.DefaultSecurityGroupId
        WHERE ou.RowStatus NOT IN (0,254)
          AND ou.OrgNode.IsDescendantOf(@BusinessUnitOrgNode) = 1
    ),
    StageIdentityIds AS
    (
        SELECT DISTINCT i.ID
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Identities i
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups ug
            ON ug.IdentityID = i.ID
           AND ug.RowStatus NOT IN (0,254)
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
            ON g.ID = ug.GroupID
           AND g.RowStatus NOT IN (0,254)
        WHERE i.RowStatus NOT IN (0,254)
          AND g.Guid = @BusinessUnitGroupGuid
    ),
    RelevantGroupIds AS
    (
        SELECT g.ID
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
        WHERE g.Guid = @BusinessUnitGroupGuid

        UNION

        SELECT DISTINCT g.ID
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups ug
            ON ug.GroupID = g.ID
        INNER JOIN StageIdentityIds si
            ON si.ID = ug.IdentityID
        WHERE g.RowStatus NOT IN (0,254)
          AND ug.RowStatus NOT IN (0,254)

        UNION

        SELECT DISTINCT g.ID
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
        INNER JOIN StageOU sou
            ON sou.DefaultSecurityGroupGuid = g.Guid
    ),
    RelevantAddressIds AS
    (
        SELECT a.ID
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Addresses a
        INNER JOIN StageOU sou
            ON sou.AddressGuid = a.Guid
            OR sou.OfficialAddressGuid = a.Guid

        UNION

        SELECT DISTINCT c.PrimaryAddressID
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts c
        INNER JOIN StageIdentityIds si
            ON si.ID = c.ID
        WHERE c.PrimaryAddressID > 0

        UNION

        SELECT DISTINCT c.PrimaryAddressID
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts c
        INNER JOIN StageOU sou
            ON sou.ContactGuid = c.Guid
            OR sou.OfficialContactGuid = c.Guid
        WHERE c.PrimaryAddressID > 0
    ),
    RelevantContactIds AS
    (
        SELECT c.ID
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts c
        INNER JOIN StageOU sou
            ON sou.ContactGuid = c.Guid
            OR sou.OfficialContactGuid = c.Guid

        UNION

        SELECT DISTINCT i.ContactId
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Identities i
        INNER JOIN StageIdentityIds si
            ON si.ID = i.ID
        WHERE i.ContactId > 0
    ),
    RelevantJobTypeIds AS
    (
        SELECT jt.ID
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes jt
        INNER JOIN StageOU sou
            ON sou.Guid = jt.OrganisationalUnitID -- intentional impossible line to protect parser
    )
    SELECT 1;
    ';

    -- easier: run staged inserts as separate dynamic SQL blocks

    /* Groups */
    SET @sql = N'
    ;WITH StageIdentityIds AS
    (
        SELECT DISTINCT i.ID
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Identities i
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups ug
            ON ug.IdentityID = i.ID AND ug.RowStatus NOT IN (0,254)
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
            ON g.ID = ug.GroupID AND g.RowStatus NOT IN (0,254)
        WHERE i.RowStatus NOT IN (0,254)
          AND g.Guid = @BusinessUnitGroupGuid
    ),
    StageOU AS
    (
        SELECT ou.ID, g.ID AS DefaultGroupID
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits ou
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g ON g.ID = ou.DefaultSecurityGroupId
        CROSS JOIN (SELECT OrgNode FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits WHERE Guid = @BusinessUnitOuGuid) b
        WHERE ou.RowStatus NOT IN (0,254)
          AND ou.OrgNode.IsDescendantOf(b.OrgNode) = 1
    ),
    RelevantGroups AS
    (
        SELECT g.*
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
        WHERE g.Guid = @BusinessUnitGroupGuid

        UNION

        SELECT DISTINCT g.*
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups ug ON ug.GroupID = g.ID
        INNER JOIN StageIdentityIds s ON s.ID = ug.IdentityID
        WHERE g.RowStatus NOT IN (0,254) AND ug.RowStatus NOT IN (0,254)

        UNION

        SELECT DISTINCT g.*
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
        INNER JOIN StageOU sou ON sou.DefaultGroupID = g.ID
        WHERE g.RowStatus NOT IN (0,254)
    )
    INSERT INTO SMigration.Onboarding_Groups
    (
        RunGuid, GroupGuid, RowStatus, DirectoryId, Code, Name, Source, IsBusinessUnitGroup
    )
    SELECT DISTINCT
        @RunGuid, g.Guid, g.RowStatus, g.DirectoryId, g.Code, g.Name, g.Source,
        CAST(CASE WHEN g.Guid = @BusinessUnitGroupGuid THEN 1 ELSE 0 END AS bit)
    FROM RelevantGroups g;';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitGroupGuid UNIQUEIDENTIFIER, @BusinessUnitOuGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid,
        @BusinessUnitGroupGuid = @BusinessUnitGroupGuid,
        @BusinessUnitOuGuid = @SourceBusinessUnitOrganisationalUnitGuid;

    /* OUs */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_OrganisationalUnits
    (
        RunGuid, OrganisationalUnitGuid, RowStatus, Name, ParentOrganisationalUnitGuid,
        AddressGuid, ContactGuid, OfficialAddressGuid, OfficialContactGuid,
        DepartmentPrefix, CostCentreCode, DefaultSecurityGroupGuid, QuoteThreshold, OrgLevel
    )
    SELECT
        @RunGuid,
        ou.Guid,
        ou.RowStatus,
        ou.Name,
        parent.Guid,
        a.Guid,
        c.Guid,
        oa.Guid,
        oc.Guid,
        ou.DepartmentPrefix,
        ou.CostCentreCode,
        g.Guid,
        ou.QuoteThreshold,
        ou.OrgNode.GetLevel()
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits ou
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits parent ON parent.ID = ou.ParentID
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Addresses a ON a.ID = ou.AddressId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts c ON c.ID = ou.ContactId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Addresses oa ON oa.ID = ou.OfficialAddressId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts oc ON oc.ID = ou.OfficialContactId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g ON g.ID = ou.DefaultSecurityGroupId
    CROSS JOIN (SELECT OrgNode FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits WHERE Guid = @BusinessUnitOuGuid) b
    WHERE ou.RowStatus NOT IN (0,254)
      AND ou.OrgNode.IsDescendantOf(b.OrgNode) = 1;';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitOuGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid,
        @BusinessUnitOuGuid = @SourceBusinessUnitOrganisationalUnitGuid;

    /* Addresses */
    SET @sql = N'
    ;WITH RelevantAddressGuids AS
    (
        SELECT AddressGuid AS Guid FROM SMigration.Onboarding_OrganisationalUnits WHERE RunGuid = @RunGuid
        UNION
        SELECT OfficialAddressGuid FROM SMigration.Onboarding_OrganisationalUnits WHERE RunGuid = @RunGuid
    )
    INSERT INTO SMigration.Onboarding_Addresses
    (
        RunGuid, AddressGuid, RowStatus, AddressNumber, Name, Number, AddressLine1, AddressLine2, AddressLine3, Town, CountyGuid, Postcode, CountryGuid, LegacySystemID
    )
    SELECT DISTINCT
        @RunGuid,
        a.Guid,
        a.RowStatus,
        a.AddressNumber,
        a.Name,
        a.Number,
        a.AddressLine1,
        a.AddressLine2,
        a.AddressLine3,
        a.Town,
        county.Guid,
        a.Postcode,
        country.Guid,
        a.LegacySystemID
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Addresses a
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Counties county ON county.ID = a.CountyID
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Countries country ON country.ID = a.CountryID
    INNER JOIN RelevantAddressGuids r ON r.Guid = a.Guid;';

    EXEC sp_executesql @sql, N'@RunGuid UNIQUEIDENTIFIER', @RunGuid = @RunGuid;

    /* Contacts: OU contacts first + identity contacts */
    SET @sql = N'
    ;WITH IdentityContactGuids AS
    (
        SELECT DISTINCT c.Guid
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Identities i
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups ug
            ON ug.IdentityID = i.ID AND ug.RowStatus NOT IN (0,254)
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
            ON g.ID = ug.GroupID AND g.RowStatus NOT IN (0,254)
        INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts c
            ON c.ID = i.ContactId
        WHERE i.RowStatus NOT IN (0,254)
          AND g.Guid = @BusinessUnitGroupGuid
    ),
    OUContactGuids AS
    (
        SELECT ContactGuid AS Guid FROM SMigration.Onboarding_OrganisationalUnits WHERE RunGuid = @RunGuid
        UNION
        SELECT OfficialContactGuid FROM SMigration.Onboarding_OrganisationalUnits WHERE RunGuid = @RunGuid
    ),
    RelevantContactGuids AS
    (
        SELECT Guid FROM IdentityContactGuids
        UNION
        SELECT Guid FROM OUContactGuids
    )
    INSERT INTO SMigration.Onboarding_Contacts
    (
        RunGuid, ContactGuid, RowStatus, PrimaryAccountGuid, PrimaryAddressGuid, FirstName, Initials, Surname,
        PostNominals, TitleGuid, DisplayName, IsPerson, PositionGuid, LegacySystemID
    )
    SELECT DISTINCT
        @RunGuid,
        c.Guid,
        c.RowStatus,
        acct.Guid,
        addr.Guid,
        c.FirstName,
        c.Initials,
        c.Surname,
        c.PostNominals,
        title.Guid,
        c.DisplayName,
        c.IsPerson,
        pos.Guid,
        c.LegacySystemID
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts c
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Accounts acct ON acct.ID = c.PrimaryAccountID
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Addresses addr ON addr.ID = c.PrimaryAddressID
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.ContactTitles title ON title.ID = c.TitleId
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.ContactPositions pos ON pos.ID = c.PositionID
    INNER JOIN RelevantContactGuids r ON r.Guid = c.Guid;';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitGroupGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid,
        @BusinessUnitGroupGuid = @BusinessUnitGroupGuid;

    /* Addresses for contacts */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_Addresses
    (
        RunGuid, AddressGuid, RowStatus, AddressNumber, Name, Number, AddressLine1, AddressLine2, AddressLine3, Town, CountyGuid, Postcode, CountryGuid, LegacySystemID
    )
    SELECT DISTINCT
        @RunGuid,
        a.Guid,
        a.RowStatus,
        a.AddressNumber,
        a.Name,
        a.Number,
        a.AddressLine1,
        a.AddressLine2,
        a.AddressLine3,
        a.Town,
        county.Guid,
        a.Postcode,
        country.Guid,
        a.LegacySystemID
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Addresses a
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Counties county ON county.ID = a.CountyID
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Countries country ON country.ID = a.CountryID
    INNER JOIN SMigration.Onboarding_Contacts c
        ON c.RunGuid = @RunGuid
       AND c.PrimaryAddressGuid = a.Guid
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Onboarding_Addresses x
        WHERE x.RunGuid = @RunGuid
          AND x.AddressGuid = a.Guid
    );';

    EXEC sp_executesql @sql, N'@RunGuid UNIQUEIDENTIFIER', @RunGuid = @RunGuid;

    /* Identities */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_Identities
    (
        RunGuid, IdentityGuid, RowStatus, FullName, EmailAddress, UserGuid, JobTitle,
        OrganisationalUnitGuid, IsActive, ContactGuid, BillableRate, Signature
    )
    SELECT DISTINCT
        @RunGuid,
        i.Guid,
        i.RowStatus,
        i.FullName,
        i.EmailAddress,
        i.UserGuid,
        i.JobTitle,
        ou.Guid,
        i.IsActive,
        c.Guid,
        i.BillableRate,
        i.Signature
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Identities i
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups ug
        ON ug.IdentityID = i.ID AND ug.RowStatus NOT IN (0,254)
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g
        ON g.ID = ug.GroupID AND g.RowStatus NOT IN (0,254)
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits ou
        ON ou.ID = i.OriganisationalUnitId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCrm.Contacts c
        ON c.ID = i.ContactId
    WHERE i.RowStatus NOT IN (0,254)
      AND g.Guid = @BusinessUnitGroupGuid;';

    EXEC sp_executesql
        @sql,
        N'@RunGuid UNIQUEIDENTIFIER, @BusinessUnitGroupGuid UNIQUEIDENTIFIER',
        @RunGuid = @RunGuid,
        @BusinessUnitGroupGuid = @BusinessUnitGroupGuid;

    /* UserGroups */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_UserGroups
    (
        RunGuid, UserGroupGuid, RowStatus, IdentityGuid, GroupGuid
    )
    SELECT DISTINCT
        @RunGuid,
        ug.Guid,
        ug.RowStatus,
        i.Guid,
        g.Guid
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.UserGroups ug
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Identities i ON i.ID = ug.IdentityID
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g ON g.ID = ug.GroupID
    WHERE ug.RowStatus NOT IN (0,254)
      AND EXISTS (SELECT 1 FROM SMigration.Onboarding_Identities si WHERE si.RunGuid = @RunGuid AND si.IdentityGuid = i.Guid)
      AND EXISTS (SELECT 1 FROM SMigration.Onboarding_Groups sg WHERE sg.RunGuid = @RunGuid AND sg.GroupGuid = g.Guid);';

    EXEC sp_executesql @sql, N'@RunGuid UNIQUEIDENTIFIER', @RunGuid = @RunGuid;

    /* WSNG */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_WorkflowStatusNotificationGroups
    (
        RunGuid, WorkflowNotificationGroupGuid, RowStatus, WorkflowGuid, WorkflowStatusGuid, GroupGuid, CanAction
    )
    SELECT DISTINCT
        @RunGuid,
        x.Guid,
        x.RowStatus,
        wf.Guid,
        x.WorkflowStatusGuid,
        g.Guid,
        x.CanAction
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.WorkflowStatusNotificationGroups x
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Workflow wf ON wf.ID = x.WorkflowID
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups g ON g.ID = x.GroupID
    WHERE x.RowStatus NOT IN (0,254)
      AND EXISTS (SELECT 1 FROM SMigration.Onboarding_Groups sg WHERE sg.RunGuid = @RunGuid AND sg.GroupGuid = g.Guid);';

    EXEC sp_executesql @sql, N'@RunGuid UNIQUEIDENTIFIER', @RunGuid = @RunGuid;

    /* JobTypes under staged OUs */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_JobTypes
    (
        RunGuid, JobTypeGuid, RowStatus, Name, IsActive, SequenceID, UseTimeSheets, UsePlanChecks, OrganisationalUnitGuid
    )
    SELECT DISTINCT
        @RunGuid, jt.Guid, jt.RowStatus, jt.Name, jt.IsActive, jt.SequenceID, jt.UseTimeSheets, jt.UsePlanChecks, ou.Guid
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes jt
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits ou ON ou.ID = jt.OrganisationalUnitID
    WHERE jt.RowStatus NOT IN (0,254)
      AND EXISTS
      (
          SELECT 1
          FROM SMigration.Onboarding_OrganisationalUnits sou
          WHERE sou.RunGuid = @RunGuid
            AND sou.OrganisationalUnitGuid = ou.Guid
      );';

    EXEC sp_executesql @sql, N'@RunGuid UNIQUEIDENTIFIER', @RunGuid = @RunGuid;

    /* ActivityTypes only those used by staged jobtypes */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_ActivityTypes
    (
        RunGuid, ActivityTypeGuid, RowStatus, Name, IsActive, SortOrder, IsFeeTrigger, IsLiveTrigger,
        IsAdmin, IsScheduleItem, Colour, IsMeeting, IsSiteVisit, IsBillable, IsCommencementTrigger
    )
    SELECT DISTINCT
        @RunGuid,
        at.Guid,
        at.RowStatus,
        at.Name,
        at.IsActive,
        at.SortOrder,
        at.IsFeeTrigger,
        at.IsLiveTrigger,
        at.IsAdmin,
        at.IsScheduleItem,
        at.Colour,
        at.IsMeeting,
        at.IsSiteVisit,
        at.IsBillable,
        at.IsCommencementTrigger
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.ActivityTypes at
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypeActivityTypes jtat
        ON jtat.ActivityTypeID = at.ID
       AND jtat.RowStatus NOT IN (0,254)
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes jt
        ON jt.ID = jtat.JobTypeID
    WHERE at.RowStatus NOT IN (0,254)
      AND EXISTS (SELECT 1 FROM SMigration.Onboarding_JobTypes s WHERE s.RunGuid = @RunGuid AND s.JobTypeGuid = jt.Guid);';

    EXEC sp_executesql @sql, N'@RunGuid UNIQUEIDENTIFIER', @RunGuid = @RunGuid;

    /* MilestoneTypes only those used by staged jobtypes */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_MilestoneTypes
    (
        RunGuid, MilestoneTypeGuid, RowStatus, Code, Name, IsActive, IsInvoiceTrigger, IsReviewRequired, HelpText,
        HasQuotedHours, HasDescription, HasReference, IsCompulsory, IncludeStart, IncludeSchedule, IncludeDueDate, HasExternalSubmission
    )
    SELECT DISTINCT
        @RunGuid,
        mt.Guid,
        mt.RowStatus,
        mt.Code,
        mt.Name,
        mt.IsActive,
        mt.IsInvoiceTrigger,
        mt.IsReviewRequired,
        mt.HelpText,
        mt.HasQuotedHours,
        mt.HasDescription,
        mt.HasReference,
        mt.IsCompulsory,
        mt.IncludeStart,
        mt.IncludeSchedule,
        mt.IncludeDueDate,
        mt.HasExternalSubmission
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.MilestoneTypes mt
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypeMilestoneTemplates jtmt
        ON jtmt.MilestoneTypeID = mt.ID
       AND jtmt.RowStatus NOT IN (0,254)
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes jt
        ON jt.ID = jtmt.JobTypeID
    WHERE mt.RowStatus NOT IN (0,254)
      AND EXISTS (SELECT 1 FROM SMigration.Onboarding_JobTypes s WHERE s.RunGuid = @RunGuid AND s.JobTypeGuid = jt.Guid);';

    EXEC sp_executesql @sql, N'@RunGuid UNIQUEIDENTIFIER', @RunGuid = @RunGuid;

    /* JTAT */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_JobTypeActivityTypes
    (
        RunGuid, JobTypeActivityTypeGuid, RowStatus, JobTypeGuid, ActivityTypeGuid
    )
    SELECT DISTINCT
        @RunGuid,
        jtat.Guid,
        jtat.RowStatus,
        jt.Guid,
        at.Guid
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypeActivityTypes jtat
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes jt ON jt.ID = jtat.JobTypeID
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.ActivityTypes at ON at.ID = jtat.ActivityTypeID
    WHERE jtat.RowStatus NOT IN (0,254)
      AND EXISTS (SELECT 1 FROM SMigration.Onboarding_JobTypes s WHERE s.RunGuid = @RunGuid AND s.JobTypeGuid = jt.Guid)
      AND EXISTS (SELECT 1 FROM SMigration.Onboarding_ActivityTypes s WHERE s.RunGuid = @RunGuid AND s.ActivityTypeGuid = at.Guid);';

    EXEC sp_executesql @sql, N'@RunGuid UNIQUEIDENTIFIER', @RunGuid = @RunGuid;

    /* JTMT */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_JobTypeMilestoneTemplates
    (
        RunGuid, JobTypeMilestoneTemplateGuid, RowStatus, JobTypeGuid, MilestoneTypeGuid, Description, SortOrder
    )
    SELECT DISTINCT
        @RunGuid,
        jtmt.Guid,
        jtmt.RowStatus,
        jt.Guid,
        mt.Guid,
        jtmt.Description,
        jtmt.SortOrder
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypeMilestoneTemplates jtmt
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes jt ON jt.ID = jtmt.JobTypeID
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.MilestoneTypes mt ON mt.ID = jtmt.MilestoneTypeID
    WHERE jtmt.RowStatus NOT IN (0,254)
      AND EXISTS (SELECT 1 FROM SMigration.Onboarding_JobTypes s WHERE s.RunGuid = @RunGuid AND s.JobTypeGuid = jt.Guid)
      AND EXISTS (SELECT 1 FROM SMigration.Onboarding_MilestoneTypes s WHERE s.RunGuid = @RunGuid AND s.MilestoneTypeGuid = mt.Guid);';

    EXEC sp_executesql @sql, N'@RunGuid UNIQUEIDENTIFIER', @RunGuid = @RunGuid;

    /* Products */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_Products
    (
        RunGuid, ProductGuid, RowStatus, Code, Description, CreatedJobTypeGuid, NeverConsolidate, RibaStageGuid
    )
    SELECT DISTINCT
        @RunGuid,
        p.Guid,
        p.RowStatus,
        p.Code,
        p.Description,
        jt.Guid,
        p.NeverConsolidate,
        rs.Guid
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SProd.Products p
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypes jt ON jt.ID = p.CreatedJobType
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.RibaStages rs ON rs.ID = p.RibaStageId
    WHERE p.RowStatus NOT IN (0,254)
      AND EXISTS (SELECT 1 FROM SMigration.Onboarding_JobTypes s WHERE s.RunGuid = @RunGuid AND s.JobTypeGuid = jt.Guid);';

    EXEC sp_executesql @sql, N'@RunGuid UNIQUEIDENTIFIER', @RunGuid = @RunGuid;

    /* ProductJobActivities */
    SET @sql = N'
    INSERT INTO SMigration.Onboarding_ProductJobActivities
    (
        RunGuid, ProductJobActivityGuid, RowStatus, ProductGuid, JobTypeActivityTypeGuid, ActivityTitle,
        OffsetDays, OffsetWeeks, OffsetMonths, JobTypeMilestoneTemplateGuid, PercentageOfProductValue
    )
    SELECT DISTINCT
        @RunGuid,
        pja.Guid,
        pja.RowStatus,
        p.Guid,
        jtat.Guid,
        pja.ActivityTitle,
        pja.OffsetDays,
        pja.OffsetWeeks,
        pja.OffsetMonths,
        jtmt.Guid,
        pja.PercentageOfProductValue
    FROM ' + QUOTENAME(@SourceDatabase) + N'.SJob.ProductJobActivities pja
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SProd.Products p ON p.ID = pja.ProductId
    INNER JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypeActivityTypes jtat ON jtat.ID = pja.JobTypeActivityTypeId
    LEFT JOIN ' + QUOTENAME(@SourceDatabase) + N'.SJob.JobTypeMilestoneTemplates jtmt ON jtmt.ID = pja.JobTypeMilestoneTemplateId
    WHERE pja.RowStatus NOT IN (0,254)
      AND EXISTS (SELECT 1 FROM SMigration.Onboarding_Products s WHERE s.RunGuid = @RunGuid AND s.ProductGuid = p.Guid)
      AND EXISTS (SELECT 1 FROM SMigration.Onboarding_JobTypeActivityTypes s WHERE s.RunGuid = @RunGuid AND s.JobTypeActivityTypeGuid = jtat.Guid);';

    EXEC sp_executesql @sql, N'@RunGuid UNIQUEIDENTIFIER', @RunGuid = @RunGuid;

    DECLARE @c INT;
    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Groups WHERE RunGuid = @RunGuid; EXEC SMigration.OnboardingLog_Add @RunGuid,N'Stage',N'Groups',N'Stage',@c,N'';
    SELECT @c = COUNT(*) FROM SMigration.Onboarding_OrganisationalUnits WHERE RunGuid = @RunGuid; EXEC SMigration.OnboardingLog_Add @RunGuid,N'Stage',N'OrganisationalUnits',N'Stage',@c,N'';
    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Addresses WHERE RunGuid = @RunGuid; EXEC SMigration.OnboardingLog_Add @RunGuid,N'Stage',N'Addresses',N'Stage',@c,N'';
    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Contacts WHERE RunGuid = @RunGuid; EXEC SMigration.OnboardingLog_Add @RunGuid,N'Stage',N'Contacts',N'Stage',@c,N'';
    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Identities WHERE RunGuid = @RunGuid; EXEC SMigration.OnboardingLog_Add @RunGuid,N'Stage',N'Identities',N'Stage',@c,N'';
    SELECT @c = COUNT(*) FROM SMigration.Onboarding_UserGroups WHERE RunGuid = @RunGuid; EXEC SMigration.OnboardingLog_Add @RunGuid,N'Stage',N'UserGroups',N'Stage',@c,N'';
    SELECT @c = COUNT(*) FROM SMigration.Onboarding_WorkflowStatusNotificationGroups WHERE RunGuid = @RunGuid; EXEC SMigration.OnboardingLog_Add @RunGuid,N'Stage',N'WorkflowStatusNotificationGroups',N'Stage',@c,N'';
    SELECT @c = COUNT(*) FROM SMigration.Onboarding_JobTypes WHERE RunGuid = @RunGuid; EXEC SMigration.OnboardingLog_Add @RunGuid,N'Stage',N'JobTypes',N'Stage',@c,N'';
    SELECT @c = COUNT(*) FROM SMigration.Onboarding_ActivityTypes WHERE RunGuid = @RunGuid; EXEC SMigration.OnboardingLog_Add @RunGuid,N'Stage',N'ActivityTypes',N'Stage',@c,N'';
    SELECT @c = COUNT(*) FROM SMigration.Onboarding_MilestoneTypes WHERE RunGuid = @RunGuid; EXEC SMigration.OnboardingLog_Add @RunGuid,N'Stage',N'MilestoneTypes',N'Stage',@c,N'';
    SELECT @c = COUNT(*) FROM SMigration.Onboarding_JobTypeActivityTypes WHERE RunGuid = @RunGuid; EXEC SMigration.OnboardingLog_Add @RunGuid,N'Stage',N'JobTypeActivityTypes',N'Stage',@c,N'';
    SELECT @c = COUNT(*) FROM SMigration.Onboarding_JobTypeMilestoneTemplates WHERE RunGuid = @RunGuid; EXEC SMigration.OnboardingLog_Add @RunGuid,N'Stage',N'JobTypeMilestoneTemplates',N'Stage',@c,N'';
    SELECT @c = COUNT(*) FROM SMigration.Onboarding_Products WHERE RunGuid = @RunGuid; EXEC SMigration.OnboardingLog_Add @RunGuid,N'Stage',N'Products',N'Stage',@c,N'';
    SELECT @c = COUNT(*) FROM SMigration.Onboarding_ProductJobActivities WHERE RunGuid = @RunGuid; EXEC SMigration.OnboardingLog_Add @RunGuid,N'Stage',N'ProductJobActivities',N'Stage',@c,N'';

    SELECT @RunGuid AS RunGuid;
END
GO

/* ================================================================================================
   Validate staged data against target
   ================================================================================================ */
CREATE OR ALTER PROCEDURE SMigration.OnboardingValidate
    @RunGuid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DELETE FROM SMigration.Onboarding_ValidationIssues WHERE RunGuid = @RunGuid;

    /* Address dependencies */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Address', N'SMigration.Onboarding_Addresses', s.AddressGuid, N'Error', N'MISSING_COUNTY',
           N'Address references a County Guid that does not exist in target.'
    FROM SMigration.Onboarding_Addresses s
    LEFT JOIN SCrm.Counties c ON c.Guid = s.CountyGuid
    WHERE s.RunGuid = @RunGuid
      AND s.CountyGuid IS NOT NULL
      AND c.ID IS NULL;

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Address', N'SMigration.Onboarding_Addresses', s.AddressGuid, N'Error', N'MISSING_COUNTRY',
           N'Address references a Country Guid that does not exist in target.'
    FROM SMigration.Onboarding_Addresses s
    LEFT JOIN SCrm.Countries c ON c.Guid = s.CountryGuid
    WHERE s.RunGuid = @RunGuid
      AND s.CountryGuid IS NOT NULL
      AND c.ID IS NULL;

    /* Contact dependencies */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Contact', N'SMigration.Onboarding_Contacts', s.ContactGuid, N'Error', N'MISSING_CONTACT_ACCOUNT',
           N'Contact references a PrimaryAccount Guid that does not exist in target.'
    FROM SMigration.Onboarding_Contacts s
    LEFT JOIN SCrm.Accounts a ON a.Guid = s.PrimaryAccountGuid
    WHERE s.RunGuid = @RunGuid
      AND s.PrimaryAccountGuid IS NOT NULL
      AND a.ID IS NULL;

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Contact', N'SMigration.Onboarding_Contacts', s.ContactGuid, N'Error', N'MISSING_CONTACT_ADDRESS',
           N'Contact references a PrimaryAddress Guid that does not exist in target or staged set.'
    FROM SMigration.Onboarding_Contacts s
    LEFT JOIN SCrm.Addresses a ON a.Guid = s.PrimaryAddressGuid
    WHERE s.RunGuid = @RunGuid
      AND a.ID IS NULL
      AND NOT EXISTS (SELECT 1 FROM SMigration.Onboarding_Addresses x WHERE x.RunGuid = @RunGuid AND x.AddressGuid = s.PrimaryAddressGuid);

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Contact', N'SMigration.Onboarding_Contacts', s.ContactGuid, N'Error', N'MISSING_CONTACT_TITLE',
           N'Contact references a Title Guid that does not exist in target.'
    FROM SMigration.Onboarding_Contacts s
    LEFT JOIN SCrm.ContactTitles t ON t.Guid = s.TitleGuid
    WHERE s.RunGuid = @RunGuid
      AND s.TitleGuid IS NOT NULL
      AND t.ID IS NULL;

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Contact', N'SMigration.Onboarding_Contacts', s.ContactGuid, N'Error', N'MISSING_CONTACT_POSITION',
           N'Contact references a Position Guid that does not exist in target.'
    FROM SMigration.Onboarding_Contacts s
    LEFT JOIN SCrm.ContactPositions p ON p.Guid = s.PositionGuid
    WHERE s.RunGuid = @RunGuid
      AND s.PositionGuid IS NOT NULL
      AND p.ID IS NULL;

    /* Group collisions */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Group', N'SMigration.Onboarding_Groups', s.GroupGuid, N'Warning', N'GROUP_NAME_GUID_MISMATCH',
           N'Target group exists with same Name but different Guid.'
    FROM SMigration.Onboarding_Groups s
    INNER JOIN SCore.Groups g ON g.Name = s.Name AND g.Guid <> s.GroupGuid
    WHERE s.RunGuid = @RunGuid;

    /* OU dependencies */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'OrganisationalUnit', N'SMigration.Onboarding_OrganisationalUnits', s.OrganisationalUnitGuid, N'Error', N'MISSING_DEFAULT_SECURITY_GROUP',
           N'OrganisationalUnit default security group does not exist in target or staged set.'
    FROM SMigration.Onboarding_OrganisationalUnits s
    LEFT JOIN SCore.Groups g ON g.Guid = s.DefaultSecurityGroupGuid
    WHERE s.RunGuid = @RunGuid
      AND g.ID IS NULL
      AND NOT EXISTS (SELECT 1 FROM SMigration.Onboarding_Groups x WHERE x.RunGuid = @RunGuid AND x.GroupGuid = s.DefaultSecurityGroupGuid);

    /* Identity dependencies */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Identity', N'SMigration.Onboarding_Identities', s.IdentityGuid, N'Error', N'MISSING_IDENTITY_OU',
           N'Identity references an OrganisationalUnit Guid that does not exist in target or staged set.'
    FROM SMigration.Onboarding_Identities s
    LEFT JOIN SCore.OrganisationalUnits ou ON ou.Guid = s.OrganisationalUnitGuid
    WHERE s.RunGuid = @RunGuid
      AND ou.ID IS NULL
      AND NOT EXISTS (SELECT 1 FROM SMigration.Onboarding_OrganisationalUnits x WHERE x.RunGuid = @RunGuid AND x.OrganisationalUnitGuid = s.OrganisationalUnitGuid);

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Identity', N'SMigration.Onboarding_Identities', s.IdentityGuid, N'Error', N'MISSING_IDENTITY_CONTACT',
           N'Identity references a Contact Guid that does not exist in target or staged set.'
    FROM SMigration.Onboarding_Identities s
    LEFT JOIN SCrm.Contacts c ON c.Guid = s.ContactGuid
    WHERE s.RunGuid = @RunGuid
      AND c.ID IS NULL
      AND NOT EXISTS (SELECT 1 FROM SMigration.Onboarding_Contacts x WHERE x.RunGuid = @RunGuid AND x.ContactGuid = s.ContactGuid);

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Identity', N'SMigration.Onboarding_Identities', s.IdentityGuid, N'Warning', N'IDENTITY_EMAIL_GUID_MISMATCH',
           N'Target identity exists with same EmailAddress but different Guid.'
    FROM SMigration.Onboarding_Identities s
    INNER JOIN SCore.Identities i ON i.EmailAddress = s.EmailAddress AND i.Guid <> s.IdentityGuid
    WHERE s.RunGuid = @RunGuid;

    /* UserGroup dependencies */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'UserGroup', N'SMigration.Onboarding_UserGroups', s.UserGroupGuid, N'Error', N'MISSING_USERGROUP_IDENTITY',
           N'UserGroup references an Identity Guid not present in target or staged set.'
    FROM SMigration.Onboarding_UserGroups s
    LEFT JOIN SCore.Identities i ON i.Guid = s.IdentityGuid
    WHERE s.RunGuid = @RunGuid
      AND i.ID IS NULL
      AND NOT EXISTS (SELECT 1 FROM SMigration.Onboarding_Identities x WHERE x.RunGuid = @RunGuid AND x.IdentityGuid = s.IdentityGuid);

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'UserGroup', N'SMigration.Onboarding_UserGroups', s.UserGroupGuid, N'Error', N'MISSING_USERGROUP_GROUP',
           N'UserGroup references a Group Guid not present in target or staged set.'
    FROM SMigration.Onboarding_UserGroups s
    LEFT JOIN SCore.Groups g ON g.Guid = s.GroupGuid
    WHERE s.RunGuid = @RunGuid
      AND g.ID IS NULL
      AND NOT EXISTS (SELECT 1 FROM SMigration.Onboarding_Groups x WHERE x.RunGuid = @RunGuid AND x.GroupGuid = s.GroupGuid);

    /* Workflow dependencies */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'WorkflowStatusNotificationGroup', N'SMigration.Onboarding_WorkflowStatusNotificationGroups', s.WorkflowNotificationGroupGuid, N'Error', N'MISSING_WORKFLOW',
           N'WorkflowStatusNotificationGroup references a Workflow Guid that does not exist in target.'
    FROM SMigration.Onboarding_WorkflowStatusNotificationGroups s
    LEFT JOIN SCore.Workflow wf ON wf.Guid = s.WorkflowGuid
    WHERE s.RunGuid = @RunGuid
      AND wf.ID IS NULL;

    /* Job setup dependencies */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'JobType', N'SMigration.Onboarding_JobTypes', s.JobTypeGuid, N'Error', N'MISSING_JOBTYPE_OU',
           N'JobType references an OrganisationalUnit Guid that does not exist in target or staged set.'
    FROM SMigration.Onboarding_JobTypes s
    LEFT JOIN SCore.OrganisationalUnits ou ON ou.Guid = s.OrganisationalUnitGuid
    WHERE s.RunGuid = @RunGuid
      AND ou.ID IS NULL
      AND NOT EXISTS (SELECT 1 FROM SMigration.Onboarding_OrganisationalUnits x WHERE x.RunGuid = @RunGuid AND x.OrganisationalUnitGuid = s.OrganisationalUnitGuid);

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Product', N'SMigration.Onboarding_Products', s.ProductGuid, N'Error', N'MISSING_PRODUCT_JOBTYPE',
           N'Product references a CreatedJobType Guid not present in target or staged set.'
    FROM SMigration.Onboarding_Products s
    LEFT JOIN SJob.JobTypes jt ON jt.Guid = s.CreatedJobTypeGuid
    WHERE s.RunGuid = @RunGuid
      AND jt.ID IS NULL
      AND NOT EXISTS (SELECT 1 FROM SMigration.Onboarding_JobTypes x WHERE x.RunGuid = @RunGuid AND x.JobTypeGuid = s.CreatedJobTypeGuid);

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Product', N'SMigration.Onboarding_Products', s.ProductGuid, N'Error', N'MISSING_RIBA_STAGE',
           N'Product references a RibaStage Guid that does not exist in target.'
    FROM SMigration.Onboarding_Products s
    LEFT JOIN SJob.RibaStages rs ON rs.Guid = s.RibaStageGuid
    WHERE s.RunGuid = @RunGuid
      AND s.RibaStageGuid IS NOT NULL
      AND rs.ID IS NULL;

    /* warnings */
    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'JobType', N'SMigration.Onboarding_JobTypes', s.JobTypeGuid, N'Warning', N'JOBTYPE_NAME_GUID_MISMATCH',
           N'Target JobType exists with same Name but different Guid.'
    FROM SMigration.Onboarding_JobTypes s
    INNER JOIN SJob.JobTypes t ON t.Name = s.Name AND t.Guid <> s.JobTypeGuid
    WHERE s.RunGuid = @RunGuid;

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'ActivityType', N'SMigration.Onboarding_ActivityTypes', s.ActivityTypeGuid, N'Warning', N'ACTIVITY_NAME_GUID_MISMATCH',
           N'Target ActivityType exists with same Name but different Guid.'
    FROM SMigration.Onboarding_ActivityTypes s
    INNER JOIN SJob.ActivityTypes t ON t.Name = s.Name AND t.Guid <> s.ActivityTypeGuid
    WHERE s.RunGuid = @RunGuid;

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'MilestoneType', N'SMigration.Onboarding_MilestoneTypes', s.MilestoneTypeGuid, N'Warning', N'MILESTONE_CODE_GUID_MISMATCH',
           N'Target MilestoneType exists with same Code but different Guid.'
    FROM SMigration.Onboarding_MilestoneTypes s
    INNER JOIN SJob.MilestoneTypes t ON t.Code = s.Code AND t.Guid <> s.MilestoneTypeGuid
    WHERE s.RunGuid = @RunGuid;

    INSERT INTO SMigration.Onboarding_ValidationIssues
    (RunGuid, EntityName, StageTable, StageGuid, Severity, IssueCode, IssueMessage)
    SELECT @RunGuid, N'Product', N'SMigration.Onboarding_Products', s.ProductGuid, N'Warning', N'PRODUCT_CODE_GUID_MISMATCH',
           N'Target Product exists with same Code but different Guid.'
    FROM SMigration.Onboarding_Products s
    INNER JOIN SProd.Products t ON t.Code = s.Code AND t.Guid <> s.ProductGuid
    WHERE s.RunGuid = @RunGuid;

    DECLARE @Err INT = 0, @Warn INT = 0;
    SELECT @Err = COUNT(*) FROM SMigration.Onboarding_ValidationIssues WHERE RunGuid = @RunGuid AND Severity = N'Error';
    SELECT @Warn = COUNT(*) FROM SMigration.Onboarding_ValidationIssues WHERE RunGuid = @RunGuid AND Severity = N'Warning';
    DECLARE @FullErrorCount INT = @Err + @Warn
    DECLARE @FullError NVarchar(50) = CONCAT(N'Errors=', @Err, N'; Warnings=', @Warn);
    EXEC SMigration.OnboardingLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'Validate',
        @EntityName = N'All',
        @ActionName = N'Summary',
        @AffectedCount = @FullErrorCount,
        @Details = @FullError

    SELECT * FROM SMigration.Onboarding_ValidationIssues WHERE RunGuid = @RunGuid ORDER BY ID;
END
GO

/* ================================================================================================
   Report
   ================================================================================================ */
CREATE OR ALTER PROCEDURE SMigration.OnboardingReport
    @RunGuid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT * FROM SMigration.Onboarding_Run WHERE RunGuid = @RunGuid;

    SELECT N'Groups' AS EntityName, COUNT(*) AS StagedCount FROM SMigration.Onboarding_Groups WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'OrganisationalUnits', COUNT(*) FROM SMigration.Onboarding_OrganisationalUnits WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'Addresses', COUNT(*) FROM SMigration.Onboarding_Addresses WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'Contacts', COUNT(*) FROM SMigration.Onboarding_Contacts WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'Identities', COUNT(*) FROM SMigration.Onboarding_Identities WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'UserGroups', COUNT(*) FROM SMigration.Onboarding_UserGroups WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'WorkflowStatusNotificationGroups', COUNT(*) FROM SMigration.Onboarding_WorkflowStatusNotificationGroups WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'JobTypes', COUNT(*) FROM SMigration.Onboarding_JobTypes WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'ActivityTypes', COUNT(*) FROM SMigration.Onboarding_ActivityTypes WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'MilestoneTypes', COUNT(*) FROM SMigration.Onboarding_MilestoneTypes WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'JobTypeActivityTypes', COUNT(*) FROM SMigration.Onboarding_JobTypeActivityTypes WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'JobTypeMilestoneTemplates', COUNT(*) FROM SMigration.Onboarding_JobTypeMilestoneTemplates WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'Products', COUNT(*) FROM SMigration.Onboarding_Products WHERE RunGuid = @RunGuid
    UNION ALL SELECT N'ProductJobActivities', COUNT(*) FROM SMigration.Onboarding_ProductJobActivities WHERE RunGuid = @RunGuid;

    SELECT Severity, COUNT(*) AS IssueCount
    FROM SMigration.Onboarding_ValidationIssues
    WHERE RunGuid = @RunGuid
    GROUP BY Severity;

    SELECT * FROM SMigration.Onboarding_ValidationIssues WHERE RunGuid = @RunGuid ORDER BY ID;
    SELECT * FROM SMigration.Onboarding_ExecutionLog WHERE RunGuid = @RunGuid ORDER BY ID;
END
GO

/* ================================================================================================
   Apply import
   ================================================================================================ */
CREATE OR ALTER PROCEDURE SMigration.OnboardingImport_Apply
    @RunGuid UNIQUEIDENTIFIER,
    @AllowWarnings BIT = 1,
    @PreviewOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    EXEC SMigration.OnboardingValidate @RunGuid = @RunGuid;

    IF EXISTS (SELECT 1 FROM SMigration.Onboarding_ValidationIssues WHERE RunGuid = @RunGuid AND Severity = N'Error')
    BEGIN
        ;THROW 60000, N'SMigration validation failed. Resolve errors before import.', 1;
    END

    IF @AllowWarnings = 0
       AND EXISTS (SELECT 1 FROM SMigration.Onboarding_ValidationIssues WHERE RunGuid = @RunGuid AND Severity = N'Warning')
    BEGIN
        ;THROW 60000, N'SMigration validation contains warnings and @AllowWarnings = 0.', 1;
    END

    IF @PreviewOnly = 1
    BEGIN
        EXEC SMigration.OnboardingLog_Add @RunGuid, N'Import', N'All', N'Preview', 0, N'Preview only; no changes applied.';
        EXEC SMigration.OnboardingReport @RunGuid = @RunGuid;
        RETURN;
    END

    DECLARE @Guid UNIQUEIDENTIFIER, @IsInsert BIT, @cnt INT;

    BEGIN TRAN;

    /* 1. Groups */
    UPDATE t
       SET t.RowStatus = s.RowStatus,
           t.DirectoryId = s.DirectoryId,
           t.Code = s.Code,
           t.Name = s.Name,
           t.Source = s.Source
    FROM SCore.Groups t
    INNER JOIN SMigration.Onboarding_Groups s ON s.GroupGuid = t.Guid
    WHERE s.RunGuid = @RunGuid
      AND (t.RowStatus <> s.RowStatus OR t.DirectoryId <> s.DirectoryId OR t.Code <> s.Code OR t.Name <> s.Name OR t.Source <> s.Source);
    SET @cnt = @@ROWCOUNT;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'Groups',N'Update',@cnt,N'';

    DECLARE cur_groups CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.GroupGuid FROM SMigration.Onboarding_Groups s
    LEFT JOIN SCore.Groups t ON t.Guid = s.GroupGuid
    WHERE s.RunGuid = @RunGuid AND t.ID IS NULL;
    OPEN cur_groups; FETCH NEXT FROM cur_groups INTO @Guid;
    SET @cnt = 0;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.UpsertDataObject @Guid=@Guid,@SchemeName=N'SCore',@ObjectName=N'Groups',@IncludeDefaultSecurity=0,@IsInsert=@IsInsert OUTPUT;
        INSERT INTO SCore.Groups (RowStatus,Guid,DirectoryId,Code,Name,Source)
        SELECT RowStatus,GroupGuid,DirectoryId,Code,Name,Source
        FROM SMigration.Onboarding_Groups
        WHERE RunGuid=@RunGuid AND GroupGuid=@Guid;
        SET @cnt += @@ROWCOUNT;
        FETCH NEXT FROM cur_groups INTO @Guid;
    END
    CLOSE cur_groups; DEALLOCATE cur_groups;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'Groups',N'Insert',@cnt,N'';

    /* 2. Addresses */
    UPDATE t
       SET t.RowStatus = s.RowStatus,
           t.AddressNumber = s.AddressNumber,
           t.Name = s.Name,
           t.Number = s.Number,
           t.AddressLine1 = s.AddressLine1,
           t.AddressLine2 = s.AddressLine2,
           t.AddressLine3 = s.AddressLine3,
           t.Town = s.Town,
           t.CountyID = c.ID,
           t.Postcode = s.Postcode,
           t.CountryID = co.ID,
           t.LegacySystemID = s.LegacySystemID,
           t.FormattedAddressCR = SCore.FormatAddress(N'', s.Number, s.AddressLine1, s.AddressLine2, s.AddressLine3, s.Town, c.Name, s.Postcode, CHAR(13)),
           t.FormattedAddressComma = SCore.FormatAddress(N'', s.Number, s.AddressLine1, s.AddressLine2, s.AddressLine3, s.Town, c.Name, s.Postcode, N',')
    FROM SCrm.Addresses t
    INNER JOIN SMigration.Onboarding_Addresses s ON s.AddressGuid = t.Guid
    LEFT JOIN SCrm.Counties c ON c.Guid = s.CountyGuid
    LEFT JOIN SCrm.Countries co ON co.Guid = s.CountryGuid
    WHERE s.RunGuid = @RunGuid;
    SET @cnt = @@ROWCOUNT;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'Addresses',N'Update',@cnt,N'';

    DECLARE cur_addr CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.AddressGuid FROM SMigration.Onboarding_Addresses s
    LEFT JOIN SCrm.Addresses t ON t.Guid = s.AddressGuid
    WHERE s.RunGuid = @RunGuid AND t.ID IS NULL;
    OPEN cur_addr; FETCH NEXT FROM cur_addr INTO @Guid;
    SET @cnt = 0;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.UpsertDataObject @Guid=@Guid,@SchemeName=N'SCrm',@ObjectName=N'Addresses',@IncludeDefaultSecurity=0,@IsInsert=@IsInsert OUTPUT;
        INSERT INTO SCrm.Addresses
        (
            RowStatus, Guid, AddressNumber, Name, Number, AddressLine1, AddressLine2, AddressLine3,
            Town, CountyID, Postcode, CountryID, LegacyID, FormattedAddressCR, FormattedAddressComma, LegacySystemID
        )
        SELECT
            s.RowStatus, s.AddressGuid, s.AddressNumber, s.Name, s.Number, s.AddressLine1, s.AddressLine2, s.AddressLine3,
            s.Town, c.ID, s.Postcode, co.ID, NULL,
            SCore.FormatAddress(N'', s.Number, s.AddressLine1, s.AddressLine2, s.AddressLine3, s.Town, c.Name, s.Postcode, CHAR(13)),
            SCore.FormatAddress(N'', s.Number, s.AddressLine1, s.AddressLine2, s.AddressLine3, s.Town, c.Name, s.Postcode, N','),
            s.LegacySystemID
        FROM SMigration.Onboarding_Addresses s
        LEFT JOIN SCrm.Counties c ON c.Guid = s.CountyGuid
        LEFT JOIN SCrm.Countries co ON co.Guid = s.CountryGuid
        WHERE s.RunGuid=@RunGuid AND s.AddressGuid=@Guid;
        SET @cnt += @@ROWCOUNT;
        FETCH NEXT FROM cur_addr INTO @Guid;
    END
    CLOSE cur_addr; DEALLOCATE cur_addr;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'Addresses',N'Insert',@cnt,N'';

    /* 3. Contacts */
    UPDATE t
       SET t.RowStatus = s.RowStatus,
           t.PrimaryAccountID = a.ID,
           t.PrimaryAddressID = addr.ID,
           t.FirstName = s.FirstName,
           t.Initials = s.Initials,
           t.Surname = s.Surname,
           t.PostNominals = s.PostNominals,
           t.TitleId = tt.ID,
           t.DisplayName = s.DisplayName,
           t.IsPerson = s.IsPerson,
           t.PositionID = p.ID,
           t.LegacySystemID = s.LegacySystemID
    FROM SCrm.Contacts t
    INNER JOIN SMigration.Onboarding_Contacts s ON s.ContactGuid = t.Guid
    LEFT JOIN SCrm.Accounts a ON a.Guid = s.PrimaryAccountGuid
    INNER JOIN SCrm.Addresses addr ON addr.Guid = s.PrimaryAddressGuid
    LEFT JOIN SCrm.ContactTitles tt ON tt.Guid = s.TitleGuid
    LEFT JOIN SCrm.ContactPositions p ON p.Guid = s.PositionGuid
    WHERE s.RunGuid = @RunGuid;
    SET @cnt = @@ROWCOUNT;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'Contacts',N'Update',@cnt,N'';

    DECLARE cur_contact CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.ContactGuid FROM SMigration.Onboarding_Contacts s
    LEFT JOIN SCrm.Contacts t ON t.Guid = s.ContactGuid
    WHERE s.RunGuid = @RunGuid AND t.ID IS NULL;
    OPEN cur_contact; FETCH NEXT FROM cur_contact INTO @Guid;
    SET @cnt = 0;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.UpsertDataObject @Guid=@Guid,@SchemeName=N'SCrm',@ObjectName=N'Contacts',@IncludeDefaultSecurity=0,@IsInsert=@IsInsert OUTPUT;
        INSERT INTO SCrm.Contacts
        (
            RowStatus, Guid, PrimaryAccountID, PrimaryAddressID, FirstName, Initials, Surname, PostNominals,
            TitleId, DisplayName, IsPerson, PositionID, LegacyID, LegacySystemID
        )
        SELECT
            s.RowStatus, s.ContactGuid, a.ID, addr.ID, s.FirstName, s.Initials, s.Surname, s.PostNominals,
            tt.ID, s.DisplayName, s.IsPerson, p.ID, NULL, s.LegacySystemID
        FROM SMigration.Onboarding_Contacts s
        LEFT JOIN SCrm.Accounts a ON a.Guid = s.PrimaryAccountGuid
        INNER JOIN SCrm.Addresses addr ON addr.Guid = s.PrimaryAddressGuid
        LEFT JOIN SCrm.ContactTitles tt ON tt.Guid = s.TitleGuid
        LEFT JOIN SCrm.ContactPositions p ON p.Guid = s.PositionGuid
        WHERE s.RunGuid=@RunGuid AND s.ContactGuid=@Guid;
        SET @cnt += @@ROWCOUNT;
        FETCH NEXT FROM cur_contact INTO @Guid;
    END
    CLOSE cur_contact; DEALLOCATE cur_contact;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'Contacts',N'Insert',@cnt,N'';

    /* 4. OUs in hierarchy order */
    DECLARE cur_ou CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.OrganisationalUnitGuid
    FROM SMigration.Onboarding_OrganisationalUnits s
    ORDER BY ISNULL(s.OrgLevel,0), s.Name;
    OPEN cur_ou; FETCH NEXT FROM cur_ou INTO @Guid;
    SET @cnt = 0;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE
            @ParentGuid UNIQUEIDENTIFIER,
            @Name NVARCHAR(250),
            @AddressGuid UNIQUEIDENTIFIER,
            @ContactGuid UNIQUEIDENTIFIER,
            @OfficialAddressGuid UNIQUEIDENTIFIER,
            @OfficialContactGuid UNIQUEIDENTIFIER,
            @DepartmentPrefix NVARCHAR(10),
            @CostCentreCode NVARCHAR(50),
            @DefaultSecurityGroupGuid UNIQUEIDENTIFIER,
            @QuoteThreshold DECIMAL(19,2);

        SELECT
            @ParentGuid = ParentOrganisationalUnitGuid,
            @Name = Name,
            @AddressGuid = AddressGuid,
            @ContactGuid = ContactGuid,
            @OfficialAddressGuid = OfficialAddressGuid,
            @OfficialContactGuid = OfficialContactGuid,
            @DepartmentPrefix = DepartmentPrefix,
            @CostCentreCode = CostCentreCode,
            @DefaultSecurityGroupGuid = DefaultSecurityGroupGuid,
            @QuoteThreshold = QuoteThreshold
        FROM SMigration.Onboarding_OrganisationalUnits
        WHERE RunGuid = @RunGuid
          AND OrganisationalUnitGuid = @Guid;

        IF EXISTS (SELECT 1 FROM SCore.OrganisationalUnits WHERE Guid = @Guid)
        BEGIN
            EXEC SCore.OrganisationalUnitsUpsert
                @ParentOrganisationalUnitGuid = @ParentGuid,
                @Name = @Name,
                @AddressGuid = @AddressGuid,
                @ContactGuid = @ContactGuid,
                @OfficialAddressGuid = @OfficialAddressGuid,
                @OfficialContactGuid = @OfficialContactGuid,
                @DepartmentPrefix = @DepartmentPrefix,
                @CostCentreCode = @CostCentreCode,
                @DefaultSecurityGroupGuid = @DefaultSecurityGroupGuid,
                @Guid = @Guid OUTPUT,
                @QuoteThreshold = @QuoteThreshold;
        END
        ELSE
        BEGIN
            EXEC SCore.OrganisationalUnitsUpsert
                @ParentOrganisationalUnitGuid = @ParentGuid,
                @Name = @Name,
                @AddressGuid = @AddressGuid,
                @ContactGuid = @ContactGuid,
                @OfficialAddressGuid = @OfficialAddressGuid,
                @OfficialContactGuid = @OfficialContactGuid,
                @DepartmentPrefix = @DepartmentPrefix,
                @CostCentreCode = @CostCentreCode,
                @DefaultSecurityGroupGuid = @DefaultSecurityGroupGuid,
                @Guid = @Guid OUTPUT,
                @QuoteThreshold = @QuoteThreshold;
        END
        SET @cnt += 1;
        FETCH NEXT FROM cur_ou INTO @Guid;
    END
    CLOSE cur_ou; DEALLOCATE cur_ou;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'OrganisationalUnits',N'Upsert',@cnt,N'';

    /* 5. Identities */
    UPDATE t
       SET t.RowStatus = s.RowStatus,
           t.FullName = s.FullName,
           t.EmailAddress = s.EmailAddress,
           t.UserGuid = s.UserGuid,
           t.JobTitle = s.JobTitle,
           t.OriganisationalUnitId = ou.ID,
           t.IsActive = s.IsActive,
           t.ContactId = c.ID,
           t.BillableRate = s.BillableRate,
           t.Signature = s.Signature
    FROM SCore.Identities t
    INNER JOIN SMigration.Onboarding_Identities s ON s.IdentityGuid = t.Guid
    INNER JOIN SCore.OrganisationalUnits ou ON ou.Guid = s.OrganisationalUnitGuid
    INNER JOIN SCrm.Contacts c ON c.Guid = s.ContactGuid
    WHERE s.RunGuid = @RunGuid;
    SET @cnt = @@ROWCOUNT;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'Identities',N'Update',@cnt,N'';

    DECLARE cur_ident CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.IdentityGuid FROM SMigration.Onboarding_Identities s
    LEFT JOIN SCore.Identities t ON t.Guid = s.IdentityGuid
    WHERE s.RunGuid = @RunGuid AND t.ID IS NULL;
    OPEN cur_ident; FETCH NEXT FROM cur_ident INTO @Guid;
    SET @cnt = 0;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE
            @FullName NVARCHAR(250), @EmailAddress NVARCHAR(150), @UserGuid UNIQUEIDENTIFIER, @JobTitle NVARCHAR(50),
            @OUguid UNIQUEIDENTIFIER, @IsActive BIT, @ContactGuid2 UNIQUEIDENTIFIER, @BillableRate DECIMAL(19,2), @Signature VARBINARY(MAX);
        SELECT
            @FullName = FullName, @EmailAddress = EmailAddress, @UserGuid = UserGuid, @JobTitle = JobTitle,
            @OUguid = OrganisationalUnitGuid, @IsActive = IsActive, @ContactGuid2 = ContactGuid, @BillableRate = BillableRate, @Signature = Signature
        FROM SMigration.Onboarding_Identities
        WHERE RunGuid = @RunGuid AND IdentityGuid = @Guid;

        EXEC SCore.UpsertDataObject @Guid=@Guid,@SchemeName=N'SCore',@ObjectName=N'Identities',@IncludeDefaultSecurity=0,@IsInsert=@IsInsert OUTPUT;
        INSERT INTO SCore.Identities
        (
            RowStatus, Guid, FullName, EmailAddress, UserGuid, JobTitle, OriganisationalUnitId, IsActive, ContactId, BillableRate, Signature
        )
        SELECT
            1, @Guid, @FullName, @EmailAddress, @UserGuid, @JobTitle, ou.ID, @IsActive, c.ID, @BillableRate, @Signature
        FROM SCore.OrganisationalUnits ou
        INNER JOIN SCrm.Contacts c ON c.Guid = @ContactGuid2
        WHERE ou.Guid = @OUguid;

        DECLARE @NewIdentityId INT;
        SELECT @NewIdentityId = ID FROM SCore.Identities WHERE Guid = @Guid;
        IF NOT EXISTS (SELECT 1 FROM SCore.UserPreferences WHERE ID = @NewIdentityId)
        BEGIN
            INSERT INTO SCore.UserPreferences (ID, Guid, RowStatus, SystemLanguageID)
            VALUES (@NewIdentityId, @Guid, 1, 1);
        END

        SET @cnt += 1;
        FETCH NEXT FROM cur_ident INTO @Guid;
    END
    CLOSE cur_ident; DEALLOCATE cur_ident;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'Identities',N'Insert',@cnt,N'';

    /* 6. UserGroups */
    UPDATE t
       SET t.RowStatus = s.RowStatus,
           t.IdentityID = i.ID,
           t.GroupID = g.ID
    FROM SCore.UserGroups t
    INNER JOIN SMigration.Onboarding_UserGroups s ON s.UserGroupGuid = t.Guid
    INNER JOIN SCore.Identities i ON i.Guid = s.IdentityGuid
    INNER JOIN SCore.Groups g ON g.Guid = s.GroupGuid
    WHERE s.RunGuid = @RunGuid;
    SET @cnt = @@ROWCOUNT;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'UserGroups',N'Update',@cnt,N'';

    DECLARE cur_ug CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.UserGroupGuid FROM SMigration.Onboarding_UserGroups s
    LEFT JOIN SCore.UserGroups t ON t.Guid = s.UserGroupGuid
    WHERE s.RunGuid = @RunGuid AND t.ID IS NULL;
    OPEN cur_ug; FETCH NEXT FROM cur_ug INTO @Guid;
    SET @cnt = 0;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.UpsertDataObject @Guid=@Guid,@SchemeName=N'SCore',@ObjectName=N'UserGroups',@IncludeDefaultSecurity=0,@IsInsert=@IsInsert OUTPUT;
        INSERT INTO SCore.UserGroups (Guid, RowStatus, IdentityID, GroupID)
        SELECT s.UserGroupGuid, s.RowStatus, i.ID, g.ID
        FROM SMigration.Onboarding_UserGroups s
        INNER JOIN SCore.Identities i ON i.Guid = s.IdentityGuid
        INNER JOIN SCore.Groups g ON g.Guid = s.GroupGuid
        WHERE s.RunGuid = @RunGuid AND s.UserGroupGuid = @Guid
          AND NOT EXISTS
          (
              SELECT 1 FROM SCore.UserGroups x WHERE x.RowStatus NOT IN (0,254) AND x.IdentityID = i.ID AND x.GroupID = g.ID
          );
        SET @cnt += @@ROWCOUNT;
        FETCH NEXT FROM cur_ug INTO @Guid;
    END
    CLOSE cur_ug; DEALLOCATE cur_ug;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'UserGroups',N'Insert',@cnt,N'';

    /* 7. WorkflowStatusNotificationGroups */
    UPDATE t
       SET t.RowStatus = s.RowStatus,
           t.WorkflowID = wf.ID,
           t.WorkflowStatusGuid = s.WorkflowStatusGuid,
           t.GroupID = g.ID,
           t.CanAction = s.CanAction
    FROM SCore.WorkflowStatusNotificationGroups t
    INNER JOIN SMigration.Onboarding_WorkflowStatusNotificationGroups s ON s.WorkflowNotificationGroupGuid = t.Guid
    INNER JOIN SCore.Workflow wf ON wf.Guid = s.WorkflowGuid
    INNER JOIN SCore.Groups g ON g.Guid = s.GroupGuid
    WHERE s.RunGuid = @RunGuid;
    SET @cnt = @@ROWCOUNT;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'WorkflowStatusNotificationGroups',N'Update',@cnt,N'';

    DECLARE cur_wsng CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.WorkflowNotificationGroupGuid FROM SMigration.Onboarding_WorkflowStatusNotificationGroups s
    LEFT JOIN SCore.WorkflowStatusNotificationGroups t ON t.Guid = s.WorkflowNotificationGroupGuid
    WHERE s.RunGuid = @RunGuid AND t.ID IS NULL;
    OPEN cur_wsng; FETCH NEXT FROM cur_wsng INTO @Guid;
    SET @cnt = 0;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.UpsertDataObject @Guid=@Guid,@SchemeName=N'SCore',@ObjectName=N'WorkflowStatusNotificationGroups',@IncludeDefaultSecurity=0,@IsInsert=@IsInsert OUTPUT;
        INSERT INTO SCore.WorkflowStatusNotificationGroups (RowStatus, Guid, WorkflowID, WorkflowStatusGuid, GroupID, CanAction)
        SELECT s.RowStatus, s.WorkflowNotificationGroupGuid, wf.ID, s.WorkflowStatusGuid, g.ID, s.CanAction
        FROM SMigration.Onboarding_WorkflowStatusNotificationGroups s
        INNER JOIN SCore.Workflow wf ON wf.Guid = s.WorkflowGuid
        INNER JOIN SCore.Groups g ON g.Guid = s.GroupGuid
        WHERE s.RunGuid = @RunGuid AND s.WorkflowNotificationGroupGuid = @Guid
          AND NOT EXISTS
          (
              SELECT 1 FROM SCore.WorkflowStatusNotificationGroups x
              WHERE x.RowStatus NOT IN (0,254) AND x.WorkflowID = wf.ID AND x.WorkflowStatusGuid = s.WorkflowStatusGuid AND x.GroupID = g.ID
          );
        SET @cnt += @@ROWCOUNT;
        FETCH NEXT FROM cur_wsng INTO @Guid;
    END
    CLOSE cur_wsng; DEALLOCATE cur_wsng;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'WorkflowStatusNotificationGroups',N'Insert',@cnt,N'';

    /* 8. JobTypes */
    UPDATE t
       SET t.RowStatus = s.RowStatus,
           t.Name = s.Name,
           t.IsActive = s.IsActive,
           t.SequenceID = s.SequenceID,
           t.UseTimeSheets = s.UseTimeSheets,
           t.UsePlanChecks = s.UsePlanChecks,
           t.OrganisationalUnitID = ou.ID
    FROM SJob.JobTypes t
    INNER JOIN SMigration.Onboarding_JobTypes s ON s.JobTypeGuid = t.Guid
    INNER JOIN SCore.OrganisationalUnits ou ON ou.Guid = s.OrganisationalUnitGuid
    WHERE s.RunGuid = @RunGuid;
    SET @cnt = @@ROWCOUNT;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'JobTypes',N'Update',@cnt,N'';

    DECLARE cur_jt CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.JobTypeGuid FROM SMigration.Onboarding_JobTypes s
    LEFT JOIN SJob.JobTypes t ON t.Guid = s.JobTypeGuid
    WHERE s.RunGuid = @RunGuid AND t.ID IS NULL;
    OPEN cur_jt; FETCH NEXT FROM cur_jt INTO @Guid;
    SET @cnt = 0;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.UpsertDataObject @Guid=@Guid,@SchemeName=N'SJob',@ObjectName=N'JobTypes',@IncludeDefaultSecurity=0,@IsInsert=@IsInsert OUTPUT;
        INSERT INTO SJob.JobTypes (RowStatus, Guid, Name, IsActive, SequenceID, UseTimeSheets, UsePlanChecks, OrganisationalUnitID)
        SELECT s.RowStatus, s.JobTypeGuid, s.Name, s.IsActive, s.SequenceID, s.UseTimeSheets, s.UsePlanChecks, ou.ID
        FROM SMigration.Onboarding_JobTypes s
        INNER JOIN SCore.OrganisationalUnits ou ON ou.Guid = s.OrganisationalUnitGuid
        WHERE s.RunGuid = @RunGuid AND s.JobTypeGuid = @Guid;
        SET @cnt += @@ROWCOUNT;
        FETCH NEXT FROM cur_jt INTO @Guid;
    END
    CLOSE cur_jt; DEALLOCATE cur_jt;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'JobTypes',N'Insert',@cnt,N'';

    /* 9. ActivityTypes */
    UPDATE t
       SET t.RowStatus = s.RowStatus, t.Name = s.Name, t.IsActive = s.IsActive, t.SortOrder = s.SortOrder,
           t.IsFeeTrigger = s.IsFeeTrigger, t.IsLiveTrigger = s.IsLiveTrigger, t.IsAdmin = s.IsAdmin,
           t.IsScheduleItem = s.IsScheduleItem, t.Colour = s.Colour, t.IsMeeting = s.IsMeeting,
           t.IsSiteVisit = s.IsSiteVisit, t.IsBillable = s.IsBillable, t.IsCommencementTrigger = s.IsCommencementTrigger
    FROM SJob.ActivityTypes t
    INNER JOIN SMigration.Onboarding_ActivityTypes s ON s.ActivityTypeGuid = t.Guid
    WHERE s.RunGuid = @RunGuid;
    SET @cnt = @@ROWCOUNT;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'ActivityTypes',N'Update',@cnt,N'';

    DECLARE cur_at CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.ActivityTypeGuid FROM SMigration.Onboarding_ActivityTypes s
    LEFT JOIN SJob.ActivityTypes t ON t.Guid = s.ActivityTypeGuid
    WHERE s.RunGuid = @RunGuid AND t.ID IS NULL;
    OPEN cur_at; FETCH NEXT FROM cur_at INTO @Guid;
    SET @cnt = 0;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.UpsertDataObject @Guid=@Guid,@SchemeName=N'SJob',@ObjectName=N'ActivityTypes',@IncludeDefaultSecurity=0,@IsInsert=@IsInsert OUTPUT;
        INSERT INTO SJob.ActivityTypes
        (
            RowStatus, Guid, Name, IsActive, SortOrder, IsFeeTrigger, IsLiveTrigger, IsAdmin,
            IsScheduleItem, Colour, IsMeeting, IsSiteVisit, IsBillable, IsCommencementTrigger
        )
        SELECT
            s.RowStatus, s.ActivityTypeGuid, s.Name, s.IsActive, s.SortOrder, s.IsFeeTrigger, s.IsLiveTrigger, s.IsAdmin,
            s.IsScheduleItem, s.Colour, s.IsMeeting, s.IsSiteVisit, s.IsBillable, s.IsCommencementTrigger
        FROM SMigration.Onboarding_ActivityTypes s
        WHERE s.RunGuid = @RunGuid AND s.ActivityTypeGuid = @Guid;
        SET @cnt += @@ROWCOUNT;
        FETCH NEXT FROM cur_at INTO @Guid;
    END
    CLOSE cur_at; DEALLOCATE cur_at;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'ActivityTypes',N'Insert',@cnt,N'';

    /* 10. MilestoneTypes */
    UPDATE t
       SET t.RowStatus = s.RowStatus, t.Code = s.Code, t.Name = s.Name, t.IsActive = s.IsActive,
           t.IsInvoiceTrigger = s.IsInvoiceTrigger, t.IsReviewRequired = s.IsReviewRequired, t.HelpText = s.HelpText,
           t.HasQuotedHours = s.HasQuotedHours, t.HasDescription = s.HasDescription, t.HasReference = s.HasReference,
           t.IsCompulsory = s.IsCompulsory, t.IncludeStart = s.IncludeStart, t.IncludeSchedule = s.IncludeSchedule,
           t.IncludeDueDate = s.IncludeDueDate, t.HasExternalSubmission = s.HasExternalSubmission
    FROM SJob.MilestoneTypes t
    INNER JOIN SMigration.Onboarding_MilestoneTypes s ON s.MilestoneTypeGuid = t.Guid
    WHERE s.RunGuid = @RunGuid;
    SET @cnt = @@ROWCOUNT;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'MilestoneTypes',N'Update',@cnt,N'';

    DECLARE cur_mt CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.MilestoneTypeGuid FROM SMigration.Onboarding_MilestoneTypes s
    LEFT JOIN SJob.MilestoneTypes t ON t.Guid = s.MilestoneTypeGuid
    WHERE s.RunGuid = @RunGuid AND t.ID IS NULL;
    OPEN cur_mt; FETCH NEXT FROM cur_mt INTO @Guid;
    SET @cnt = 0;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.UpsertDataObject @Guid=@Guid,@SchemeName=N'SJob',@ObjectName=N'MilestoneTypes',@IncludeDefaultSecurity=0,@IsInsert=@IsInsert OUTPUT;
        INSERT INTO SJob.MilestoneTypes
        (
            RowStatus, Guid, Code, Name, IsActive, IsInvoiceTrigger, IsReviewRequired, HelpText,
            HasQuotedHours, HasDescription, HasReference, IsCompulsory, IncludeStart, IncludeSchedule, IncludeDueDate, HasExternalSubmission
        )
        SELECT
            s.RowStatus, s.MilestoneTypeGuid, s.Code, s.Name, s.IsActive, s.IsInvoiceTrigger, s.IsReviewRequired, s.HelpText,
            s.HasQuotedHours, s.HasDescription, s.HasReference, s.IsCompulsory, s.IncludeStart, s.IncludeSchedule, s.IncludeDueDate, s.HasExternalSubmission
        FROM SMigration.Onboarding_MilestoneTypes s
        WHERE s.RunGuid = @RunGuid AND s.MilestoneTypeGuid = @Guid;
        SET @cnt += @@ROWCOUNT;
        FETCH NEXT FROM cur_mt INTO @Guid;
    END
    CLOSE cur_mt; DEALLOCATE cur_mt;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'MilestoneTypes',N'Insert',@cnt,N'';

    /* 11. JTAT */
    UPDATE t
       SET t.RowStatus = s.RowStatus, t.JobTypeID = jt.ID, t.ActivityTypeID = at.ID
    FROM SJob.JobTypeActivityTypes t
    INNER JOIN SMigration.Onboarding_JobTypeActivityTypes s ON s.JobTypeActivityTypeGuid = t.Guid
    INNER JOIN SJob.JobTypes jt ON jt.Guid = s.JobTypeGuid
    INNER JOIN SJob.ActivityTypes at ON at.Guid = s.ActivityTypeGuid
    WHERE s.RunGuid = @RunGuid;
    SET @cnt = @@ROWCOUNT;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'JobTypeActivityTypes',N'Update',@cnt,N'';

    DECLARE cur_jtat CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.JobTypeActivityTypeGuid FROM SMigration.Onboarding_JobTypeActivityTypes s
    LEFT JOIN SJob.JobTypeActivityTypes t ON t.Guid = s.JobTypeActivityTypeGuid
    WHERE s.RunGuid = @RunGuid AND t.ID IS NULL;
    OPEN cur_jtat; FETCH NEXT FROM cur_jtat INTO @Guid;
    SET @cnt = 0;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.UpsertDataObject @Guid=@Guid,@SchemeName=N'SJob',@ObjectName=N'JobTypeActivityTypes',@IncludeDefaultSecurity=0,@IsInsert=@IsInsert OUTPUT;
        INSERT INTO SJob.JobTypeActivityTypes (RowStatus, Guid, JobTypeID, ActivityTypeID)
        SELECT s.RowStatus, s.JobTypeActivityTypeGuid, jt.ID, at.ID
        FROM SMigration.Onboarding_JobTypeActivityTypes s
        INNER JOIN SJob.JobTypes jt ON jt.Guid = s.JobTypeGuid
        INNER JOIN SJob.ActivityTypes at ON at.Guid = s.ActivityTypeGuid
        WHERE s.RunGuid = @RunGuid AND s.JobTypeActivityTypeGuid = @Guid
          AND NOT EXISTS (SELECT 1 FROM SJob.JobTypeActivityTypes x WHERE x.RowStatus NOT IN (0,254) AND x.JobTypeID = jt.ID AND x.ActivityTypeID = at.ID);
        SET @cnt += @@ROWCOUNT;
        FETCH NEXT FROM cur_jtat INTO @Guid;
    END
    CLOSE cur_jtat; DEALLOCATE cur_jtat;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'JobTypeActivityTypes',N'Insert',@cnt,N'';

    /* 12. JTMT */
    UPDATE t
       SET t.RowStatus = s.RowStatus, t.JobTypeID = jt.ID, t.MilestoneTypeID = mt.ID, t.Description = s.Description, t.SortOrder = s.SortOrder
    FROM SJob.JobTypeMilestoneTemplates t
    INNER JOIN SMigration.Onboarding_JobTypeMilestoneTemplates s ON s.JobTypeMilestoneTemplateGuid = t.Guid
    INNER JOIN SJob.JobTypes jt ON jt.Guid = s.JobTypeGuid
    INNER JOIN SJob.MilestoneTypes mt ON mt.Guid = s.MilestoneTypeGuid
    WHERE s.RunGuid = @RunGuid;
    SET @cnt = @@ROWCOUNT;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'JobTypeMilestoneTemplates',N'Update',@cnt,N'';

    DECLARE cur_jtmt CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.JobTypeMilestoneTemplateGuid FROM SMigration.Onboarding_JobTypeMilestoneTemplates s
    LEFT JOIN SJob.JobTypeMilestoneTemplates t ON t.Guid = s.JobTypeMilestoneTemplateGuid
    WHERE s.RunGuid = @RunGuid AND t.ID IS NULL;
    OPEN cur_jtmt; FETCH NEXT FROM cur_jtmt INTO @Guid;
    SET @cnt = 0;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.UpsertDataObject @Guid=@Guid,@SchemeName=N'SJob',@ObjectName=N'JobTypeMilestoneTemplates',@IncludeDefaultSecurity=0,@IsInsert=@IsInsert OUTPUT;
        INSERT INTO SJob.JobTypeMilestoneTemplates (RowStatus, Guid, JobTypeID, MilestoneTypeID, Description, SortOrder)
        SELECT s.RowStatus, s.JobTypeMilestoneTemplateGuid, jt.ID, mt.ID, s.Description, s.SortOrder
        FROM SMigration.Onboarding_JobTypeMilestoneTemplates s
        INNER JOIN SJob.JobTypes jt ON jt.Guid = s.JobTypeGuid
        INNER JOIN SJob.MilestoneTypes mt ON mt.Guid = s.MilestoneTypeGuid
        WHERE s.RunGuid = @RunGuid AND s.JobTypeMilestoneTemplateGuid = @Guid
          AND NOT EXISTS (SELECT 1 FROM SJob.JobTypeMilestoneTemplates x WHERE x.RowStatus NOT IN (0,254) AND x.JobTypeID = jt.ID AND x.MilestoneTypeID = mt.ID AND x.SortOrder = s.SortOrder);
        SET @cnt += @@ROWCOUNT;
        FETCH NEXT FROM cur_jtmt INTO @Guid;
    END
    CLOSE cur_jtmt; DEALLOCATE cur_jtmt;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'JobTypeMilestoneTemplates',N'Insert',@cnt,N'';

    /* 13. Products */
    UPDATE t
       SET t.RowStatus = s.RowStatus, t.Code = s.Code, t.Description = s.Description, t.CreatedJobType = jt.ID,
           t.NeverConsolidate = s.NeverConsolidate, t.RibaStageId = rs.ID
    FROM SProd.Products t
    INNER JOIN SMigration.Onboarding_Products s ON s.ProductGuid = t.Guid
    INNER JOIN SJob.JobTypes jt ON jt.Guid = s.CreatedJobTypeGuid
    LEFT JOIN SJob.RibaStages rs ON rs.Guid = s.RibaStageGuid
    WHERE s.RunGuid = @RunGuid;
    SET @cnt = @@ROWCOUNT;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'Products',N'Update',@cnt,N'';

    DECLARE cur_prod CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.ProductGuid FROM SMigration.Onboarding_Products s
    LEFT JOIN SProd.Products t ON t.Guid = s.ProductGuid
    WHERE s.RunGuid = @RunGuid AND t.ID IS NULL;
    OPEN cur_prod; FETCH NEXT FROM cur_prod INTO @Guid;
    SET @cnt = 0;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.UpsertDataObject @Guid=@Guid,@SchemeName=N'SProd',@ObjectName=N'Products',@IncludeDefaultSecurity=0,@IsInsert=@IsInsert OUTPUT;
        INSERT INTO SProd.Products (RowStatus, Guid, Code, Description, CreatedJobType, NeverConsolidate, RibaStageId)
        SELECT s.RowStatus, s.ProductGuid, s.Code, s.Description, jt.ID, s.NeverConsolidate, rs.ID
        FROM SMigration.Onboarding_Products s
        INNER JOIN SJob.JobTypes jt ON jt.Guid = s.CreatedJobTypeGuid
        LEFT JOIN SJob.RibaStages rs ON rs.Guid = s.RibaStageGuid
        WHERE s.RunGuid = @RunGuid AND s.ProductGuid = @Guid;
        SET @cnt += @@ROWCOUNT;
        FETCH NEXT FROM cur_prod INTO @Guid;
    END
    CLOSE cur_prod; DEALLOCATE cur_prod;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'Products',N'Insert',@cnt,N'';

    /* 14. ProductJobActivities */
    UPDATE t
       SET t.RowStatus = s.RowStatus, t.ProductId = p.ID, t.JobTypeActivityTypeId = jtat.ID, t.ActivityTitle = s.ActivityTitle,
           t.OffsetDays = s.OffsetDays, t.OffsetWeeks = s.OffsetWeeks, t.OffsetMonths = s.OffsetMonths,
           t.JobTypeMilestoneTemplateId = ISNULL(jtmt.ID, -1), t.PercentageOfProductValue = s.PercentageOfProductValue
    FROM SJob.ProductJobActivities t
    INNER JOIN SMigration.Onboarding_ProductJobActivities s ON s.ProductJobActivityGuid = t.Guid
    INNER JOIN SProd.Products p ON p.Guid = s.ProductGuid
    INNER JOIN SJob.JobTypeActivityTypes jtat ON jtat.Guid = s.JobTypeActivityTypeGuid
    LEFT JOIN SJob.JobTypeMilestoneTemplates jtmt ON jtmt.Guid = s.JobTypeMilestoneTemplateGuid
    WHERE s.RunGuid = @RunGuid;
    SET @cnt = @@ROWCOUNT;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'ProductJobActivities',N'Update',@cnt,N'';

    DECLARE cur_pja CURSOR LOCAL FAST_FORWARD FOR
    SELECT s.ProductJobActivityGuid FROM SMigration.Onboarding_ProductJobActivities s
    LEFT JOIN SJob.ProductJobActivities t ON t.Guid = s.ProductJobActivityGuid
    WHERE s.RunGuid = @RunGuid AND t.ID IS NULL;
    OPEN cur_pja; FETCH NEXT FROM cur_pja INTO @Guid;
    SET @cnt = 0;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.UpsertDataObject @Guid=@Guid,@SchemeName=N'SJob',@ObjectName=N'ProductJobActivities',@IncludeDefaultSecurity=0,@IsInsert=@IsInsert OUTPUT;
        INSERT INTO SJob.ProductJobActivities
        (
            RowStatus, Guid, ProductId, JobTypeActivityTypeId, ActivityTitle,
            OffsetDays, OffsetWeeks, OffsetMonths, JobTypeMilestoneTemplateId, PercentageOfProductValue
        )
        SELECT
            s.RowStatus, s.ProductJobActivityGuid, p.ID, jtat.ID, s.ActivityTitle,
            s.OffsetDays, s.OffsetWeeks, s.OffsetMonths, ISNULL(jtmt.ID, -1), s.PercentageOfProductValue
        FROM SMigration.Onboarding_ProductJobActivities s
        INNER JOIN SProd.Products p ON p.Guid = s.ProductGuid
        INNER JOIN SJob.JobTypeActivityTypes jtat ON jtat.Guid = s.JobTypeActivityTypeGuid
        LEFT JOIN SJob.JobTypeMilestoneTemplates jtmt ON jtmt.Guid = s.JobTypeMilestoneTemplateGuid
        WHERE s.RunGuid = @RunGuid AND s.ProductJobActivityGuid = @Guid;
        SET @cnt += @@ROWCOUNT;
        FETCH NEXT FROM cur_pja INTO @Guid;
    END
    CLOSE cur_pja; DEALLOCATE cur_pja;
    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'ProductJobActivities',N'Insert',@cnt,N'';

    COMMIT TRAN;

    EXEC SMigration.OnboardingLog_Add @RunGuid,N'Import',N'All',N'Summary',0,N'Import complete.';
    EXEC SMigration.OnboardingReport @RunGuid = @RunGuid;
END
GO

/* ================================================================================================
   Example usage

DECLARE @RunGuid UNIQUEIDENTIFIER = NEWID();

EXEC SMigration.OnboardingStage_LoadFromSource
    @SourceDatabase = N'CymBuild_UAT',
    @BusinessUnitGroupGuid = '315CF5D4-37EB-4966-AB77-4CCAB627A613',
    @RunGuid = @RunGuid,
    @Notes = N'Onboarding promotion from UAT';

-- preview only
EXEC SMigration.OnboardingImport_Apply
    @RunGuid = @RunGuid,
    @AllowWarnings = 1,
    @PreviewOnly = 1;

-- apply
EXEC SMigration.OnboardingImport_Apply
    @RunGuid = @RunGuid,
    @AllowWarnings = 1,
    @PreviewOnly = 0;

EXEC SMigration.OnboardingReport @RunGuid = @RunGuid;

================================================================================================ */
