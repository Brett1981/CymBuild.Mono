SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingDiff_Report]')
GO



/* ================================================================================================
   SMigration.OnboardingDiff_Report
   Corrected against current SMigration staging schema and current import mapping.

   Output contract consumed by CoreService.OnboardingMigration.cs:
       EntityName             NVARCHAR
       RowGuid                NVARCHAR(36)
       DiffType               NVARCHAR -- MissingInTarget / Same / Different
       SourceValuesJson       NVARCHAR(MAX) -- JSON object containing string values
       TargetValuesJson       NVARCHAR(MAX) -- JSON object containing string values
       DifferingColumnsJson   NVARCHAR(MAX) -- JSON array of strings

   Notes:
   - Explicit columns only.
   - No SELECT *.
   - Compares meaningful business/config columns only.
   - Resolves target FK IDs back to target GUIDs.
   ================================================================================================ */
PRINT (N'Create procedure [SMigration].[OnboardingDiff_Report]')
GO
PRINT (N'Create procedure [SMigration].[OnboardingDiff_Report]')
GO



/* ================================================================================================
   SMigration.OnboardingDiff_Report
   Corrected against current SMigration staging schema and current import mapping.

   Output contract consumed by CoreService.OnboardingMigration.cs:
       EntityName             NVARCHAR
       RowGuid                NVARCHAR(36)
       DiffType               NVARCHAR -- MissingInTarget / Same / Different
       SourceValuesJson       NVARCHAR(MAX) -- JSON object containing string values
       TargetValuesJson       NVARCHAR(MAX) -- JSON object containing string values
       DifferingColumnsJson   NVARCHAR(MAX) -- JSON array of strings

   Notes:
   - Explicit columns only.
   - No SELECT *.
   - Compares meaningful business/config columns only.
   - Resolves target FK IDs back to target GUIDs.
   ================================================================================================ */
CREATE PROCEDURE [SMigration].[OnboardingDiff_Report]
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
            DiffType =
                CASE
                    WHEN t.ID IS NULL THEN N'MissingInTarget'
                    WHEN ISNULL(t.RowStatus, 255) = s.RowStatus
                     AND ISNULL(t.DirectoryId, N'') = s.DirectoryId
                     AND ISNULL(t.Code, N'') = s.Code
                     AND ISNULL(t.Name, N'') = s.Name
                     AND ISNULL(t.Source, N'') = s.Source
                    THEN N'Same'
                    ELSE N'Different'
                END,
            SourceValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    s.DirectoryId,
                    s.Code,
                    s.Name,
                    s.Source
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            TargetValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), ISNULL(t.RowStatus, 255)) AS RowStatus,
                    ISNULL(t.DirectoryId, N'') AS DirectoryId,
                    ISNULL(t.Code, N'') AS Code,
                    ISNULL(t.Name, N'') AS Name,
                    ISNULL(t.Source, N'') AS Source
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            DifferingColumnsJson = COALESCE
            (
                (
                    SELECT N'[' + STRING_AGG(N'"' + STRING_ESCAPE(d.ColumnName, 'json') + N'"', N',') + N']'
                    FROM
                    (
                        VALUES
                            (CASE WHEN ISNULL(t.RowStatus, 255) <> s.RowStatus THEN N'RowStatus' END),
                            (CASE WHEN ISNULL(t.DirectoryId, N'') <> s.DirectoryId THEN N'DirectoryId' END),
                            (CASE WHEN ISNULL(t.Code, N'') <> s.Code THEN N'Code' END),
                            (CASE WHEN ISNULL(t.Name, N'') <> s.Name THEN N'Name' END),
                            (CASE WHEN ISNULL(t.Source, N'') <> s.Source THEN N'Source' END)
                    ) AS d(ColumnName)
                    WHERE d.ColumnName IS NOT NULL
                ),
                N'[]'
            )
        FROM SMigration.Onboarding_Groups AS s
        LEFT JOIN SCore.Groups AS t
            ON t.Guid = s.GroupGuid
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.Name, s.Code;
        RETURN;
    END;

    IF @EntityName = N'OrganisationalUnits'
    BEGIN
        SELECT
            EntityName = N'OrganisationalUnits',
            RowGuid = CONVERT(NVARCHAR(36), s.OrganisationalUnitGuid),
            DiffType =
                CASE
                    WHEN t.ID IS NULL THEN N'MissingInTarget'
                    WHEN ISNULL(t.RowStatus, 255) = s.RowStatus
                     AND ISNULL(t.Name, N'') = s.Name
                     AND ISNULL(parent.Guid, '00000000-0000-0000-0000-000000000000') = ISNULL(s.ParentOrganisationalUnitGuid, '00000000-0000-0000-0000-000000000000')
                     AND ISNULL(addr.Guid, '00000000-0000-0000-0000-000000000000') = s.AddressGuid
                     AND ISNULL(contact.Guid, '00000000-0000-0000-0000-000000000000') = s.ContactGuid
                     AND ISNULL(officialAddr.Guid, '00000000-0000-0000-0000-000000000000') = s.OfficialAddressGuid
                     AND ISNULL(officialContact.Guid, '00000000-0000-0000-0000-000000000000') = s.OfficialContactGuid
                     AND ISNULL(t.DepartmentPrefix, N'') = s.DepartmentPrefix
                     AND ISNULL(t.CostCentreCode, N'') = s.CostCentreCode
                     AND ISNULL(g.Guid, '00000000-0000-0000-0000-000000000000') = s.DefaultSecurityGroupGuid
                     AND ISNULL(t.QuoteThreshold, 0) = s.QuoteThreshold
                    THEN N'Same'
                    ELSE N'Different'
                END,
            SourceValuesJson =
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
                    CONVERT(NVARCHAR(50), s.QuoteThreshold) AS QuoteThreshold
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            TargetValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), ISNULL(t.RowStatus, 255)) AS RowStatus,
                    ISNULL(t.Name, N'') AS Name,
                    ISNULL(CONVERT(NVARCHAR(36), parent.Guid), N'') AS ParentOrganisationalUnitGuid,
                    ISNULL(CONVERT(NVARCHAR(36), addr.Guid), N'') AS AddressGuid,
                    ISNULL(CONVERT(NVARCHAR(36), contact.Guid), N'') AS ContactGuid,
                    ISNULL(CONVERT(NVARCHAR(36), officialAddr.Guid), N'') AS OfficialAddressGuid,
                    ISNULL(CONVERT(NVARCHAR(36), officialContact.Guid), N'') AS OfficialContactGuid,
                    ISNULL(t.DepartmentPrefix, N'') AS DepartmentPrefix,
                    ISNULL(t.CostCentreCode, N'') AS CostCentreCode,
                    ISNULL(CONVERT(NVARCHAR(36), g.Guid), N'') AS DefaultSecurityGroupGuid,
                    CONVERT(NVARCHAR(50), ISNULL(t.QuoteThreshold, 0)) AS QuoteThreshold
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            DifferingColumnsJson = COALESCE
            (
                (
                    SELECT N'[' + STRING_AGG(N'"' + STRING_ESCAPE(d.ColumnName, 'json') + N'"', N',') + N']'
                    FROM
                    (
                        VALUES
                            (CASE WHEN ISNULL(t.RowStatus, 255) <> s.RowStatus THEN N'RowStatus' END),
                            (CASE WHEN ISNULL(t.Name, N'') <> s.Name THEN N'Name' END),
                            (CASE WHEN ISNULL(parent.Guid, '00000000-0000-0000-0000-000000000000') <> ISNULL(s.ParentOrganisationalUnitGuid, '00000000-0000-0000-0000-000000000000') THEN N'ParentOrganisationalUnitGuid' END),
                            (CASE WHEN ISNULL(addr.Guid, '00000000-0000-0000-0000-000000000000') <> s.AddressGuid THEN N'AddressGuid' END),
                            (CASE WHEN ISNULL(contact.Guid, '00000000-0000-0000-0000-000000000000') <> s.ContactGuid THEN N'ContactGuid' END),
                            (CASE WHEN ISNULL(officialAddr.Guid, '00000000-0000-0000-0000-000000000000') <> s.OfficialAddressGuid THEN N'OfficialAddressGuid' END),
                            (CASE WHEN ISNULL(officialContact.Guid, '00000000-0000-0000-0000-000000000000') <> s.OfficialContactGuid THEN N'OfficialContactGuid' END),
                            (CASE WHEN ISNULL(t.DepartmentPrefix, N'') <> s.DepartmentPrefix THEN N'DepartmentPrefix' END),
                            (CASE WHEN ISNULL(t.CostCentreCode, N'') <> s.CostCentreCode THEN N'CostCentreCode' END),
                            (CASE WHEN ISNULL(g.Guid, '00000000-0000-0000-0000-000000000000') <> s.DefaultSecurityGroupGuid THEN N'DefaultSecurityGroupGuid' END),
                            (CASE WHEN ISNULL(t.QuoteThreshold, 0) <> s.QuoteThreshold THEN N'QuoteThreshold' END)
                    ) AS d(ColumnName)
                    WHERE d.ColumnName IS NOT NULL
                ),
                N'[]'
            )
        FROM SMigration.Onboarding_OrganisationalUnits AS s
        LEFT JOIN SCore.OrganisationalUnits AS t
            ON t.Guid = s.OrganisationalUnitGuid
        LEFT JOIN SCore.OrganisationalUnits AS parent
            ON parent.ID = t.ParentID
        LEFT JOIN SCrm.Addresses AS addr
            ON addr.ID = t.AddressId
        LEFT JOIN SCrm.Contacts AS contact
            ON contact.ID = t.ContactId
        LEFT JOIN SCrm.Addresses AS officialAddr
            ON officialAddr.ID = t.OfficialAddressId
        LEFT JOIN SCrm.Contacts AS officialContact
            ON officialContact.ID = t.OfficialContactId
        LEFT JOIN SCore.Groups AS g
            ON g.ID = t.DefaultSecurityGroupId
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.OrgLevel, s.Name;
        RETURN;
    END;

    IF @EntityName = N'Addresses'
    BEGIN
        SELECT
            EntityName = N'Addresses',
            RowGuid = CONVERT(NVARCHAR(36), s.AddressGuid),
            DiffType =
                CASE
                    WHEN t.ID IS NULL THEN N'MissingInTarget'
                    WHEN ISNULL(t.RowStatus, 255) = s.RowStatus
                     AND ISNULL(t.AddressNumber, -1) = s.AddressNumber
                     AND ISNULL(t.Name, N'') = s.Name
                     AND ISNULL(t.Number, N'') = s.Number
                     AND ISNULL(t.AddressLine1, N'') = s.AddressLine1
                     AND ISNULL(t.AddressLine2, N'') = s.AddressLine2
                     AND ISNULL(t.AddressLine3, N'') = s.AddressLine3
                     AND ISNULL(t.Town, N'') = s.Town
                     AND ISNULL(county.Guid, '00000000-0000-0000-0000-000000000000') = ISNULL(s.CountyGuid, '00000000-0000-0000-0000-000000000000')
                     AND ISNULL(t.Postcode, N'') = s.Postcode
                     AND ISNULL(country.Guid, '00000000-0000-0000-0000-000000000000') = ISNULL(s.CountryGuid, '00000000-0000-0000-0000-000000000000')
                     AND ISNULL(t.LegacySystemID, -1) = s.LegacySystemID
                    THEN N'Same'
                    ELSE N'Different'
                END,
            SourceValuesJson =
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
            ),
            TargetValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), ISNULL(t.RowStatus, 255)) AS RowStatus,
                    CONVERT(NVARCHAR(50), ISNULL(t.AddressNumber, -1)) AS AddressNumber,
                    ISNULL(t.Name, N'') AS Name,
                    ISNULL(t.Number, N'') AS Number,
                    ISNULL(t.AddressLine1, N'') AS AddressLine1,
                    ISNULL(t.AddressLine2, N'') AS AddressLine2,
                    ISNULL(t.AddressLine3, N'') AS AddressLine3,
                    ISNULL(t.Town, N'') AS Town,
                    ISNULL(CONVERT(NVARCHAR(36), county.Guid), N'') AS CountyGuid,
                    ISNULL(t.Postcode, N'') AS Postcode,
                    ISNULL(CONVERT(NVARCHAR(36), country.Guid), N'') AS CountryGuid,
                    CONVERT(NVARCHAR(50), ISNULL(t.LegacySystemID, -1)) AS LegacySystemID
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            DifferingColumnsJson = COALESCE
            (
                (
                    SELECT N'[' + STRING_AGG(N'"' + STRING_ESCAPE(d.ColumnName, 'json') + N'"', N',') + N']'
                    FROM
                    (
                        VALUES
                            (CASE WHEN ISNULL(t.RowStatus, 255) <> s.RowStatus THEN N'RowStatus' END),
                            (CASE WHEN ISNULL(t.AddressNumber, -1) <> s.AddressNumber THEN N'AddressNumber' END),
                            (CASE WHEN ISNULL(t.Name, N'') <> s.Name THEN N'Name' END),
                            (CASE WHEN ISNULL(t.Number, N'') <> s.Number THEN N'Number' END),
                            (CASE WHEN ISNULL(t.AddressLine1, N'') <> s.AddressLine1 THEN N'AddressLine1' END),
                            (CASE WHEN ISNULL(t.AddressLine2, N'') <> s.AddressLine2 THEN N'AddressLine2' END),
                            (CASE WHEN ISNULL(t.AddressLine3, N'') <> s.AddressLine3 THEN N'AddressLine3' END),
                            (CASE WHEN ISNULL(t.Town, N'') <> s.Town THEN N'Town' END),
                            (CASE WHEN ISNULL(county.Guid, '00000000-0000-0000-0000-000000000000') <> ISNULL(s.CountyGuid, '00000000-0000-0000-0000-000000000000') THEN N'CountyGuid' END),
                            (CASE WHEN ISNULL(t.Postcode, N'') <> s.Postcode THEN N'Postcode' END),
                            (CASE WHEN ISNULL(country.Guid, '00000000-0000-0000-0000-000000000000') <> ISNULL(s.CountryGuid, '00000000-0000-0000-0000-000000000000') THEN N'CountryGuid' END),
                            (CASE WHEN ISNULL(t.LegacySystemID, -1) <> s.LegacySystemID THEN N'LegacySystemID' END)
                    ) AS d(ColumnName)
                    WHERE d.ColumnName IS NOT NULL
                ),
                N'[]'
            )
        FROM SMigration.Onboarding_Addresses AS s
        LEFT JOIN SCrm.Addresses AS t
            ON t.Guid = s.AddressGuid
        LEFT JOIN SCrm.Counties AS county
            ON county.ID = t.CountyID
        LEFT JOIN SCrm.Countries AS country
            ON country.ID = t.CountryID
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.Name, s.Postcode;
        RETURN;
    END;

    IF @EntityName = N'Contacts'
    BEGIN
        SELECT
            EntityName = N'Contacts',
            RowGuid = CONVERT(NVARCHAR(36), s.ContactGuid),
            DiffType =
                CASE
                    WHEN t.ID IS NULL THEN N'MissingInTarget'
                    WHEN ISNULL(t.RowStatus, 255) = s.RowStatus
                     AND ISNULL(account.Guid, '00000000-0000-0000-0000-000000000000') = ISNULL(s.PrimaryAccountGuid, '00000000-0000-0000-0000-000000000000')
                     AND ISNULL(address.Guid, '00000000-0000-0000-0000-000000000000') = s.PrimaryAddressGuid
                     AND ISNULL(t.FirstName, N'') = s.FirstName
                     AND ISNULL(t.Initials, N'') = s.Initials
                     AND ISNULL(t.Surname, N'') = s.Surname
                     AND ISNULL(t.PostNominals, N'') = s.PostNominals
                     AND ISNULL(title.Guid, '00000000-0000-0000-0000-000000000000') = ISNULL(s.TitleGuid, '00000000-0000-0000-0000-000000000000')
                     AND ISNULL(t.DisplayName, N'') = s.DisplayName
                     AND ISNULL(t.IsPerson, 0) = s.IsPerson
                     AND ISNULL(position.Guid, '00000000-0000-0000-0000-000000000000') = ISNULL(s.PositionGuid, '00000000-0000-0000-0000-000000000000')
                     AND ISNULL(t.LegacySystemID, -1) = s.LegacySystemID
                    THEN N'Same'
                    ELSE N'Different'
                END,
            SourceValuesJson =
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
            ),
            TargetValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), ISNULL(t.RowStatus, 255)) AS RowStatus,
                    ISNULL(CONVERT(NVARCHAR(36), account.Guid), N'') AS PrimaryAccountGuid,
                    ISNULL(CONVERT(NVARCHAR(36), address.Guid), N'') AS PrimaryAddressGuid,
                    ISNULL(t.FirstName, N'') AS FirstName,
                    ISNULL(t.Initials, N'') AS Initials,
                    ISNULL(t.Surname, N'') AS Surname,
                    ISNULL(t.PostNominals, N'') AS PostNominals,
                    ISNULL(CONVERT(NVARCHAR(36), title.Guid), N'') AS TitleGuid,
                    ISNULL(t.DisplayName, N'') AS DisplayName,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsPerson, 0)) AS IsPerson,
                    ISNULL(CONVERT(NVARCHAR(36), position.Guid), N'') AS PositionGuid,
                    CONVERT(NVARCHAR(50), ISNULL(t.LegacySystemID, -1)) AS LegacySystemID
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            DifferingColumnsJson = COALESCE
            (
                (
                    SELECT N'[' + STRING_AGG(N'"' + STRING_ESCAPE(d.ColumnName, 'json') + N'"', N',') + N']'
                    FROM
                    (
                        VALUES
                            (CASE WHEN ISNULL(t.RowStatus, 255) <> s.RowStatus THEN N'RowStatus' END),
                            (CASE WHEN ISNULL(account.Guid, '00000000-0000-0000-0000-000000000000') <> ISNULL(s.PrimaryAccountGuid, '00000000-0000-0000-0000-000000000000') THEN N'PrimaryAccountGuid' END),
                            (CASE WHEN ISNULL(address.Guid, '00000000-0000-0000-0000-000000000000') <> s.PrimaryAddressGuid THEN N'PrimaryAddressGuid' END),
                            (CASE WHEN ISNULL(t.FirstName, N'') <> s.FirstName THEN N'FirstName' END),
                            (CASE WHEN ISNULL(t.Initials, N'') <> s.Initials THEN N'Initials' END),
                            (CASE WHEN ISNULL(t.Surname, N'') <> s.Surname THEN N'Surname' END),
                            (CASE WHEN ISNULL(t.PostNominals, N'') <> s.PostNominals THEN N'PostNominals' END),
                            (CASE WHEN ISNULL(title.Guid, '00000000-0000-0000-0000-000000000000') <> ISNULL(s.TitleGuid, '00000000-0000-0000-0000-000000000000') THEN N'TitleGuid' END),
                            (CASE WHEN ISNULL(t.DisplayName, N'') <> s.DisplayName THEN N'DisplayName' END),
                            (CASE WHEN ISNULL(t.IsPerson, 0) <> s.IsPerson THEN N'IsPerson' END),
                            (CASE WHEN ISNULL(position.Guid, '00000000-0000-0000-0000-000000000000') <> ISNULL(s.PositionGuid, '00000000-0000-0000-0000-000000000000') THEN N'PositionGuid' END),
                            (CASE WHEN ISNULL(t.LegacySystemID, -1) <> s.LegacySystemID THEN N'LegacySystemID' END)
                    ) AS d(ColumnName)
                    WHERE d.ColumnName IS NOT NULL
                ),
                N'[]'
            )
        FROM SMigration.Onboarding_Contacts AS s
        LEFT JOIN SCrm.Contacts AS t
            ON t.Guid = s.ContactGuid
        LEFT JOIN SCrm.Accounts AS account
            ON account.ID = t.PrimaryAccountID
        LEFT JOIN SCrm.Addresses AS address
            ON address.ID = t.PrimaryAddressID
        LEFT JOIN SCrm.ContactTitles AS title
            ON title.ID = t.TitleId
        LEFT JOIN SCrm.ContactPositions AS position
            ON position.ID = t.PositionID
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.DisplayName, s.Surname, s.FirstName;
        RETURN;
    END;

    IF @EntityName = N'Identities'
    BEGIN
        SELECT
            EntityName = N'Identities',
            RowGuid = CONVERT(NVARCHAR(36), s.IdentityGuid),
            DiffType =
                CASE
                    WHEN t.ID IS NULL THEN N'MissingInTarget'
                    WHEN ISNULL(t.RowStatus, 255) = s.RowStatus
                     AND ISNULL(t.FullName, N'') = s.FullName
                     AND ISNULL(t.EmailAddress, N'') = s.EmailAddress
                     AND ISNULL(t.UserGuid, '00000000-0000-0000-0000-000000000000') = s.UserGuid
                     AND ISNULL(t.JobTitle, N'') = s.JobTitle
                     AND ISNULL(ou.Guid, '00000000-0000-0000-0000-000000000000') = s.OrganisationalUnitGuid
                     AND ISNULL(t.IsActive, 1) = s.IsActive
                     AND ISNULL(contact.Guid, '00000000-0000-0000-0000-000000000000') = s.ContactGuid
                     AND ISNULL(t.BillableRate, 0) = s.BillableRate
                    THEN N'Same'
                    ELSE N'Different'
                END,
            SourceValuesJson =
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
            ),
            TargetValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), ISNULL(t.RowStatus, 255)) AS RowStatus,
                    ISNULL(t.FullName, N'') AS FullName,
                    ISNULL(t.EmailAddress, N'') AS EmailAddress,
                    ISNULL(CONVERT(NVARCHAR(36), t.UserGuid), N'') AS UserGuid,
                    ISNULL(t.JobTitle, N'') AS JobTitle,
                    ISNULL(CONVERT(NVARCHAR(36), ou.Guid), N'') AS OrganisationalUnitGuid,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsActive, 1)) AS IsActive,
                    ISNULL(CONVERT(NVARCHAR(36), contact.Guid), N'') AS ContactGuid,
                    CONVERT(NVARCHAR(50), ISNULL(t.BillableRate, 0)) AS BillableRate
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            DifferingColumnsJson = COALESCE
            (
                (
                    SELECT N'[' + STRING_AGG(N'"' + STRING_ESCAPE(d.ColumnName, 'json') + N'"', N',') + N']'
                    FROM
                    (
                        VALUES
                            (CASE WHEN ISNULL(t.RowStatus, 255) <> s.RowStatus THEN N'RowStatus' END),
                            (CASE WHEN ISNULL(t.FullName, N'') <> s.FullName THEN N'FullName' END),
                            (CASE WHEN ISNULL(t.EmailAddress, N'') <> s.EmailAddress THEN N'EmailAddress' END),
                            (CASE WHEN ISNULL(t.UserGuid, '00000000-0000-0000-0000-000000000000') <> s.UserGuid THEN N'UserGuid' END),
                            (CASE WHEN ISNULL(t.JobTitle, N'') <> s.JobTitle THEN N'JobTitle' END),
                            (CASE WHEN ISNULL(ou.Guid, '00000000-0000-0000-0000-000000000000') <> s.OrganisationalUnitGuid THEN N'OrganisationalUnitGuid' END),
                            (CASE WHEN ISNULL(t.IsActive, 1) <> s.IsActive THEN N'IsActive' END),
                            (CASE WHEN ISNULL(contact.Guid, '00000000-0000-0000-0000-000000000000') <> s.ContactGuid THEN N'ContactGuid' END),
                            (CASE WHEN ISNULL(t.BillableRate, 0) <> s.BillableRate THEN N'BillableRate' END)
                    ) AS d(ColumnName)
                    WHERE d.ColumnName IS NOT NULL
                ),
                N'[]'
            )
        FROM SMigration.Onboarding_Identities AS s
        LEFT JOIN SCore.Identities AS t
            ON t.Guid = s.IdentityGuid
        LEFT JOIN SCore.OrganisationalUnits AS ou
            ON ou.ID = t.OriganisationalUnitId
        LEFT JOIN SCrm.Contacts AS contact
            ON contact.ID = t.ContactId
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.FullName, s.EmailAddress;
        RETURN;
    END;

    IF @EntityName = N'UserGroups'
    BEGIN
        SELECT
            EntityName = N'UserGroups',
            RowGuid = CONVERT(NVARCHAR(36), s.UserGroupGuid),
            DiffType =
                CASE
                    WHEN t.ID IS NULL THEN N'MissingInTarget'
                    WHEN ISNULL(t.RowStatus, 255) = s.RowStatus
                     AND ISNULL(identityTarget.Guid, '00000000-0000-0000-0000-000000000000') = s.IdentityGuid
                     AND ISNULL(groupTarget.Guid, '00000000-0000-0000-0000-000000000000') = s.GroupGuid
                    THEN N'Same'
                    ELSE N'Different'
                END,
            SourceValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    CONVERT(NVARCHAR(36), s.IdentityGuid) AS IdentityGuid,
                    CONVERT(NVARCHAR(36), s.GroupGuid) AS GroupGuid
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            TargetValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), ISNULL(t.RowStatus, 255)) AS RowStatus,
                    ISNULL(CONVERT(NVARCHAR(36), identityTarget.Guid), N'') AS IdentityGuid,
                    ISNULL(CONVERT(NVARCHAR(36), groupTarget.Guid), N'') AS GroupGuid
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            DifferingColumnsJson = COALESCE
            (
                (
                    SELECT N'[' + STRING_AGG(N'"' + STRING_ESCAPE(d.ColumnName, 'json') + N'"', N',') + N']'
                    FROM
                    (
                        VALUES
                            (CASE WHEN ISNULL(t.RowStatus, 255) <> s.RowStatus THEN N'RowStatus' END),
                            (CASE WHEN ISNULL(identityTarget.Guid, '00000000-0000-0000-0000-000000000000') <> s.IdentityGuid THEN N'IdentityGuid' END),
                            (CASE WHEN ISNULL(groupTarget.Guid, '00000000-0000-0000-0000-000000000000') <> s.GroupGuid THEN N'GroupGuid' END)
                    ) AS d(ColumnName)
                    WHERE d.ColumnName IS NOT NULL
                ),
                N'[]'
            )
        FROM SMigration.Onboarding_UserGroups AS s
        LEFT JOIN SCore.UserGroups AS t
            ON t.Guid = s.UserGroupGuid
        LEFT JOIN SCore.Identities AS identityTarget
            ON identityTarget.ID = t.IdentityID
        LEFT JOIN SCore.Groups AS groupTarget
            ON groupTarget.ID = t.GroupID
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.IdentityGuid, s.GroupGuid;
        RETURN;
    END;

    IF @EntityName = N'Workflows'
    BEGIN
        SELECT
            EntityName = N'Workflows',
            RowGuid = CONVERT(NVARCHAR(36), s.WorkflowGuid),
            DiffType =
                CASE
                    WHEN t.ID IS NULL THEN N'MissingInTarget'
                    WHEN ISNULL(t.RowStatus, 255) = s.RowStatus
                     AND ISNULL(t.Name, N'') = ISNULL(s.Name, N'')
                     AND ISNULL(t.Description, N'') = ISNULL(s.Description, N'')
                     AND ISNULL(t.Enabled, 0) = ISNULL(s.Enabled, 0)
                    THEN N'Same'
                    ELSE N'Different'
                END,
            SourceValuesJson =
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
            ),
            TargetValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), ISNULL(t.RowStatus, 255)) AS RowStatus,
                    ISNULL(t.Name, N'') AS Name,
                    ISNULL(CONVERT(NVARCHAR(36), ou.Guid), N'') AS OrganisationalUnitGuid,
                    ISNULL(CONVERT(NVARCHAR(36), et.Guid), N'') AS EntityTypeGuid,
                    ISNULL(CONVERT(NVARCHAR(36), eh.Guid), N'') AS EntityHoBTGuid,
                    ISNULL(t.Description, N'') AS Description,
                    CONVERT(NVARCHAR(5), ISNULL(t.Enabled, 0)) AS Enabled
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            DifferingColumnsJson = COALESCE
            (
                (
                    SELECT N'[' + STRING_AGG(N'"' + STRING_ESCAPE(d.ColumnName, 'json') + N'"', N',') + N']'
                    FROM
                    (
                        VALUES
                            (CASE WHEN ISNULL(t.RowStatus, 255) <> s.RowStatus THEN N'RowStatus' END),
                            (CASE WHEN ISNULL(t.Name, N'') <> ISNULL(s.Name, N'') THEN N'Name' END),
                            (CASE WHEN ISNULL(t.Description, N'') <> ISNULL(s.Description, N'') THEN N'Description' END),
                            (CASE WHEN ISNULL(t.Enabled, 0) <> ISNULL(s.Enabled, 0) THEN N'Enabled' END)
                    ) AS d(ColumnName)
                    WHERE d.ColumnName IS NOT NULL
                ),
                N'[]'
            )
        FROM SMigration.Onboarding_Workflows AS s
        LEFT JOIN SCore.Workflow AS t
            ON t.Guid = s.WorkflowGuid
        LEFT JOIN SCore.OrganisationalUnits AS ou
            ON ou.ID = t.OrganisationalUnitId
        LEFT JOIN SCore.EntityTypes AS et
            ON et.ID = t.EntityTypeID
        LEFT JOIN SCore.EntityHobts AS eh
            ON eh.ID = t.EntityHoBTID
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.Name;
        RETURN;
    END;

    IF @EntityName = N'WorkflowStatuses'
    BEGIN
        SELECT
            EntityName = N'WorkflowStatuses',
            RowGuid = CONVERT(NVARCHAR(36), s.WorkflowStatusGuid),
            DiffType =
                CASE
                    WHEN t.ID IS NULL THEN N'MissingInTarget'
                    WHEN ISNULL(t.RowStatus, 255) = s.RowStatus
                     AND ISNULL(targetOu.Guid, '00000000-0000-0000-0000-000000000000') = ISNULL(s.OrganisationalUnitGuid, '00000000-0000-0000-0000-000000000000')
                     AND ISNULL(t.Name, N'') = ISNULL(s.Name, N'')
                     AND ISNULL(t.Description, N'') = ISNULL(s.Description, N'')
                     AND ISNULL(t.ShowInEnquiries, 0) = s.ShowInEnquiries
                     AND ISNULL(t.ShowInQuotes, 0) = s.ShowInQuotes
                     AND ISNULL(t.ShowInJobs, 0) = s.ShowInJobs
                     AND ISNULL(t.Enabled, 0) = s.Enabled
                     AND ISNULL(t.IsPredefined, 0) = s.IsPredefined
                     AND ISNULL(t.SortOrder, 0) = s.SortOrder
                     AND ISNULL(t.Colour, N'') = ISNULL(s.Colour, N'')
                     AND ISNULL(t.Icon, N'') = ISNULL(s.Icon, N'')
                     AND ISNULL(t.SendNotification, 0) = s.SendNotification
                     AND ISNULL(t.IsCompleteStatus, 0) = s.IsCompleteStatus
                     AND ISNULL(t.IsCustomerWaitingStatus, 0) = s.IsCustomerWaitingStatus
                     AND ISNULL(t.RequiresUsersAction, 0) = s.RequiresUsersAction
                     AND ISNULL(t.IsActiveStatus, 0) = s.IsActiveStatus
                     AND ISNULL(t.AuthorisationNeeded, 0) = s.AuthorisationNeeded
                     AND ISNULL(t.IsAuthStatus, 0) = s.IsAuthStatus
                    THEN N'Same'
                    ELSE N'Different'
                END,
            SourceValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    ISNULL(CONVERT(NVARCHAR(36), s.OrganisationalUnitGuid), N'') AS OrganisationalUnitGuid,
                    s.Name,
                    s.Description,
                    CONVERT(NVARCHAR(5), s.Enabled) AS Enabled,
                    CONVERT(NVARCHAR(20), s.SortOrder) AS SortOrder,
                    s.Colour,
                    ISNULL(s.Icon, N'') AS Icon,
                    CONVERT(NVARCHAR(5), s.IsCompleteStatus) AS IsCompleteStatus,
                    CONVERT(NVARCHAR(5), s.IsActiveStatus) AS IsActiveStatus,
                    CONVERT(NVARCHAR(5), s.AuthorisationNeeded) AS AuthorisationNeeded,
                    CONVERT(NVARCHAR(5), s.IsAuthStatus) AS IsAuthStatus
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            TargetValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), ISNULL(t.RowStatus, 255)) AS RowStatus,
                    ISNULL(CONVERT(NVARCHAR(36), targetOu.Guid), N'') AS OrganisationalUnitGuid,
                    ISNULL(t.Name, N'') AS Name,
                    ISNULL(t.Description, N'') AS Description,
                    CONVERT(NVARCHAR(5), ISNULL(t.Enabled, 0)) AS Enabled,
                    CONVERT(NVARCHAR(20), ISNULL(t.SortOrder, 0)) AS SortOrder,
                    ISNULL(t.Colour, N'') AS Colour,
                    ISNULL(t.Icon, N'') AS Icon,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsCompleteStatus, 0)) AS IsCompleteStatus,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsActiveStatus, 0)) AS IsActiveStatus,
                    CONVERT(NVARCHAR(5), ISNULL(t.AuthorisationNeeded, 0)) AS AuthorisationNeeded,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsAuthStatus, 0)) AS IsAuthStatus
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            DifferingColumnsJson = COALESCE
            (
                (
                    SELECT N'[' + STRING_AGG(N'"' + STRING_ESCAPE(d.ColumnName, 'json') + N'"', N',') + N']'
                    FROM
                    (
                        VALUES
                            (CASE WHEN ISNULL(t.RowStatus, 255) <> s.RowStatus THEN N'RowStatus' END),
                            (CASE WHEN ISNULL(targetOu.Guid, '00000000-0000-0000-0000-000000000000') <> ISNULL(s.OrganisationalUnitGuid, '00000000-0000-0000-0000-000000000000') THEN N'OrganisationalUnitGuid' END),
                            (CASE WHEN ISNULL(t.Name, N'') <> ISNULL(s.Name, N'') THEN N'Name' END),
                            (CASE WHEN ISNULL(t.Description, N'') <> ISNULL(s.Description, N'') THEN N'Description' END),
                            (CASE WHEN ISNULL(t.Enabled, 0) <> s.Enabled THEN N'Enabled' END),
                            (CASE WHEN ISNULL(t.SortOrder, 0) <> s.SortOrder THEN N'SortOrder' END),
                            (CASE WHEN ISNULL(t.Colour, N'') <> ISNULL(s.Colour, N'') THEN N'Colour' END),
                            (CASE WHEN ISNULL(t.Icon, N'') <> ISNULL(s.Icon, N'') THEN N'Icon' END),
                            (CASE WHEN ISNULL(t.IsCompleteStatus, 0) <> s.IsCompleteStatus THEN N'IsCompleteStatus' END),
                            (CASE WHEN ISNULL(t.IsActiveStatus, 0) <> s.IsActiveStatus THEN N'IsActiveStatus' END),
                            (CASE WHEN ISNULL(t.AuthorisationNeeded, 0) <> s.AuthorisationNeeded THEN N'AuthorisationNeeded' END),
                            (CASE WHEN ISNULL(t.IsAuthStatus, 0) <> s.IsAuthStatus THEN N'IsAuthStatus' END)
                    ) AS d(ColumnName)
                    WHERE d.ColumnName IS NOT NULL
                ),
                N'[]'
            )
        FROM SMigration.Onboarding_WorkflowStatuses AS s
        LEFT JOIN SCore.WorkflowStatus AS t
            ON t.Guid = s.WorkflowStatusGuid
        LEFT JOIN SCore.OrganisationalUnits AS targetOu
            ON targetOu.ID = t.OrganisationalUnitId
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.SortOrder, s.Name;
        RETURN;
    END;

    IF @EntityName = N'WorkflowStatusNotificationGroups'
    BEGIN
        SELECT
            EntityName = N'WorkflowStatusNotificationGroups',
            RowGuid = CONVERT(NVARCHAR(36), s.WorkflowNotificationGroupGuid),
            DiffType =
                CASE
                    WHEN t.ID IS NULL THEN N'MissingInTarget'
                    WHEN ISNULL(t.RowStatus, 255) = s.RowStatus
                     AND ISNULL(wf.Guid, '00000000-0000-0000-0000-000000000000') = s.WorkflowGuid
                     AND ISNULL(t.WorkflowStatusGuid, '00000000-0000-0000-0000-000000000000') = s.WorkflowStatusGuid
                     AND ISNULL(groupTarget.Guid, '00000000-0000-0000-0000-000000000000') = s.GroupGuid
                     AND ISNULL(t.CanAction, 0) = s.CanAction
                    THEN N'Same'
                    ELSE N'Different'
                END,
            SourceValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    CONVERT(NVARCHAR(36), s.WorkflowGuid) AS WorkflowGuid,
                    CONVERT(NVARCHAR(36), s.WorkflowStatusGuid) AS WorkflowStatusGuid,
                    CONVERT(NVARCHAR(36), s.GroupGuid) AS GroupGuid,
                    CONVERT(NVARCHAR(5), s.CanAction) AS CanAction
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            TargetValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), ISNULL(t.RowStatus, 255)) AS RowStatus,
                    ISNULL(CONVERT(NVARCHAR(36), wf.Guid), N'') AS WorkflowGuid,
                    ISNULL(CONVERT(NVARCHAR(36), t.WorkflowStatusGuid), N'') AS WorkflowStatusGuid,
                    ISNULL(CONVERT(NVARCHAR(36), groupTarget.Guid), N'') AS GroupGuid,
                    CONVERT(NVARCHAR(5), ISNULL(t.CanAction, 0)) AS CanAction
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            DifferingColumnsJson = COALESCE
            (
                (
                    SELECT N'[' + STRING_AGG(N'"' + STRING_ESCAPE(d.ColumnName, 'json') + N'"', N',') + N']'
                    FROM
                    (
                        VALUES
                            (CASE WHEN ISNULL(t.RowStatus, 255) <> s.RowStatus THEN N'RowStatus' END),
                            (CASE WHEN ISNULL(wf.Guid, '00000000-0000-0000-0000-000000000000') <> s.WorkflowGuid THEN N'WorkflowGuid' END),
                            (CASE WHEN ISNULL(t.WorkflowStatusGuid, '00000000-0000-0000-0000-000000000000') <> s.WorkflowStatusGuid THEN N'WorkflowStatusGuid' END),
                            (CASE WHEN ISNULL(groupTarget.Guid, '00000000-0000-0000-0000-000000000000') <> s.GroupGuid THEN N'GroupGuid' END),
                            (CASE WHEN ISNULL(t.CanAction, 0) <> s.CanAction THEN N'CanAction' END)
                    ) AS d(ColumnName)
                    WHERE d.ColumnName IS NOT NULL
                ),
                N'[]'
            )
        FROM SMigration.Onboarding_WorkflowStatusNotificationGroups AS s
        LEFT JOIN SCore.WorkflowStatusNotificationGroups AS t
            ON t.Guid = s.WorkflowNotificationGroupGuid
        LEFT JOIN SCore.Workflow AS wf
            ON wf.ID = t.WorkflowID
        LEFT JOIN SCore.Groups AS groupTarget
            ON groupTarget.ID = t.GroupID
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.WorkflowGuid, s.GroupGuid;
        RETURN;
    END;

    IF @EntityName = N'JobTypes'
    BEGIN
        SELECT
            EntityName = N'JobTypes',
            RowGuid = CONVERT(NVARCHAR(36), s.JobTypeGuid),
            DiffType =
                CASE
                    WHEN t.ID IS NULL THEN N'MissingInTarget'
                    WHEN ISNULL(t.RowStatus, 255) = s.RowStatus
                     AND ISNULL(t.Name, N'') = s.Name
                     AND ISNULL(t.IsActive, 1) = s.IsActive
                     AND ISNULL(t.SequenceID, 0) = s.SequenceID
                     AND ISNULL(t.UseTimeSheets, 0) = s.UseTimeSheets
                     AND ISNULL(t.UsePlanChecks, 0) = s.UsePlanChecks
                     AND ISNULL(ou.Guid, '00000000-0000-0000-0000-000000000000') = s.OrganisationalUnitGuid
                    THEN N'Same'
                    ELSE N'Different'
                END,
            SourceValuesJson =
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
            ),
            TargetValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), ISNULL(t.RowStatus, 255)) AS RowStatus,
                    ISNULL(t.Name, N'') AS Name,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsActive, 1)) AS IsActive,
                    CONVERT(NVARCHAR(20), ISNULL(t.SequenceID, 0)) AS SequenceID,
                    CONVERT(NVARCHAR(5), ISNULL(t.UseTimeSheets, 0)) AS UseTimeSheets,
                    CONVERT(NVARCHAR(5), ISNULL(t.UsePlanChecks, 0)) AS UsePlanChecks,
                    ISNULL(CONVERT(NVARCHAR(36), ou.Guid), N'') AS OrganisationalUnitGuid
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            DifferingColumnsJson = COALESCE
            (
                (
                    SELECT N'[' + STRING_AGG(N'"' + STRING_ESCAPE(d.ColumnName, 'json') + N'"', N',') + N']'
                    FROM
                    (
                        VALUES
                            (CASE WHEN ISNULL(t.RowStatus, 255) <> s.RowStatus THEN N'RowStatus' END),
                            (CASE WHEN ISNULL(t.Name, N'') <> s.Name THEN N'Name' END),
                            (CASE WHEN ISNULL(t.IsActive, 1) <> s.IsActive THEN N'IsActive' END),
                            (CASE WHEN ISNULL(t.SequenceID, 0) <> s.SequenceID THEN N'SequenceID' END),
                            (CASE WHEN ISNULL(t.UseTimeSheets, 0) <> s.UseTimeSheets THEN N'UseTimeSheets' END),
                            (CASE WHEN ISNULL(t.UsePlanChecks, 0) <> s.UsePlanChecks THEN N'UsePlanChecks' END),
                            (CASE WHEN ISNULL(ou.Guid, '00000000-0000-0000-0000-000000000000') <> s.OrganisationalUnitGuid THEN N'OrganisationalUnitGuid' END)
                    ) AS d(ColumnName)
                    WHERE d.ColumnName IS NOT NULL
                ),
                N'[]'
            )
        FROM SMigration.Onboarding_JobTypes AS s
        LEFT JOIN SJob.JobTypes AS t
            ON t.Guid = s.JobTypeGuid
        LEFT JOIN SCore.OrganisationalUnits AS ou
            ON ou.ID = t.OrganisationalUnitID
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.SequenceID, s.Name;
        RETURN;
    END;

    IF @EntityName = N'ActivityTypes'
    BEGIN
        SELECT
            EntityName = N'ActivityTypes',
            RowGuid = CONVERT(NVARCHAR(36), s.ActivityTypeGuid),
            DiffType =
                CASE
                    WHEN t.ID IS NULL THEN N'MissingInTarget'
                    WHEN ISNULL(t.RowStatus, 255) = s.RowStatus
                     AND ISNULL(t.Name, N'') = s.Name
                     AND ISNULL(t.IsActive, 1) = s.IsActive
                     AND ISNULL(t.SortOrder, 0) = s.SortOrder
                     AND ISNULL(t.IsFeeTrigger, 0) = s.IsFeeTrigger
                     AND ISNULL(t.IsLiveTrigger, 0) = s.IsLiveTrigger
                     AND ISNULL(t.IsAdmin, 0) = s.IsAdmin
                     AND ISNULL(t.IsScheduleItem, 0) = s.IsScheduleItem
                     AND ISNULL(t.Colour, N'') = s.Colour
                     AND ISNULL(t.IsMeeting, 0) = s.IsMeeting
                     AND ISNULL(t.IsSiteVisit, 0) = s.IsSiteVisit
                     AND ISNULL(t.IsBillable, 0) = s.IsBillable
                     AND ISNULL(t.IsCommencementTrigger, 0) = s.IsCommencementTrigger
                    THEN N'Same'
                    ELSE N'Different'
                END,
            SourceValuesJson =
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
            ),
            TargetValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), ISNULL(t.RowStatus, 255)) AS RowStatus,
                    ISNULL(t.Name, N'') AS Name,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsActive, 1)) AS IsActive,
                    CONVERT(NVARCHAR(20), ISNULL(t.SortOrder, 0)) AS SortOrder,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsFeeTrigger, 0)) AS IsFeeTrigger,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsLiveTrigger, 0)) AS IsLiveTrigger,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsAdmin, 0)) AS IsAdmin,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsScheduleItem, 0)) AS IsScheduleItem,
                    ISNULL(t.Colour, N'') AS Colour,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsMeeting, 0)) AS IsMeeting,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsSiteVisit, 0)) AS IsSiteVisit,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsBillable, 0)) AS IsBillable,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsCommencementTrigger, 0)) AS IsCommencementTrigger
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            DifferingColumnsJson = COALESCE
            (
                (
                    SELECT N'[' + STRING_AGG(N'"' + STRING_ESCAPE(d.ColumnName, 'json') + N'"', N',') + N']'
                    FROM
                    (
                        VALUES
                            (CASE WHEN ISNULL(t.RowStatus, 255) <> s.RowStatus THEN N'RowStatus' END),
                            (CASE WHEN ISNULL(t.Name, N'') <> s.Name THEN N'Name' END),
                            (CASE WHEN ISNULL(t.IsActive, 1) <> s.IsActive THEN N'IsActive' END),
                            (CASE WHEN ISNULL(t.SortOrder, 0) <> s.SortOrder THEN N'SortOrder' END),
                            (CASE WHEN ISNULL(t.IsFeeTrigger, 0) <> s.IsFeeTrigger THEN N'IsFeeTrigger' END),
                            (CASE WHEN ISNULL(t.IsLiveTrigger, 0) <> s.IsLiveTrigger THEN N'IsLiveTrigger' END),
                            (CASE WHEN ISNULL(t.IsAdmin, 0) <> s.IsAdmin THEN N'IsAdmin' END),
                            (CASE WHEN ISNULL(t.IsScheduleItem, 0) <> s.IsScheduleItem THEN N'IsScheduleItem' END),
                            (CASE WHEN ISNULL(t.Colour, N'') <> s.Colour THEN N'Colour' END),
                            (CASE WHEN ISNULL(t.IsMeeting, 0) <> s.IsMeeting THEN N'IsMeeting' END),
                            (CASE WHEN ISNULL(t.IsSiteVisit, 0) <> s.IsSiteVisit THEN N'IsSiteVisit' END),
                            (CASE WHEN ISNULL(t.IsBillable, 0) <> s.IsBillable THEN N'IsBillable' END),
                            (CASE WHEN ISNULL(t.IsCommencementTrigger, 0) <> s.IsCommencementTrigger THEN N'IsCommencementTrigger' END)
                    ) AS d(ColumnName)
                    WHERE d.ColumnName IS NOT NULL
                ),
                N'[]'
            )
        FROM SMigration.Onboarding_ActivityTypes AS s
        LEFT JOIN SJob.ActivityTypes AS t
            ON t.Guid = s.ActivityTypeGuid
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.SortOrder, s.Name;
        RETURN;
    END;

    IF @EntityName = N'MilestoneTypes'
    BEGIN
        SELECT
            EntityName = N'MilestoneTypes',
            RowGuid = CONVERT(NVARCHAR(36), s.MilestoneTypeGuid),
            DiffType =
                CASE
                    WHEN t.ID IS NULL THEN N'MissingInTarget'
                    WHEN ISNULL(t.RowStatus, 255) = s.RowStatus
                     AND ISNULL(t.Code, N'') = s.Code
                     AND ISNULL(t.Name, N'') = s.Name
                     AND ISNULL(t.IsActive, 1) = s.IsActive
                     AND ISNULL(t.IsInvoiceTrigger, 0) = s.IsInvoiceTrigger
                     AND ISNULL(t.IsReviewRequired, 0) = s.IsReviewRequired
                     AND ISNULL(t.HelpText, N'') = s.HelpText
                     AND ISNULL(t.HasQuotedHours, 0) = s.HasQuotedHours
                     AND ISNULL(t.HasDescription, 0) = s.HasDescription
                     AND ISNULL(t.HasReference, 0) = s.HasReference
                     AND ISNULL(t.IsCompulsory, 0) = s.IsCompulsory
                     AND ISNULL(t.IncludeStart, 0) = s.IncludeStart
                     AND ISNULL(t.IncludeSchedule, 0) = s.IncludeSchedule
                     AND ISNULL(t.IncludeDueDate, 0) = s.IncludeDueDate
                     AND ISNULL(t.HasExternalSubmission, 0) = s.HasExternalSubmission
                    THEN N'Same'
                    ELSE N'Different'
                END,
            SourceValuesJson =
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
            ),
            TargetValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), ISNULL(t.RowStatus, 255)) AS RowStatus,
                    ISNULL(t.Code, N'') AS Code,
                    ISNULL(t.Name, N'') AS Name,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsActive, 1)) AS IsActive,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsInvoiceTrigger, 0)) AS IsInvoiceTrigger,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsReviewRequired, 0)) AS IsReviewRequired,
                    ISNULL(t.HelpText, N'') AS HelpText,
                    CONVERT(NVARCHAR(5), ISNULL(t.HasQuotedHours, 0)) AS HasQuotedHours,
                    CONVERT(NVARCHAR(5), ISNULL(t.HasDescription, 0)) AS HasDescription,
                    CONVERT(NVARCHAR(5), ISNULL(t.HasReference, 0)) AS HasReference,
                    CONVERT(NVARCHAR(5), ISNULL(t.IsCompulsory, 0)) AS IsCompulsory,
                    CONVERT(NVARCHAR(5), ISNULL(t.IncludeStart, 0)) AS IncludeStart,
                    CONVERT(NVARCHAR(5), ISNULL(t.IncludeSchedule, 0)) AS IncludeSchedule,
                    CONVERT(NVARCHAR(5), ISNULL(t.IncludeDueDate, 0)) AS IncludeDueDate,
                    CONVERT(NVARCHAR(5), ISNULL(t.HasExternalSubmission, 0)) AS HasExternalSubmission
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            DifferingColumnsJson = COALESCE
            (
                (
                    SELECT N'[' + STRING_AGG(N'"' + STRING_ESCAPE(d.ColumnName, 'json') + N'"', N',') + N']'
                    FROM
                    (
                        VALUES
                            (CASE WHEN ISNULL(t.RowStatus, 255) <> s.RowStatus THEN N'RowStatus' END),
                            (CASE WHEN ISNULL(t.Code, N'') <> s.Code THEN N'Code' END),
                            (CASE WHEN ISNULL(t.Name, N'') <> s.Name THEN N'Name' END),
                            (CASE WHEN ISNULL(t.IsActive, 1) <> s.IsActive THEN N'IsActive' END),
                            (CASE WHEN ISNULL(t.IsInvoiceTrigger, 0) <> s.IsInvoiceTrigger THEN N'IsInvoiceTrigger' END),
                            (CASE WHEN ISNULL(t.IsReviewRequired, 0) <> s.IsReviewRequired THEN N'IsReviewRequired' END),
                            (CASE WHEN ISNULL(t.HelpText, N'') <> s.HelpText THEN N'HelpText' END),
                            (CASE WHEN ISNULL(t.HasQuotedHours, 0) <> s.HasQuotedHours THEN N'HasQuotedHours' END),
                            (CASE WHEN ISNULL(t.HasDescription, 0) <> s.HasDescription THEN N'HasDescription' END),
                            (CASE WHEN ISNULL(t.HasReference, 0) <> s.HasReference THEN N'HasReference' END),
                            (CASE WHEN ISNULL(t.IsCompulsory, 0) <> s.IsCompulsory THEN N'IsCompulsory' END),
                            (CASE WHEN ISNULL(t.IncludeStart, 0) <> s.IncludeStart THEN N'IncludeStart' END),
                            (CASE WHEN ISNULL(t.IncludeSchedule, 0) <> s.IncludeSchedule THEN N'IncludeSchedule' END),
                            (CASE WHEN ISNULL(t.IncludeDueDate, 0) <> s.IncludeDueDate THEN N'IncludeDueDate' END),
                            (CASE WHEN ISNULL(t.HasExternalSubmission, 0) <> s.HasExternalSubmission THEN N'HasExternalSubmission' END)
                    ) AS d(ColumnName)
                    WHERE d.ColumnName IS NOT NULL
                ),
                N'[]'
            )
        FROM SMigration.Onboarding_MilestoneTypes AS s
        LEFT JOIN SJob.MilestoneTypes AS t
            ON t.Guid = s.MilestoneTypeGuid
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.Code, s.Name;
        RETURN;
    END;

    IF @EntityName = N'JobTypeActivityTypes'
    BEGIN
        SELECT
            EntityName = N'JobTypeActivityTypes',
            RowGuid = CONVERT(NVARCHAR(36), s.JobTypeActivityTypeGuid),
            DiffType =
                CASE
                    WHEN t.ID IS NULL THEN N'MissingInTarget'
                    WHEN ISNULL(t.RowStatus, 255) = s.RowStatus
                     AND ISNULL(jt.Guid, '00000000-0000-0000-0000-000000000000') = s.JobTypeGuid
                     AND ISNULL(at.Guid, '00000000-0000-0000-0000-000000000000') = s.ActivityTypeGuid
                    THEN N'Same'
                    ELSE N'Different'
                END,
            SourceValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    CONVERT(NVARCHAR(36), s.JobTypeGuid) AS JobTypeGuid,
                    CONVERT(NVARCHAR(36), s.ActivityTypeGuid) AS ActivityTypeGuid
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            TargetValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), ISNULL(t.RowStatus, 255)) AS RowStatus,
                    ISNULL(CONVERT(NVARCHAR(36), jt.Guid), N'') AS JobTypeGuid,
                    ISNULL(CONVERT(NVARCHAR(36), at.Guid), N'') AS ActivityTypeGuid
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            DifferingColumnsJson = COALESCE
            (
                (
                    SELECT N'[' + STRING_AGG(N'"' + STRING_ESCAPE(d.ColumnName, 'json') + N'"', N',') + N']'
                    FROM
                    (
                        VALUES
                            (CASE WHEN ISNULL(t.RowStatus, 255) <> s.RowStatus THEN N'RowStatus' END),
                            (CASE WHEN ISNULL(jt.Guid, '00000000-0000-0000-0000-000000000000') <> s.JobTypeGuid THEN N'JobTypeGuid' END),
                            (CASE WHEN ISNULL(at.Guid, '00000000-0000-0000-0000-000000000000') <> s.ActivityTypeGuid THEN N'ActivityTypeGuid' END)
                    ) AS d(ColumnName)
                    WHERE d.ColumnName IS NOT NULL
                ),
                N'[]'
            )
        FROM SMigration.Onboarding_JobTypeActivityTypes AS s
        LEFT JOIN SJob.JobTypeActivityTypes AS t
            ON t.Guid = s.JobTypeActivityTypeGuid
        LEFT JOIN SJob.JobTypes AS jt
            ON jt.ID = t.JobTypeID
        LEFT JOIN SJob.ActivityTypes AS at
            ON at.ID = t.ActivityTypeID
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.JobTypeGuid, s.ActivityTypeGuid;
        RETURN;
    END;

    IF @EntityName = N'JobTypeMilestoneTemplates'
    BEGIN
        SELECT
            EntityName = N'JobTypeMilestoneTemplates',
            RowGuid = CONVERT(NVARCHAR(36), s.JobTypeMilestoneTemplateGuid),
            DiffType =
                CASE
                    WHEN t.ID IS NULL THEN N'MissingInTarget'
                    WHEN ISNULL(t.RowStatus, 255) = s.RowStatus
                     AND ISNULL(jt.Guid, '00000000-0000-0000-0000-000000000000') = s.JobTypeGuid
                     AND ISNULL(mt.Guid, '00000000-0000-0000-0000-000000000000') = s.MilestoneTypeGuid
                     AND ISNULL(t.Description, N'') = s.Description
                     AND ISNULL(t.SortOrder, 0) = s.SortOrder
                    THEN N'Same'
                    ELSE N'Different'
                END,
            SourceValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    CONVERT(NVARCHAR(36), s.JobTypeGuid) AS JobTypeGuid,
                    CONVERT(NVARCHAR(36), s.MilestoneTypeGuid) AS MilestoneTypeGuid,
                    s.Description,
                    CONVERT(NVARCHAR(20), s.SortOrder) AS SortOrder
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            TargetValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), ISNULL(t.RowStatus, 255)) AS RowStatus,
                    ISNULL(CONVERT(NVARCHAR(36), jt.Guid), N'') AS JobTypeGuid,
                    ISNULL(CONVERT(NVARCHAR(36), mt.Guid), N'') AS MilestoneTypeGuid,
                    ISNULL(t.Description, N'') AS Description,
                    CONVERT(NVARCHAR(20), ISNULL(t.SortOrder, 0)) AS SortOrder
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            DifferingColumnsJson = COALESCE
            (
                (
                    SELECT N'[' + STRING_AGG(N'"' + STRING_ESCAPE(d.ColumnName, 'json') + N'"', N',') + N']'
                    FROM
                    (
                        VALUES
                            (CASE WHEN ISNULL(t.RowStatus, 255) <> s.RowStatus THEN N'RowStatus' END),
                            (CASE WHEN ISNULL(jt.Guid, '00000000-0000-0000-0000-000000000000') <> s.JobTypeGuid THEN N'JobTypeGuid' END),
                            (CASE WHEN ISNULL(mt.Guid, '00000000-0000-0000-0000-000000000000') <> s.MilestoneTypeGuid THEN N'MilestoneTypeGuid' END),
                            (CASE WHEN ISNULL(t.Description, N'') <> s.Description THEN N'Description' END),
                            (CASE WHEN ISNULL(t.SortOrder, 0) <> s.SortOrder THEN N'SortOrder' END)
                    ) AS d(ColumnName)
                    WHERE d.ColumnName IS NOT NULL
                ),
                N'[]'
            )
        FROM SMigration.Onboarding_JobTypeMilestoneTemplates AS s
        LEFT JOIN SJob.JobTypeMilestoneTemplates AS t
            ON t.Guid = s.JobTypeMilestoneTemplateGuid
        LEFT JOIN SJob.JobTypes AS jt
            ON jt.ID = t.JobTypeID
        LEFT JOIN SJob.MilestoneTypes AS mt
            ON mt.ID = t.MilestoneTypeID
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.JobTypeGuid, s.SortOrder, s.MilestoneTypeGuid;
        RETURN;
    END;

    IF @EntityName = N'Products'
    BEGIN
        SELECT
            EntityName = N'Products',
            RowGuid = CONVERT(NVARCHAR(36), s.ProductGuid),
            DiffType =
                CASE
                    WHEN tgtByGuid.ID IS NOT NULL THEN N'Same'
                    WHEN tgtByCode.ID IS NOT NULL THEN N'Same'
                    ELSE N'MissingInTarget'
                END,
            SourceValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), s.RowStatus) AS RowStatus,
                    s.Code,
                    s.Description,
                    CONVERT(NVARCHAR(36), s.CreatedJobTypeGuid) AS CreatedJobTypeGuid,
                    CONVERT(NVARCHAR(5), s.NeverConsolidate) AS NeverConsolidate,
                    ISNULL(CONVERT(NVARCHAR(36), s.RibaStageGuid), N'') AS RibaStageGuid
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            TargetValuesJson =
            (
                SELECT
                    CASE
                        WHEN tgtByGuid.ID IS NOT NULL THEN N'ExistingByGuid'
                        WHEN tgtByCode.ID IS NOT NULL THEN N'ExistingByCode'
                        ELSE N''
                    END AS MatchType
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            DifferingColumnsJson = N'[]'
        FROM SMigration.Onboarding_Products AS s
        LEFT JOIN SProd.Products AS tgtByGuid
            ON tgtByGuid.Guid = s.ProductGuid
           AND tgtByGuid.ID > 0
        LEFT JOIN SProd.Products AS tgtByCode
            ON tgtByCode.ID > 0
           AND tgtByCode.RowStatus NOT IN (0,254)
           AND NULLIF(LTRIM(RTRIM(s.Code)), N'') IS NOT NULL
           AND LOWER(LTRIM(RTRIM(tgtByCode.Code))) = LOWER(LTRIM(RTRIM(s.Code)))
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.Code, s.Description;

        RETURN;
    END;

    IF @EntityName = N'ProductJobActivities'
    BEGIN
        SELECT
            EntityName = N'ProductJobActivities',
            RowGuid = CONVERT(NVARCHAR(36), s.ProductJobActivityGuid),
            DiffType =
                CASE
                    WHEN t.ID IS NULL THEN N'MissingInTarget'
                    WHEN ISNULL(t.RowStatus, 255) = s.RowStatus
                     AND ISNULL(p.Guid, '00000000-0000-0000-0000-000000000000') = s.ProductGuid
                     AND ISNULL(jtat.Guid, '00000000-0000-0000-0000-000000000000') = s.JobTypeActivityTypeGuid
                     AND ISNULL(t.ActivityTitle, N'') = s.ActivityTitle
                     AND ISNULL(t.OffsetDays, 0) = s.OffsetDays
                     AND ISNULL(t.OffsetWeeks, 0) = s.OffsetWeeks
                     AND ISNULL(t.OffsetMonths, 0) = s.OffsetMonths
                     AND ISNULL(jtmt.Guid, '00000000-0000-0000-0000-000000000000') = ISNULL(s.JobTypeMilestoneTemplateGuid, '00000000-0000-0000-0000-000000000000')
                     AND ISNULL(t.PercentageOfProductValue, 0) = s.PercentageOfProductValue
                    THEN N'Same'
                    ELSE N'Different'
                END,
            SourceValuesJson =
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
            ),
            TargetValuesJson =
            (
                SELECT
                    CONVERT(NVARCHAR(10), ISNULL(t.RowStatus, 255)) AS RowStatus,
                    ISNULL(CONVERT(NVARCHAR(36), p.Guid), N'') AS ProductGuid,
                    ISNULL(CONVERT(NVARCHAR(36), jtat.Guid), N'') AS JobTypeActivityTypeGuid,
                    ISNULL(t.ActivityTitle, N'') AS ActivityTitle,
                    CONVERT(NVARCHAR(20), ISNULL(t.OffsetDays, 0)) AS OffsetDays,
                    CONVERT(NVARCHAR(20), ISNULL(t.OffsetWeeks, 0)) AS OffsetWeeks,
                    CONVERT(NVARCHAR(20), ISNULL(t.OffsetMonths, 0)) AS OffsetMonths,
                    ISNULL(CONVERT(NVARCHAR(36), jtmt.Guid), N'') AS JobTypeMilestoneTemplateGuid,
                    CONVERT(NVARCHAR(50), ISNULL(t.PercentageOfProductValue, 0)) AS PercentageOfProductValue
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            DifferingColumnsJson = COALESCE
            (
                (
                    SELECT N'[' + STRING_AGG(N'"' + STRING_ESCAPE(d.ColumnName, 'json') + N'"', N',') + N']'
                    FROM
                    (
                        VALUES
                            (CASE WHEN ISNULL(t.RowStatus, 255) <> s.RowStatus THEN N'RowStatus' END),
                            (CASE WHEN ISNULL(p.Guid, '00000000-0000-0000-0000-000000000000') <> s.ProductGuid THEN N'ProductGuid' END),
                            (CASE WHEN ISNULL(jtat.Guid, '00000000-0000-0000-0000-000000000000') <> s.JobTypeActivityTypeGuid THEN N'JobTypeActivityTypeGuid' END),
                            (CASE WHEN ISNULL(t.ActivityTitle, N'') <> s.ActivityTitle THEN N'ActivityTitle' END),
                            (CASE WHEN ISNULL(t.OffsetDays, 0) <> s.OffsetDays THEN N'OffsetDays' END),
                            (CASE WHEN ISNULL(t.OffsetWeeks, 0) <> s.OffsetWeeks THEN N'OffsetWeeks' END),
                            (CASE WHEN ISNULL(t.OffsetMonths, 0) <> s.OffsetMonths THEN N'OffsetMonths' END),
                            (CASE WHEN ISNULL(jtmt.Guid, '00000000-0000-0000-0000-000000000000') <> ISNULL(s.JobTypeMilestoneTemplateGuid, '00000000-0000-0000-0000-000000000000') THEN N'JobTypeMilestoneTemplateGuid' END),
                            (CASE WHEN ISNULL(t.PercentageOfProductValue, 0) <> s.PercentageOfProductValue THEN N'PercentageOfProductValue' END)
                    ) AS d(ColumnName)
                    WHERE d.ColumnName IS NOT NULL
                ),
                N'[]'
            )
        FROM SMigration.Onboarding_ProductJobActivities AS s
        LEFT JOIN SJob.ProductJobActivities AS t
            ON t.Guid = s.ProductJobActivityGuid
        LEFT JOIN SProd.Products AS p
            ON p.ID = t.ProductId
        LEFT JOIN SJob.JobTypeActivityTypes AS jtat
            ON jtat.ID = t.JobTypeActivityTypeId
        LEFT JOIN SJob.JobTypeMilestoneTemplates AS jtmt
            ON jtmt.ID = t.JobTypeMilestoneTemplateId
        WHERE s.RunGuid = @RunGuid
        ORDER BY s.ProductGuid, s.JobTypeActivityTypeGuid, s.ActivityTitle;
        RETURN;
    END;

    IF @EntityName = N'WorkflowTransitions'
    BEGIN
        SELECT
            EntityName = N'WorkflowTransitions',
            RowGuid = CONVERT(NVARCHAR(36), s.WorkflowTransitionGuid),
            DiffType =
                CASE
                    WHEN t.ID IS NULL THEN N'MissingInTarget'
                    WHEN
                        ISNULL(sw.Name, N'') = ISNULL(tw.Name, N'')
                        AND
                        ISNULL
                        (
                            CASE
                                WHEN s.FromStatusGuid = '00000000-0000-0000-0000-000000000000'
                                    THEN N'N/A'
                                ELSE sfs.Name
                            END,
                            N''
                        ) = ISNULL(tfs.Name, N'')
                        AND ISNULL(sts.Name, N'') = ISNULL(tts.Name, N'')
                        AND ISNULL(s.Description, N'') = ISNULL(t.Description, N'')
                    THEN N'Same'
                    ELSE N'Different'
                END,
            SourceValuesJson =
            (
                SELECT
                    ISNULL(sw.Name, N'') AS WorkflowName,
                    ISNULL
                    (
                        CASE
                            WHEN s.FromStatusGuid = '00000000-0000-0000-0000-000000000000'
                                THEN N'N/A'
                            ELSE sfs.Name
                        END,
                        N''
                    ) AS FromStatus,
                    ISNULL(sts.Name, N'') AS ToStatus,
                    ISNULL(s.Description, N'') AS Description
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            TargetValuesJson =
            (
                SELECT
                    ISNULL(tw.Name, N'') AS WorkflowName,
                    ISNULL(tfs.Name, N'') AS FromStatus,
                    ISNULL(tts.Name, N'') AS ToStatus,
                    ISNULL(t.Description, N'') AS Description
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ),
            DifferingColumnsJson = COALESCE
            (
                (
                    SELECT N'[' + STRING_AGG(N'"' + STRING_ESCAPE(d.ColumnName, 'json') + N'"', N',') + N']'
                    FROM
                    (
                        VALUES
                            (CASE WHEN ISNULL(sw.Name, N'') <> ISNULL(tw.Name, N'') THEN N'WorkflowName' END),
                            (
                                CASE
                                    WHEN ISNULL
                                    (
                                        CASE
                                            WHEN s.FromStatusGuid = '00000000-0000-0000-0000-000000000000'
                                                THEN N'N/A'
                                            ELSE sfs.Name
                                        END,
                                        N''
                                    ) <> ISNULL(tfs.Name, N'')
                                    THEN N'FromStatus'
                                END
                            ),
                            (CASE WHEN ISNULL(sts.Name, N'') <> ISNULL(tts.Name, N'') THEN N'ToStatus' END),
                            (CASE WHEN ISNULL(s.Description, N'') <> ISNULL(t.Description, N'') THEN N'Description' END)
                    ) AS d(ColumnName)
                    WHERE d.ColumnName IS NOT NULL
                ),
                N'[]'
            )
        FROM SMigration.Onboarding_WorkflowTransitions AS s
        LEFT JOIN SCore.WorkflowTransition AS t
            ON t.Guid = s.WorkflowTransitionGuid
        LEFT JOIN SCore.Workflow AS sw
            ON sw.Guid = s.WorkflowGuid
        LEFT JOIN SCore.Workflow AS tw
            ON tw.ID = t.WorkflowID
        LEFT JOIN SCore.WorkflowStatus AS sfs
            ON sfs.Guid = s.FromStatusGuid
           AND s.FromStatusGuid <> '00000000-0000-0000-0000-000000000000'
        LEFT JOIN SCore.WorkflowStatus AS tfs
            ON tfs.ID = t.FromStatusID
        LEFT JOIN SCore.WorkflowStatus AS sts
            ON sts.Guid = s.ToStatusGuid
        LEFT JOIN SCore.WorkflowStatus AS tts
            ON tts.ID = t.ToStatusID
        WHERE s.RunGuid = @RunGuid
        ORDER BY sw.Name, sfs.Name, sts.Name;

        RETURN;
    END;
    ;THROW 60000, N'Unsupported entity name passed to SMigration.OnboardingDiff_Report.', 1;
END;

GO