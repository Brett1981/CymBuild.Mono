SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create or alter function [SCore].[tvf_UniversalSearch]')
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SCore].[tvf_UniversalSearch]')
GO

CREATE FUNCTION [SCore].[tvf_UniversalSearch]
(
    @UserId       INT,
    @SearchText   NVARCHAR(200),
    @ModuleFilter NVARCHAR(1000),
    @Take         INT
)
RETURNS @Results TABLE
(
    ModuleKey         NVARCHAR(50) NOT NULL,
    ModuleDisplayName NVARCHAR(100) NOT NULL,
    RecordGuid        UNIQUEIDENTIFIER NOT NULL,
    EntityTypeGuid    UNIQUEIDENTIFIER NOT NULL,
    EntityTypeName    NVARCHAR(250) NOT NULL,
    DetailPageUri     NVARCHAR(250) NOT NULL,
    PrimaryText       NVARCHAR(500) NOT NULL,
    SecondaryText     NVARCHAR(1000) NOT NULL,
    TertiaryText      NVARCHAR(1000) NOT NULL,
    SearchRank        INT NOT NULL
)
AS
BEGIN
    DECLARE @CleanSearchText NVARCHAR(200) = LTRIM(RTRIM(ISNULL(@SearchText, N'')));
    DECLARE @SafeTake INT = CASE WHEN ISNULL(@Take, 0) BETWEEN 1 AND 100 THEN @Take ELSE 10 END;
    DECLARE @Pattern NVARCHAR(210) = N'%' + REPLACE(REPLACE(REPLACE(@CleanSearchText, N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';

    IF (@CleanSearchText = N'')
    BEGIN
        RETURN;
    END;

    DECLARE @Filters TABLE
    (
        ModuleKey NVARCHAR(50) NOT NULL PRIMARY KEY
    );

    INSERT INTO @Filters (ModuleKey)
    SELECT DISTINCT UPPER(LTRIM(RTRIM([value]))) AS ModuleKey
    FROM STRING_SPLIT(ISNULL(@ModuleFilter, N''), N',')
    WHERE LTRIM(RTRIM([value])) <> N'';

    INSERT INTO @Results
    (
        ModuleKey,
        ModuleDisplayName,
        RecordGuid,
        EntityTypeGuid,
        EntityTypeName,
        DetailPageUri,
        PrimaryText,
        SecondaryText,
        TertiaryText,
        SearchRank
    )
    SELECT RankedResults.ModuleKey,
           RankedResults.ModuleDisplayName,
           RankedResults.RecordGuid,
           RankedResults.EntityTypeGuid,
           RankedResults.EntityTypeName,
           RankedResults.DetailPageUri,
           RankedResults.PrimaryText,
           RankedResults.SecondaryText,
           RankedResults.TertiaryText,
           RankedResults.SearchRank
    FROM
    (
        SELECT RawResults.ModuleKey,
               RawResults.ModuleDisplayName,
               RawResults.RecordGuid,
               RawResults.EntityTypeGuid,
               RawResults.EntityTypeName,
               RawResults.DetailPageUri,
               RawResults.PrimaryText,
               RawResults.SecondaryText,
               RawResults.TertiaryText,
               RawResults.SearchRank,
               ROW_NUMBER() OVER
               (
                   PARTITION BY RawResults.ModuleKey
                   ORDER BY RawResults.SearchRank,
                            RawResults.PrimaryText,
                            RawResults.SecondaryText,
                            RawResults.RecordGuid
               ) AS ModuleRowNumber
        FROM
        (
        SELECT N'JOBS' AS ModuleKey,
               N'Jobs' AS ModuleDisplayName,
               j.Guid AS RecordGuid,
               et.Guid AS EntityTypeGuid,
               et.Name AS EntityTypeName,
               COALESCE(NULLIF(et.DetailPageUrl, N''), N'DynamicEdit') AS DetailPageUri,
               CONVERT(NVARCHAR(500), N'Job ' + j.Number) AS PrimaryText,
               CONVERT(NVARCHAR(1000), COALESCE(NULLIF(LTRIM(RTRIM(j.JobDescription)), N''), N'No description')) AS SecondaryText,
               CONVERT(NVARCHAR(1000), CONCAT(COALESCE(client.Name, N''), N' / ', COALESCE(agent.Name, N''), N' · ', COALESCE(asset.FormattedAddressComma, N''), N' · ', COALESCE(manager.FullName, N''))) AS TertiaryText,
               CASE WHEN j.Number = @CleanSearchText THEN 1 ELSE 10 END AS SearchRank
        FROM SJob.Jobs AS j
        JOIN SCore.EntityHobts AS eh
          ON eh.SchemaName = N'SJob'
         AND eh.ObjectName = N'Jobs'
         AND eh.IsMainHoBT = 1
         AND eh.RowStatus NOT IN (0,254)
        JOIN SCore.EntityTypes AS et
          ON et.ID = eh.EntityTypeID
         AND et.RowStatus NOT IN (0,254)
        LEFT JOIN SCrm.Accounts AS client
          ON client.ID = j.ClientAccountID
         AND client.RowStatus NOT IN (0,254)
        LEFT JOIN SCrm.Accounts AS agent
          ON agent.ID = j.AgentAccountID
         AND agent.RowStatus NOT IN (0,254)
        LEFT JOIN SJob.Assets AS asset
          ON asset.ID = j.UprnID
         AND asset.RowStatus NOT IN (0,254)
        LEFT JOIN SCore.Identities AS manager
          ON manager.ID = j.SurveyorID
         AND manager.RowStatus NOT IN (0,254)
        WHERE j.RowStatus NOT IN (0,254)
          AND j.ID > 0
          AND (NOT EXISTS (SELECT 1 FROM @Filters) OR EXISTS (SELECT 1 FROM @Filters AS f WHERE f.ModuleKey = N'JOBS'))
          AND EXISTS (SELECT 1 FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr)
          AND (
                 j.Number LIKE @Pattern
              OR j.JobDescription LIKE @Pattern
              OR j.ExternalReference LIKE @Pattern
              OR client.Name LIKE @Pattern
              OR agent.Name LIKE @Pattern
              OR asset.FormattedAddressComma LIKE @Pattern
              OR manager.FullName LIKE @Pattern
          )

        UNION ALL

        SELECT N'ASSETS' AS ModuleKey,
               N'Assets' AS ModuleDisplayName,
               asset.Guid AS RecordGuid,
               et.Guid AS EntityTypeGuid,
               et.Name AS EntityTypeName,
               COALESCE(NULLIF(et.DetailPageUrl, N''), N'DynamicEdit') AS DetailPageUri,
               CONVERT(NVARCHAR(500), CONCAT(N'Asset ', CONVERT(NVARCHAR(50), asset.AssetNumber))) AS PrimaryText,
               CONVERT(NVARCHAR(1000), COALESCE(NULLIF(LTRIM(RTRIM(asset.FormattedAddressComma)), N''), asset.Name)) AS SecondaryText,
               CONVERT(NVARCHAR(1000), CONCAT(COALESCE(asset.Name, N''), N' · ', COALESCE(asset.Postcode, N''), N' · ', COALESCE(owner.Name, N''))) AS TertiaryText,
               CASE WHEN CONVERT(NVARCHAR(50), asset.AssetNumber) = @CleanSearchText THEN 2 ELSE 20 END AS SearchRank
        FROM SJob.Assets AS asset
        JOIN SCore.EntityHobts AS eh
          ON eh.SchemaName = N'SJob'
         AND eh.ObjectName = N'Assets'
         AND eh.IsMainHoBT = 1
         AND eh.RowStatus NOT IN (0,254)
        JOIN SCore.EntityTypes AS et
          ON et.ID = eh.EntityTypeID
         AND et.RowStatus NOT IN (0,254)
        LEFT JOIN SCrm.Accounts AS owner
          ON owner.ID = asset.OwnerAccountId
         AND owner.RowStatus NOT IN (0,254)
        WHERE asset.RowStatus NOT IN (0,254)
          AND asset.ID > 0
          AND (NOT EXISTS (SELECT 1 FROM @Filters) OR EXISTS (SELECT 1 FROM @Filters AS f WHERE f.ModuleKey = N'ASSETS'))
          AND EXISTS (SELECT 1 FROM SCore.ObjectSecurityForUser_CanRead(asset.Guid, @UserId) AS oscr)
          AND (
                 CONVERT(NVARCHAR(50), asset.AssetNumber) LIKE @Pattern
              OR asset.Name LIKE @Pattern
              OR asset.Number LIKE @Pattern
              OR asset.FormattedAddressComma LIKE @Pattern
              OR asset.Postcode LIKE @Pattern
              OR asset.GovernmentUPRN LIKE @Pattern
              OR owner.Name LIKE @Pattern
          )

        UNION ALL

        SELECT N'CRM' AS ModuleKey,
               N'CRM' AS ModuleDisplayName,
               account.Guid AS RecordGuid,
               et.Guid AS EntityTypeGuid,
               et.Name AS EntityTypeName,
               COALESCE(NULLIF(et.DetailPageUrl, N''), N'DynamicEdit') AS DetailPageUri,
               CONVERT(NVARCHAR(500), account.Name) AS PrimaryText,
               CONVERT(NVARCHAR(1000), CONCAT(N'Account', CASE WHEN account.Code <> N'' THEN N' · ' + account.Code ELSE N'' END)) AS SecondaryText,
               CONVERT(NVARCHAR(1000), CONCAT(COALESCE(account.CompanyRegistrationNumber, N''), CASE WHEN manager.FullName IS NULL THEN N'' ELSE N' · ' + manager.FullName END)) AS TertiaryText,
               CASE WHEN account.Name = @CleanSearchText THEN 3 ELSE 30 END AS SearchRank
        FROM SCrm.Accounts AS account
        JOIN SCore.EntityHobts AS eh
          ON eh.SchemaName = N'SCrm'
         AND eh.ObjectName = N'Accounts'
         AND eh.IsMainHoBT = 1
         AND eh.RowStatus NOT IN (0,254)
        JOIN SCore.EntityTypes AS et
          ON et.ID = eh.EntityTypeID
         AND et.RowStatus NOT IN (0,254)
        LEFT JOIN SCore.Identities AS manager
          ON manager.ID = account.RelationshipManagerUserId
         AND manager.RowStatus NOT IN (0,254)
        WHERE account.RowStatus NOT IN (0,254)
          AND account.ID > 0
          AND (NOT EXISTS (SELECT 1 FROM @Filters) OR EXISTS (SELECT 1 FROM @Filters AS f WHERE f.ModuleKey = N'CRM'))
          AND EXISTS (SELECT 1 FROM SCore.ObjectSecurityForUser_CanRead(account.Guid, @UserId) AS oscr)
          AND (
                 account.Name LIKE @Pattern
              OR account.Code LIKE @Pattern
              OR account.CompanyRegistrationNumber LIKE @Pattern
              OR manager.FullName LIKE @Pattern
          )

        UNION ALL

        SELECT N'CRM' AS ModuleKey,
               N'CRM' AS ModuleDisplayName,
               contact.Guid AS RecordGuid,
               et.Guid AS EntityTypeGuid,
               et.Name AS EntityTypeName,
               COALESCE(NULLIF(et.DetailPageUrl, N''), N'DynamicEdit') AS DetailPageUri,
               CONVERT(NVARCHAR(500), contact.DisplayName) AS PrimaryText,
               CONVERT(NVARCHAR(1000), CONCAT(N'Contact', CASE WHEN account.Name IS NULL THEN N'' ELSE N' · ' + account.Name END)) AS SecondaryText,
               CONVERT(NVARCHAR(1000), CONCAT(COALESCE(contact.FirstName, N''), N' ', COALESCE(contact.Surname, N''), CASE WHEN contact.PostNominals = N'' THEN N'' ELSE N' · ' + contact.PostNominals END)) AS TertiaryText,
               CASE WHEN contact.DisplayName = @CleanSearchText THEN 4 ELSE 35 END AS SearchRank
        FROM SCrm.Contacts AS contact
        JOIN SCore.EntityHobts AS eh
          ON eh.SchemaName = N'SCrm'
         AND eh.ObjectName = N'Contacts'
         AND eh.IsMainHoBT = 1
         AND eh.RowStatus NOT IN (0,254)
        JOIN SCore.EntityTypes AS et
          ON et.ID = eh.EntityTypeID
         AND et.RowStatus NOT IN (0,254)
        LEFT JOIN SCrm.Accounts AS account
          ON account.ID = contact.PrimaryAccountID
         AND account.RowStatus NOT IN (0,254)
        WHERE contact.RowStatus NOT IN (0,254)
          AND contact.ID > 0
          AND (NOT EXISTS (SELECT 1 FROM @Filters) OR EXISTS (SELECT 1 FROM @Filters AS f WHERE f.ModuleKey = N'CRM'))
          AND EXISTS (SELECT 1 FROM SCore.ObjectSecurityForUser_CanRead(contact.Guid, @UserId) AS oscr)
          AND (
                 contact.DisplayName LIKE @Pattern
              OR contact.FirstName LIKE @Pattern
              OR contact.Surname LIKE @Pattern
              OR contact.PostNominals LIKE @Pattern
              OR account.Name LIKE @Pattern
          )

        UNION ALL

        SELECT N'ENQUIRIES' AS ModuleKey,
               N'Enquiries' AS ModuleDisplayName,
               enquiry.Guid AS RecordGuid,
               et.Guid AS EntityTypeGuid,
               et.Name AS EntityTypeName,
               COALESCE(NULLIF(et.DetailPageUrl, N''), N'DynamicEdit') AS DetailPageUri,
               CONVERT(NVARCHAR(500), N'Enquiry ' + enquiry.Number) AS PrimaryText,
               CONVERT(NVARCHAR(1000), COALESCE(NULLIF(LTRIM(RTRIM(enquiry.DescriptionOfWorks)), N''), N'No description')) AS SecondaryText,
               CONVERT(NVARCHAR(1000), CONCAT(COALESCE(NULLIF(client.Name, N''), enquiry.ClientName), N' / ', COALESCE(NULLIF(agent.Name, N''), enquiry.AgentName), N' · ', COALESCE(asset.FormattedAddressComma, enquiry.PropertyNameNumber + N' ' + enquiry.PropertyAddressLine1))) AS TertiaryText,
               CASE WHEN enquiry.Number = @CleanSearchText THEN 5 ELSE 40 END AS SearchRank
        FROM SSop.Enquiries AS enquiry
        JOIN SCore.EntityHobts AS eh
          ON eh.SchemaName = N'SSop'
         AND eh.ObjectName = N'Enquiries'
         AND eh.IsMainHoBT = 1
         AND eh.RowStatus NOT IN (0,254)
        JOIN SCore.EntityTypes AS et
          ON et.ID = eh.EntityTypeID
         AND et.RowStatus NOT IN (0,254)
        LEFT JOIN SCrm.Accounts AS client
          ON client.ID = enquiry.ClientAccountId
         AND client.RowStatus NOT IN (0,254)
        LEFT JOIN SCrm.Accounts AS agent
          ON agent.ID = enquiry.AgentAccountId
         AND agent.RowStatus NOT IN (0,254)
        LEFT JOIN SJob.Assets AS asset
          ON asset.ID = enquiry.PropertyId
         AND asset.RowStatus NOT IN (0,254)
        WHERE enquiry.RowStatus NOT IN (0,254)
          AND enquiry.ID > 0
          AND (NOT EXISTS (SELECT 1 FROM @Filters) OR EXISTS (SELECT 1 FROM @Filters AS f WHERE f.ModuleKey = N'ENQUIRIES'))
          AND EXISTS (SELECT 1 FROM SCore.ObjectSecurityForUser_CanRead(enquiry.Guid, @UserId) AS oscr)
          AND (
                 enquiry.Number LIKE @Pattern
              OR enquiry.ExternalReference LIKE @Pattern
              OR enquiry.DescriptionOfWorks LIKE @Pattern
              OR enquiry.ClientName LIKE @Pattern
              OR enquiry.AgentName LIKE @Pattern
              OR client.Name LIKE @Pattern
              OR agent.Name LIKE @Pattern
              OR asset.FormattedAddressComma LIKE @Pattern
              OR enquiry.PropertyNameNumber LIKE @Pattern
              OR enquiry.PropertyAddressLine1 LIKE @Pattern
          )

        UNION ALL

        SELECT N'QUOTES' AS ModuleKey,
               N'Quotes' AS ModuleDisplayName,
               quote.Guid AS RecordGuid,
               et.Guid AS EntityTypeGuid,
               et.Name AS EntityTypeName,
               COALESCE(NULLIF(et.DetailPageUrl, N''), N'DynamicEdit') AS DetailPageUri,
               CONVERT(NVARCHAR(500), N'Quote ' + quote.FullNumber) AS PrimaryText,
               CONVERT(NVARCHAR(1000), COALESCE(NULLIF(LTRIM(RTRIM(quote.DescriptionOfWorks)), N''), LEFT(quote.Overview, 1000))) AS SecondaryText,
               CONVERT(NVARCHAR(1000), CONCAT(COALESCE(client.Name, N''), CASE WHEN consultant.FullName IS NULL THEN N'' ELSE N' · ' + consultant.FullName END)) AS TertiaryText,
               CASE WHEN quote.FullNumber = @CleanSearchText THEN 6 ELSE 50 END AS SearchRank
        FROM SSop.Quotes AS quote
        JOIN SCore.EntityHobts AS eh
          ON eh.SchemaName = N'SSop'
         AND eh.ObjectName = N'Quotes'
         AND eh.IsMainHoBT = 1
         AND eh.RowStatus NOT IN (0,254)
        JOIN SCore.EntityTypes AS et
          ON et.ID = eh.EntityTypeID
         AND et.RowStatus NOT IN (0,254)
        LEFT JOIN SCrm.Accounts AS client
          ON client.ID = quote.ClientAccountId
         AND client.RowStatus NOT IN (0,254)
        LEFT JOIN SCore.Identities AS consultant
          ON consultant.ID = quote.QuotingConsultantId
         AND consultant.RowStatus NOT IN (0,254)
        WHERE quote.RowStatus NOT IN (0,254)
          AND quote.ID > 0
          AND (NOT EXISTS (SELECT 1 FROM @Filters) OR EXISTS (SELECT 1 FROM @Filters AS f WHERE f.ModuleKey = N'QUOTES'))
          AND EXISTS (SELECT 1 FROM SCore.ObjectSecurityForUser_CanRead(quote.Guid, @UserId) AS oscr)
          AND (
                 quote.Number LIKE @Pattern
              OR quote.FullNumber LIKE @Pattern
              OR quote.DescriptionOfWorks LIKE @Pattern
              OR quote.Overview LIKE @Pattern
              OR client.Name LIKE @Pattern
              OR consultant.FullName LIKE @Pattern
          )

        UNION ALL

        SELECT N'PROJECTS' AS ModuleKey,
               N'Client Projects' AS ModuleDisplayName,
               project.Guid AS RecordGuid,
               et.Guid AS EntityTypeGuid,
               et.Name AS EntityTypeName,
               COALESCE(NULLIF(et.DetailPageUrl, N''), N'DynamicEdit') AS DetailPageUri,
               CONVERT(NVARCHAR(500), CONCAT(N'Project ', CONVERT(NVARCHAR(50), project.Number))) AS PrimaryText,
               CONVERT(NVARCHAR(1000), COALESCE(NULLIF(LTRIM(RTRIM(project.ProjectDescription)), N''), N'No description')) AS SecondaryText,
               CONVERT(NVARCHAR(1000), project.ExternalReference) AS TertiaryText,
               CASE WHEN CONVERT(NVARCHAR(50), project.Number) = @CleanSearchText THEN 7 ELSE 60 END AS SearchRank
        FROM SSop.Projects AS project
        JOIN SCore.EntityHobts AS eh
          ON eh.SchemaName = N'SSop'
         AND eh.ObjectName = N'Projects'
         AND eh.IsMainHoBT = 1
         AND eh.RowStatus NOT IN (0,254)
        JOIN SCore.EntityTypes AS et
          ON et.ID = eh.EntityTypeID
         AND et.RowStatus NOT IN (0,254)
        WHERE project.RowStatus NOT IN (0,254)
          AND project.ID > 0
          AND (NOT EXISTS (SELECT 1 FROM @Filters) OR EXISTS (SELECT 1 FROM @Filters AS f WHERE f.ModuleKey = N'PROJECTS'))
          AND EXISTS (SELECT 1 FROM SCore.ObjectSecurityForUser_CanRead(project.Guid, @UserId) AS oscr)
          AND (
                 CONVERT(NVARCHAR(50), project.Number) LIKE @Pattern
              OR project.ExternalReference LIKE @Pattern
              OR project.ProjectDescription LIKE @Pattern
          )

        UNION ALL

        SELECT N'PROJECT_MANAGER' AS ModuleKey,
               N'Project Manager' AS ModuleDisplayName,
               identityRow.Guid AS RecordGuid,
               et.Guid AS EntityTypeGuid,
               et.Name AS EntityTypeName,
               COALESCE(NULLIF(et.DetailPageUrl, N''), N'DynamicEdit') AS DetailPageUri,
               CONVERT(NVARCHAR(500), identityRow.FullName) AS PrimaryText,
               CONVERT(NVARCHAR(1000), CONCAT(N'Project Manager', CASE WHEN identityRow.JobTitle <> N'' THEN N' · ' + identityRow.JobTitle ELSE N'' END)) AS SecondaryText,
               CONVERT(NVARCHAR(1000), CONCAT(identityRow.EmailAddress, CASE WHEN org.Name IS NULL THEN N'' ELSE N' · ' + org.Name END)) AS TertiaryText,
               CASE WHEN identityRow.FullName = @CleanSearchText THEN 8 ELSE 70 END AS SearchRank
        FROM SCore.Identities AS identityRow
        JOIN SCore.EntityHobts AS eh
          ON eh.SchemaName = N'SCore'
         AND eh.ObjectName = N'Identities'
         AND eh.IsMainHoBT = 1
         AND eh.RowStatus NOT IN (0,254)
        JOIN SCore.EntityTypes AS et
          ON et.ID = eh.EntityTypeID
         AND et.RowStatus NOT IN (0,254)
        LEFT JOIN SCore.OrganisationalUnits AS org
          ON org.ID = identityRow.OriganisationalUnitId
         AND org.RowStatus NOT IN (0,254)
        WHERE identityRow.RowStatus NOT IN (0,254)
          AND identityRow.ID > 0
          AND identityRow.IsActive = 1
          AND (NOT EXISTS (SELECT 1 FROM @Filters) OR EXISTS (SELECT 1 FROM @Filters AS f WHERE f.ModuleKey = N'PROJECT_MANAGER'))
          AND EXISTS (SELECT 1 FROM SCore.ObjectSecurityForUser_CanRead(identityRow.Guid, @UserId) AS oscr)
          AND (
                 identityRow.FullName LIKE @Pattern
              OR identityRow.EmailAddress LIKE @Pattern
              OR identityRow.JobTitle LIKE @Pattern
              OR org.Name LIKE @Pattern
          )
        ) AS RawResults
    ) AS RankedResults
    WHERE RankedResults.ModuleRowNumber <= @SafeTake
    ORDER BY RankedResults.ModuleDisplayName,
             RankedResults.SearchRank,
             RankedResults.PrimaryText;

    RETURN;
END;
GO