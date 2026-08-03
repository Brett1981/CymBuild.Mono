SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingReport_StagedData]')
GO
PRINT (N'Create procedure [SMigration].[OnboardingReport_StagedData]')
GO

/* ================================================================================================
   SMigration.OnboardingReport_StagedData
   Corrected against current SMigration staging schema.

   Output contract consumed by CoreService.OnboardingMigration.cs:
       EntityName NVARCHAR
       RowGuid    NVARCHAR(36)
       ValuesJson NVARCHAR(MAX) -- JSON object containing string values

   Notes:
   - Explicit columns only.
   - No SELECT *.
   - JSON values are cast to strings so the API can deserialize to Dictionary<string,string>.
   ================================================================================================ */
CREATE PROCEDURE [SMigration].[OnboardingReport_StagedData]
    @RunGuid UNIQUEIDENTIFIER,
    @EntityName NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    IF @EntityName = N'Groups'
    BEGIN
        SELECT
            EntityName = N'Groups',
            RowGuid = CONVERT(NVARCHAR(36), s.GroupGuid),
            ValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    s.DirectoryId,
                    s.Code,
                    s.Name,
                    s.Source,
                    CONVERT(NVARCHAR(5), s.IsBusinessUnitGroup) AS IsBusinessUnitGroup
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM SMigration.Onboarding_Groups AS s
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.Name, s.Code;
        RETURN;
    END;

    IF @EntityName = N'OrganisationalUnits'
    BEGIN
        SELECT
            EntityName = N'OrganisationalUnits',
            RowGuid = CONVERT(NVARCHAR(36), s.OrganisationalUnitGuid),
            ValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    s.Name,
                    ISNULL(CONVERT(NVARCHAR(36), s.ParentOrganisationalUnitGuid), N'') AS ParentOrganisationalUnitGuid,
                    CONVERT(NVARCHAR(36), s.AddressGuid) AS AddressGuid,
                    CONVERT(NVARCHAR(36), s.ContactGuid) AS ContactGuid,
                    CONVERT(NVARCHAR(36), s.OfficialAddressGuid) AS OfficialAddressGuid,
                    CONVERT(NVARCHAR(36), s.OfficialContactGuid) AS OfficialContactGuid,
                    s.DepartmentPrefix,
                    s.CostCentreCode,
                    CONVERT(NVARCHAR(36), s.DefaultSecurityGroupGuid) AS DefaultSecurityGroupGuid,
                    CONVERT(NVARCHAR(50), s.QuoteThreshold) AS QuoteThreshold,
                    CONVERT(NVARCHAR(20), s.OrgLevel) AS OrgLevel
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM SMigration.Onboarding_OrganisationalUnits AS s
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.OrgLevel, s.Name;
        RETURN;
    END;

    IF @EntityName = N'Addresses'
    BEGIN
        SELECT
            EntityName = N'Addresses',
            RowGuid = CONVERT(NVARCHAR(36), s.AddressGuid),
            ValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    CONVERT(NVARCHAR(50), s.AddressNumber) AS AddressNumber,
                    s.Name,
                    s.Number,
                    s.AddressLine1,
                    s.AddressLine2,
                    s.AddressLine3,
                    s.Town,
                    ISNULL(CONVERT(NVARCHAR(36), s.CountyGuid), N'') AS CountyGuid,
                    s.Postcode,
                    ISNULL(CONVERT(NVARCHAR(36), s.CountryGuid), N'') AS CountryGuid,
                    CONVERT(NVARCHAR(50), s.LegacySystemID) AS LegacySystemID
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM SMigration.Onboarding_Addresses AS s
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.Name, s.Postcode;
        RETURN;
    END;

    IF @EntityName = N'Contacts'
    BEGIN
        SELECT
            EntityName = N'Contacts',
            RowGuid = CONVERT(NVARCHAR(36), s.ContactGuid),
            ValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    ISNULL(CONVERT(NVARCHAR(36), s.PrimaryAccountGuid), N'') AS PrimaryAccountGuid,
                    CONVERT(NVARCHAR(36), s.PrimaryAddressGuid) AS PrimaryAddressGuid,
                    s.FirstName,
                    s.Initials,
                    s.Surname,
                    s.PostNominals,
                    ISNULL(CONVERT(NVARCHAR(36), s.TitleGuid), N'') AS TitleGuid,
                    s.DisplayName,
                    CONVERT(NVARCHAR(5), s.IsPerson) AS IsPerson,
                    ISNULL(CONVERT(NVARCHAR(36), s.PositionGuid), N'') AS PositionGuid,
                    CONVERT(NVARCHAR(50), s.LegacySystemID) AS LegacySystemID
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM SMigration.Onboarding_Contacts AS s
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.DisplayName, s.Surname, s.FirstName;
        RETURN;
    END;

    IF @EntityName = N'Identities'
    BEGIN
        SELECT
            EntityName = N'Identities',
            RowGuid = CONVERT(NVARCHAR(36), s.IdentityGuid),
            ValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    s.FullName,
                    s.EmailAddress,
                    CONVERT(NVARCHAR(36), s.UserGuid) AS UserGuid,
                    s.JobTitle,
                    CONVERT(NVARCHAR(36), s.OrganisationalUnitGuid) AS OrganisationalUnitGuid,
                    CONVERT(NVARCHAR(5), s.IsActive) AS IsActive,
                    CONVERT(NVARCHAR(36), s.ContactGuid) AS ContactGuid,
                    CONVERT(NVARCHAR(50), s.BillableRate) AS BillableRate
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM SMigration.Onboarding_Identities AS s
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.FullName, s.EmailAddress;
        RETURN;
    END;

    IF @EntityName = N'UserGroups'
    BEGIN
        SELECT
            EntityName = N'UserGroups',
            RowGuid = CONVERT(NVARCHAR(36), s.UserGroupGuid),
            ValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    CONVERT(NVARCHAR(36), s.IdentityGuid) AS IdentityGuid,
                    CONVERT(NVARCHAR(36), s.GroupGuid) AS GroupGuid
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM SMigration.Onboarding_UserGroups AS s
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.IdentityGuid, s.GroupGuid;
        RETURN;
    END;

    IF @EntityName = N'Workflows'
    BEGIN
        SELECT
            EntityName = N'Workflows',
            RowGuid = CONVERT(NVARCHAR(36), s.WorkflowGuid),
            ValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    s.Name,
                    ISNULL(CONVERT(NVARCHAR(36), s.OrganisationalUnitGuid), N'') AS OrganisationalUnitGuid,
                    ISNULL(CONVERT(NVARCHAR(36), s.EntityTypeGuid), N'') AS EntityTypeGuid,
                    ISNULL(CONVERT(NVARCHAR(36), s.EntityHoBTGuid), N'') AS EntityHoBTGuid,
                    ISNULL(s.Description, N'') AS Description,
                    CONVERT(NVARCHAR(5), ISNULL(s.Enabled, 0)) AS Enabled
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM SMigration.Onboarding_Workflows AS s
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.Name;
        RETURN;
    END;

    IF @EntityName = N'WorkflowStatuses'
    BEGIN
        SELECT
            EntityName = N'WorkflowStatuses',
            RowGuid = CONVERT(NVARCHAR(36), s.WorkflowStatusGuid),
            ValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    ISNULL(CONVERT(NVARCHAR(36), s.OrganisationalUnitGuid), N'') AS OrganisationalUnitGuid,
                    s.Name,
                    s.Description,
                    CONVERT(NVARCHAR(5), s.ShowInEnquiries) AS ShowInEnquiries,
                    CONVERT(NVARCHAR(5), s.ShowInQuotes) AS ShowInQuotes,
                    CONVERT(NVARCHAR(5), s.ShowInJobs) AS ShowInJobs,
                    CONVERT(NVARCHAR(5), s.Enabled) AS Enabled,
                    CONVERT(NVARCHAR(5), s.IsPredefined) AS IsPredefined,
                    CONVERT(NVARCHAR(20), s.SortOrder) AS SortOrder,
                    s.Colour,
                    ISNULL(s.Icon, N'') AS Icon,
                    CONVERT(NVARCHAR(5), s.SendNotification) AS SendNotification,
                    CONVERT(NVARCHAR(5), s.IsCompleteStatus) AS IsCompleteStatus,
                    CONVERT(NVARCHAR(5), s.IsCustomerWaitingStatus) AS IsCustomerWaitingStatus,
                    CONVERT(NVARCHAR(5), s.RequiresUsersAction) AS RequiresUsersAction,
                    CONVERT(NVARCHAR(5), s.IsActiveStatus) AS IsActiveStatus,
                    CONVERT(NVARCHAR(5), s.AuthorisationNeeded) AS AuthorisationNeeded,
                    CONVERT(NVARCHAR(5), s.IsAuthStatus) AS IsAuthStatus
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM SMigration.Onboarding_WorkflowStatuses AS s
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.SortOrder, s.Name;
        RETURN;
    END;

    IF @EntityName = N'WorkflowTransitions'
    BEGIN
        SELECT
            EntityName = N'WorkflowTransitions',
            RowGuid = CONVERT(NVARCHAR(36), s.WorkflowTransitionGuid),
            ValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    CONVERT(NVARCHAR(36), s.WorkflowGuid) AS WorkflowGuid,
                    CONVERT(NVARCHAR(36), s.FromStatusGuid) AS FromStatusGuid,
                    CONVERT(NVARCHAR(36), s.ToStatusGuid) AS ToStatusGuid,
                    CONVERT(NVARCHAR(5), s.IsFinal) AS IsFinal,
                    CONVERT(NVARCHAR(5), s.Enabled) AS Enabled,
                    CONVERT(NVARCHAR(20), s.SortOrder) AS SortOrder,
                    s.Description
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM SMigration.Onboarding_WorkflowTransitions AS s
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.WorkflowGuid, s.SortOrder, s.Description;
        RETURN;
    END;

    IF @EntityName = N'WorkflowStatusNotificationGroups'
    BEGIN
        SELECT
            EntityName = N'WorkflowStatusNotificationGroups',
            RowGuid = CONVERT(NVARCHAR(36), s.WorkflowNotificationGroupGuid),
            ValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    CONVERT(NVARCHAR(36), s.WorkflowGuid) AS WorkflowGuid,
                    CONVERT(NVARCHAR(36), s.WorkflowStatusGuid) AS WorkflowStatusGuid,
                    CONVERT(NVARCHAR(36), s.GroupGuid) AS GroupGuid,
                    CONVERT(NVARCHAR(5), s.CanAction) AS CanAction
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM SMigration.Onboarding_WorkflowStatusNotificationGroups AS s
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.WorkflowGuid, s.GroupGuid;
        RETURN;
    END;

    IF @EntityName = N'JobTypes'
    BEGIN
        SELECT
            EntityName = N'JobTypes',
            RowGuid = CONVERT(NVARCHAR(36), s.JobTypeGuid),
            ValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    s.Name,
                    CONVERT(NVARCHAR(5), s.IsActive) AS IsActive,
                    CONVERT(NVARCHAR(20), s.SequenceID) AS SequenceID,
                    CONVERT(NVARCHAR(5), s.UseTimeSheets) AS UseTimeSheets,
                    CONVERT(NVARCHAR(5), s.UsePlanChecks) AS UsePlanChecks,
                    CONVERT(NVARCHAR(36), s.OrganisationalUnitGuid) AS OrganisationalUnitGuid
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM SMigration.Onboarding_JobTypes AS s
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.SequenceID, s.Name;
        RETURN;
    END;

    IF @EntityName = N'ActivityTypes'
    BEGIN
        SELECT
            EntityName = N'ActivityTypes',
            RowGuid = CONVERT(NVARCHAR(36), s.ActivityTypeGuid),
            ValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    s.Name,
                    CONVERT(NVARCHAR(5), s.IsActive) AS IsActive,
                    CONVERT(NVARCHAR(20), s.SortOrder) AS SortOrder,
                    CONVERT(NVARCHAR(5), s.IsFeeTrigger) AS IsFeeTrigger,
                    CONVERT(NVARCHAR(5), s.IsLiveTrigger) AS IsLiveTrigger,
                    CONVERT(NVARCHAR(5), s.IsAdmin) AS IsAdmin,
                    CONVERT(NVARCHAR(5), s.IsScheduleItem) AS IsScheduleItem,
                    s.Colour,
                    CONVERT(NVARCHAR(5), s.IsMeeting) AS IsMeeting,
                    CONVERT(NVARCHAR(5), s.IsSiteVisit) AS IsSiteVisit,
                    CONVERT(NVARCHAR(5), s.IsBillable) AS IsBillable,
                    CONVERT(NVARCHAR(5), s.IsCommencementTrigger) AS IsCommencementTrigger
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM SMigration.Onboarding_ActivityTypes AS s
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.SortOrder, s.Name;
        RETURN;
    END;

    IF @EntityName = N'MilestoneTypes'
    BEGIN
        SELECT
            EntityName = N'MilestoneTypes',
            RowGuid = CONVERT(NVARCHAR(36), s.MilestoneTypeGuid),
            ValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    s.Code,
                    s.Name,
                    CONVERT(NVARCHAR(5), s.IsActive) AS IsActive,
                    CONVERT(NVARCHAR(5), s.IsInvoiceTrigger) AS IsInvoiceTrigger,
                    CONVERT(NVARCHAR(5), s.IsReviewRequired) AS IsReviewRequired,
                    s.HelpText,
                    CONVERT(NVARCHAR(5), s.HasQuotedHours) AS HasQuotedHours,
                    CONVERT(NVARCHAR(5), s.HasDescription) AS HasDescription,
                    CONVERT(NVARCHAR(5), s.HasReference) AS HasReference,
                    CONVERT(NVARCHAR(5), s.IsCompulsory) AS IsCompulsory,
                    CONVERT(NVARCHAR(5), s.IncludeStart) AS IncludeStart,
                    CONVERT(NVARCHAR(5), s.IncludeSchedule) AS IncludeSchedule,
                    CONVERT(NVARCHAR(5), s.IncludeDueDate) AS IncludeDueDate,
                    CONVERT(NVARCHAR(5), s.HasExternalSubmission) AS HasExternalSubmission
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM SMigration.Onboarding_MilestoneTypes AS s
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.Code, s.Name;
        RETURN;
    END;

    IF @EntityName = N'JobTypeActivityTypes'
    BEGIN
        SELECT
            EntityName = N'JobTypeActivityTypes',
            RowGuid = CONVERT(NVARCHAR(36), s.JobTypeActivityTypeGuid),
            ValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    CONVERT(NVARCHAR(36), s.JobTypeGuid) AS JobTypeGuid,
                    CONVERT(NVARCHAR(36), s.ActivityTypeGuid) AS ActivityTypeGuid
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM SMigration.Onboarding_JobTypeActivityTypes AS s
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.JobTypeGuid, s.ActivityTypeGuid;
        RETURN;
    END;

    IF @EntityName = N'JobTypeMilestoneTemplates'
    BEGIN
        SELECT
            EntityName = N'JobTypeMilestoneTemplates',
            RowGuid = CONVERT(NVARCHAR(36), s.JobTypeMilestoneTemplateGuid),
            ValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    CONVERT(NVARCHAR(36), s.JobTypeGuid) AS JobTypeGuid,
                    CONVERT(NVARCHAR(36), s.MilestoneTypeGuid) AS MilestoneTypeGuid,
                    s.Description,
                    CONVERT(NVARCHAR(20), s.SortOrder) AS SortOrder
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM SMigration.Onboarding_JobTypeMilestoneTemplates AS s
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.JobTypeGuid, s.SortOrder, s.MilestoneTypeGuid;
        RETURN;
    END;

    IF @EntityName = N'Products'
    BEGIN
        SELECT
            EntityName = N'Products',
            RowGuid = CONVERT(NVARCHAR(36), s.ProductGuid),
            ValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    s.Code,
                    s.Description,
                    CONVERT(NVARCHAR(36), s.CreatedJobTypeGuid) AS CreatedJobTypeGuid,
                    CONVERT(NVARCHAR(5), s.NeverConsolidate) AS NeverConsolidate,
                    ISNULL(CONVERT(NVARCHAR(36), s.RibaStageGuid), N'') AS RibaStageGuid
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM SMigration.Onboarding_Products AS s
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.Code, s.Description;
        RETURN;
    END;

    IF @EntityName = N'ProductJobActivities'
    BEGIN
        SELECT
            EntityName = N'ProductJobActivities',
            RowGuid = CONVERT(NVARCHAR(36), s.ProductJobActivityGuid),
            ValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    CONVERT(NVARCHAR(36), s.ProductGuid) AS ProductGuid,
                    CONVERT(NVARCHAR(36), s.JobTypeActivityTypeGuid) AS JobTypeActivityTypeGuid,
                    s.ActivityTitle,
                    CONVERT(NVARCHAR(20), s.OffsetDays) AS OffsetDays,
                    CONVERT(NVARCHAR(20), s.OffsetWeeks) AS OffsetWeeks,
                    CONVERT(NVARCHAR(20), s.OffsetMonths) AS OffsetMonths,
                    ISNULL(CONVERT(NVARCHAR(36), s.JobTypeMilestoneTemplateGuid), N'') AS JobTypeMilestoneTemplateGuid,
                    CONVERT(NVARCHAR(50), s.PercentageOfProductValue) AS PercentageOfProductValue
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            )
        FROM SMigration.Onboarding_ProductJobActivities AS s
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.ProductGuid, s.JobTypeActivityTypeGuid, s.ActivityTitle;
        RETURN;
    END;

    ;THROW 60000, N'Unsupported entity name passed to SMigration.OnboardingReport_StagedData.', 1;
END;

GO