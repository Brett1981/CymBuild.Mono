SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SSop].[tvf_ProjectDocumentNavigation]')
GO
/*

--Job
select * from [SSop].[tvf_ProjectDocumentNavigation] (
722,9,'b9d44428-c3f0-4e32-922d-9dc53d214c23')

--Enquiry
select * from [SSop].[tvf_ProjectDocumentNavigation] (
722,83,'7D3330CA-3D3F-4B14-A6E2-947F42983F8D')

--Qoute
select * from [SSop].[tvf_ProjectDocumentNavigation] (
722,55,'48A13C58-892E-4A63-88DE-A2C0F9174282')

--Project
select * from [SSop].[tvf_ProjectDocumentNavigation] (
722,94,'77E27402-2BD9-434B-96E8-8B08A548582C')

*/

CREATE FUNCTION [SSop].[tvf_ProjectDocumentNavigation]
(
    @UserId INT,
    @EntityTypeId INT,
    @RecordGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN

WITH
ResolvedProjects AS
(
    /* Project */
    SELECT
        p.ID   AS ProjectId,
        p.Guid AS ProjectGuid
    FROM SSop.Projects p
    WHERE @EntityTypeId = 94
      AND p.Guid = @RecordGuid
      AND p.RowStatus NOT IN (0, 254)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(p.Guid, @UserId) oscr
      )

    UNION

    /* Enquiry -> Project */
    SELECT
        p.ID   AS ProjectId,
        p.Guid AS ProjectGuid
    FROM SSop.Enquiries e
    INNER JOIN SSop.Projects p
        ON p.ID = e.ProjectId
       AND p.RowStatus NOT IN (0, 254)
    WHERE @EntityTypeId = 83
      AND e.Guid = @RecordGuid
      AND e.RowStatus NOT IN (0, 254)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) oscr
      )

    UNION

    /* Quote -> Project */
    SELECT
        p.ID   AS ProjectId,
        p.Guid AS ProjectGuid
    FROM SSop.Quotes q
    INNER JOIN SSop.Projects p
        ON p.ID = q.ProjectId
       AND p.RowStatus NOT IN (0, 254)
    WHERE @EntityTypeId = 55
      AND q.Guid = @RecordGuid
      AND q.RowStatus NOT IN (0, 254)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
      )

    UNION

    /* Job -> Project */
    SELECT
        p.ID   AS ProjectId,
        p.Guid AS ProjectGuid
    FROM SJob.Jobs j
    INNER JOIN SSop.Projects p
        ON p.ID = j.ProjectId
       AND p.RowStatus NOT IN (0, 254)
    WHERE @EntityTypeId = 9
      AND j.Guid = @RecordGuid
      AND j.RowStatus NOT IN (0, 254)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
      )

    UNION

    /* Asset -> all linked Projects */
    SELECT DISTINCT
        p.ID   AS ProjectId,
        p.Guid AS ProjectGuid
    FROM SJob.Assets a
    INNER JOIN SSop.Projects p
        ON p.RowStatus NOT IN (0, 254)
    WHERE @EntityTypeId = 27
      AND a.Guid = @RecordGuid
      AND a.ID > 0
      AND a.RowStatus NOT IN (0, 254)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) oscr
      )
      AND
      (
          EXISTS
          (
              SELECT 1
              FROM SSop.Enquiries e
              WHERE e.ProjectId = p.ID
                AND e.RowStatus NOT IN (0, 254)
                AND e.PropertyId = a.ID
                AND EXISTS
                (
                    SELECT 1
                    FROM SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) oscr
                )
          )
          OR EXISTS
          (
              SELECT 1
              FROM SSop.Quotes q
              WHERE q.ProjectId = p.ID
                AND q.RowStatus NOT IN (0, 254)
                AND q.UprnId = a.ID
                AND EXISTS
                (
                    SELECT 1
                    FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
                )
          )
          OR EXISTS
          (
              SELECT 1
              FROM SJob.Jobs j
              WHERE j.ProjectId = p.ID
                AND j.RowStatus NOT IN (0, 254)
                AND j.UprnID = a.ID
                AND EXISTS
                (
                    SELECT 1
                    FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
                )
          )
      )

    UNION

    /* Account -> all linked Projects */
    SELECT DISTINCT
        p.ID   AS ProjectId,
        p.Guid AS ProjectGuid
    FROM SCrm.Accounts a
    INNER JOIN SSop.Projects p
        ON p.RowStatus NOT IN (0, 254)
    WHERE @EntityTypeId = 15
      AND a.Guid = @RecordGuid
      AND a.ID > 0
      AND a.RowStatus NOT IN (0, 254)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) oscr
      )
      AND
      (
          EXISTS
          (
              SELECT 1
              FROM SSop.Enquiries e
              WHERE e.ProjectId = p.ID
                AND e.RowStatus NOT IN (0, 254)
                AND a.ID IN (e.ClientAccountId, e.AgentAccountId, e.FinanceAccountId)
                AND EXISTS
                (
                    SELECT 1
                    FROM SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) oscr
                )
          )
          OR EXISTS
          (
              SELECT 1
              FROM SSop.Quotes q
              WHERE q.ProjectId = p.ID
                AND q.RowStatus NOT IN (0, 254)
                AND a.ID IN (q.ClientAccountId, q.AgentAccountId)
                AND EXISTS
                (
                    SELECT 1
                    FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
                )
          )
          OR EXISTS
          (
              SELECT 1
              FROM SJob.Jobs j
              WHERE j.ProjectId = p.ID
                AND j.RowStatus NOT IN (0, 254)
                AND a.ID IN (j.ClientAccountID, j.AgentAccountID, j.FinanceAccountID)
                AND EXISTS
                (
                    SELECT 1
                    FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
                )
          )
      )
),

ProjectRows AS
(
    SELECT
        rp.ProjectId,
        rp.ProjectGuid,
        94 AS EntityTypeId,
        CAST(N'Project' AS NVARCHAR(50)) AS NavigationGroup,
        CAST(10 AS INT) AS NavigationSortOrder,
        p.ID AS RecordId,
        p.Guid AS RecordGuid,
        CAST(p.Number AS NVARCHAR(50)) AS RecordNumber,
        CAST(CONCAT(N'Project ', p.Number) AS NVARCHAR(250)) AS RecordTitle,
        CAST(p.ProjectDescription AS NVARCHAR(1000)) AS RecordSubtitle,
        CAST(NULL AS INT) AS RelatedAccountId,
        CAST(NULL AS INT) AS RelatedAssetId,
        CAST(NULL AS NVARCHAR(50)) AS AccountRole,
        CAST(p.Number AS NVARCHAR(100)) AS RecordSortValue
    FROM ResolvedProjects rp
    INNER JOIN SSop.Projects p
        ON p.ID = rp.ProjectId
       AND p.RowStatus NOT IN (0, 254)
    WHERE EXISTS
    (
        SELECT 1
        FROM SCore.ObjectSecurityForUser_CanRead(p.Guid, @UserId) oscr
    )
),

EnquiryRows AS
(
    SELECT
        rp.ProjectId,
        rp.ProjectGuid,
        83 AS EntityTypeId,
        CAST(N'Enquiries' AS NVARCHAR(50)) AS NavigationGroup,
        CAST(20 AS INT) AS NavigationSortOrder,
        e.ID AS RecordId,
        e.Guid AS RecordGuid,
        e.Number AS RecordNumber,
        CAST(CONCAT(N'Enquiry ', e.Number) AS NVARCHAR(250)) AS RecordTitle,
        CAST(e.DescriptionOfWorks AS NVARCHAR(1000)) AS RecordSubtitle,
        NULLIF(e.ClientAccountId, -1) AS RelatedAccountId,
        NULLIF(e.PropertyId, -1) AS RelatedAssetId,
        CAST(N'Client' AS NVARCHAR(50)) AS AccountRole,
        CAST(e.Number AS NVARCHAR(100)) AS RecordSortValue
    FROM ResolvedProjects rp
    INNER JOIN SSop.Enquiries e
        ON e.ProjectId = rp.ProjectId
       AND e.RowStatus NOT IN (0, 254)
    WHERE EXISTS
    (
        SELECT 1
        FROM SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) oscr
    )
),

QuoteRows AS
(
    SELECT
        rp.ProjectId,
        rp.ProjectGuid,
        55 AS EntityTypeId,
        CAST(N'Quotes' AS NVARCHAR(50)) AS NavigationGroup,
        CAST(30 AS INT) AS NavigationSortOrder,
        q.ID AS RecordId,
        q.Guid AS RecordGuid,
        q.FullNumber AS RecordNumber,
        CAST(CONCAT(N'Quote ', q.FullNumber) AS NVARCHAR(250)) AS RecordTitle,
        CAST(COALESCE(NULLIF(q.Overview, N''), q.DescriptionOfWorks) AS NVARCHAR(1000)) AS RecordSubtitle,
        NULLIF(q.ClientAccountId, -1) AS RelatedAccountId,
        NULLIF(q.UprnId, -1) AS RelatedAssetId,
        CAST(N'Client' AS NVARCHAR(50)) AS AccountRole,
        CAST(q.FullNumber AS NVARCHAR(100)) AS RecordSortValue
    FROM ResolvedProjects rp
    INNER JOIN SSop.Quotes q
        ON q.ProjectId = rp.ProjectId
       AND q.RowStatus NOT IN (0, 254)
    WHERE EXISTS
    (
        SELECT 1
        FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
    )
),

JobRows AS
(
    SELECT
        rp.ProjectId,
        rp.ProjectGuid,
        9 AS EntityTypeId,
        CAST(N'Jobs' AS NVARCHAR(50)) AS NavigationGroup,
        CAST(40 AS INT) AS NavigationSortOrder,
        j.ID AS RecordId,
        j.Guid AS RecordGuid,
        j.Number AS RecordNumber,
        CAST(CONCAT(N'Job ', j.Number) AS NVARCHAR(250)) AS RecordTitle,
        CAST(j.JobDescription AS NVARCHAR(1000)) AS RecordSubtitle,
        NULLIF(j.ClientAccountID, -1) AS RelatedAccountId,
        NULLIF(j.UprnID, -1) AS RelatedAssetId,
        CAST(N'Client' AS NVARCHAR(50)) AS AccountRole,
        CAST(j.Number AS NVARCHAR(100)) AS RecordSortValue
    FROM ResolvedProjects rp
    INNER JOIN SJob.Jobs j
        ON j.ProjectId = rp.ProjectId
       AND j.RowStatus NOT IN (0, 254)
    WHERE EXISTS
    (
        SELECT 1
        FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
    )
),

AssetRows AS
(
    SELECT DISTINCT
        rp.ProjectId,
        rp.ProjectGuid,
        27 AS EntityTypeId,
        CAST(N'Assets' AS NVARCHAR(50)) AS NavigationGroup,
        CAST(50 AS INT) AS NavigationSortOrder,
        a.ID AS RecordId,
        a.Guid AS RecordGuid,
        CAST(a.ID AS NVARCHAR(50)) AS RecordNumber,
        CAST(CONCAT(N'Asset ', a.ID) AS NVARCHAR(250)) AS RecordTitle,
        CAST(NULL AS NVARCHAR(1000)) AS RecordSubtitle,
        CAST(NULL AS INT) AS RelatedAccountId,
        a.ID AS RelatedAssetId,
        CAST(NULL AS NVARCHAR(50)) AS AccountRole,
        CAST(RIGHT(REPLICATE(N'0', 10) + CAST(a.ID AS NVARCHAR(10)), 10) AS NVARCHAR(100)) AS RecordSortValue
    FROM ResolvedProjects rp
    INNER JOIN SJob.Assets a
        ON a.ID > 0
       AND a.RowStatus NOT IN (0, 254)
       AND
       (
            EXISTS
            (
                SELECT 1
                FROM SSop.Enquiries e
                WHERE e.ProjectId = rp.ProjectId
                  AND e.RowStatus NOT IN (0, 254)
                  AND e.PropertyId = a.ID
                  AND EXISTS
                  (
                      SELECT 1
                      FROM SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) oscr
                  )
            )
            OR EXISTS
            (
                SELECT 1
                FROM SSop.Quotes q
                WHERE q.ProjectId = rp.ProjectId
                  AND q.RowStatus NOT IN (0, 254)
                  AND q.UprnId = a.ID
                  AND EXISTS
                  (
                      SELECT 1
                      FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
                  )
            )
            OR EXISTS
            (
                SELECT 1
                FROM SJob.Jobs j
                WHERE j.ProjectId = rp.ProjectId
                  AND j.RowStatus NOT IN (0, 254)
                  AND j.UprnID = a.ID
                  AND EXISTS
                  (
                      SELECT 1
                      FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
                  )
            )
       )
    WHERE EXISTS
    (
        SELECT 1
        FROM SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) oscr
    )
),

AccountRoleSource AS
(
    SELECT
        e.ProjectId,
        e.ClientAccountId AS AccountId,
        CAST(N'Clients' AS NVARCHAR(50)) AS NavigationGroup,
        CAST(60 AS INT) AS NavigationSortOrder,
        CAST(N'Client' AS NVARCHAR(50)) AS AccountRole
    FROM SSop.Enquiries e
    WHERE e.RowStatus NOT IN (0, 254)
      AND e.ClientAccountId > 0
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) oscr
      )

    UNION ALL

    SELECT
        e.ProjectId,
        e.AgentAccountId AS AccountId,
        CAST(N'Agents' AS NVARCHAR(50)) AS NavigationGroup,
        CAST(70 AS INT) AS NavigationSortOrder,
        CAST(N'Agent' AS NVARCHAR(50)) AS AccountRole
    FROM SSop.Enquiries e
    WHERE e.RowStatus NOT IN (0, 254)
      AND e.AgentAccountId > 0
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) oscr
      )

    UNION ALL

    SELECT
        e.ProjectId,
        e.FinanceAccountId AS AccountId,
        CAST(N'Finance' AS NVARCHAR(50)) AS NavigationGroup,
        CAST(80 AS INT) AS NavigationSortOrder,
        CAST(N'Finance' AS NVARCHAR(50)) AS AccountRole
    FROM SSop.Enquiries e
    WHERE e.RowStatus NOT IN (0, 254)
      AND e.FinanceAccountId > 0
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) oscr
      )

    UNION ALL

    SELECT
        q.ProjectId,
        q.ClientAccountId AS AccountId,
        CAST(N'Clients' AS NVARCHAR(50)) AS NavigationGroup,
        CAST(60 AS INT) AS NavigationSortOrder,
        CAST(N'Client' AS NVARCHAR(50)) AS AccountRole
    FROM SSop.Quotes q
    WHERE q.RowStatus NOT IN (0, 254)
      AND q.ClientAccountId > 0
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
      )

    UNION ALL

    SELECT
        q.ProjectId,
        q.AgentAccountId AS AccountId,
        CAST(N'Agents' AS NVARCHAR(50)) AS NavigationGroup,
        CAST(70 AS INT) AS NavigationSortOrder,
        CAST(N'Agent' AS NVARCHAR(50)) AS AccountRole
    FROM SSop.Quotes q
    WHERE q.RowStatus NOT IN (0, 254)
      AND q.AgentAccountId > 0
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
      )

    UNION ALL

    SELECT
        j.ProjectId,
        j.ClientAccountID AS AccountId,
        CAST(N'Clients' AS NVARCHAR(50)) AS NavigationGroup,
        CAST(60 AS INT) AS NavigationSortOrder,
        CAST(N'Client' AS NVARCHAR(50)) AS AccountRole
    FROM SJob.Jobs j
    WHERE j.RowStatus NOT IN (0, 254)
      AND j.ClientAccountID > 0
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
      )

    UNION ALL

    SELECT
        j.ProjectId,
        j.AgentAccountID AS AccountId,
        CAST(N'Agents' AS NVARCHAR(50)) AS NavigationGroup,
        CAST(70 AS INT) AS NavigationSortOrder,
        CAST(N'Agent' AS NVARCHAR(50)) AS AccountRole
    FROM SJob.Jobs j
    WHERE j.RowStatus NOT IN (0, 254)
      AND j.AgentAccountID > 0
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
      )

    UNION ALL

    SELECT
        j.ProjectId,
        j.FinanceAccountID AS AccountId,
        CAST(N'Finance' AS NVARCHAR(50)) AS NavigationGroup,
        CAST(80 AS INT) AS NavigationSortOrder,
        CAST(N'Finance' AS NVARCHAR(50)) AS AccountRole
    FROM SJob.Jobs j
    WHERE j.RowStatus NOT IN (0, 254)
      AND j.FinanceAccountID > 0
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
      )
),

AccountRows AS
(
    SELECT DISTINCT
        rp.ProjectId,
        rp.ProjectGuid,
        15 AS EntityTypeId,
        roles.NavigationGroup,
        roles.NavigationSortOrder,
        a.ID AS RecordId,
        a.Guid AS RecordGuid,
        a.Code AS RecordNumber,
        CAST(
            CASE
                WHEN NULLIF(a.Code, N'') IS NULL THEN a.Name
                ELSE CONCAT(a.Name, N' - ', a.Code)
            END
            AS NVARCHAR(250)
        ) AS RecordTitle,
        CAST(NULL AS NVARCHAR(1000)) AS RecordSubtitle,
        a.ID AS RelatedAccountId,
        CAST(NULL AS INT) AS RelatedAssetId,
        roles.AccountRole,
        CAST(
            CASE
                WHEN NULLIF(a.Code, N'') IS NULL THEN a.Name
                ELSE a.Code
            END
            AS NVARCHAR(100)
        ) AS RecordSortValue
    FROM ResolvedProjects rp
    INNER JOIN AccountRoleSource roles
        ON roles.ProjectId = rp.ProjectId
    INNER JOIN SCrm.Accounts a
        ON a.ID = roles.AccountId
       AND a.ID > 0
       AND a.RowStatus NOT IN (0, 254)
    WHERE EXISTS
    (
        SELECT 1
        FROM SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) oscr
    )
),

AllRows AS
(
    SELECT * FROM ProjectRows
    UNION ALL
    SELECT * FROM EnquiryRows
    UNION ALL
    SELECT * FROM QuoteRows
    UNION ALL
    SELECT * FROM JobRows
    UNION ALL
    SELECT * FROM AssetRows
    UNION ALL
    SELECT * FROM AccountRows
)

SELECT
    ar.ProjectId,
    ar.ProjectGuid,
    p.Number AS ProjectNumber,
    94 AS ProjectEntityTypeId,
    etProject.Name AS ProjectEntityTypeName,

    ar.EntityTypeId,
    et.Name AS EntityTypeName,
    et.Guid AS EntityTypeGuid,
    et.HasDocuments,

    ar.NavigationGroup,
    ar.NavigationSortOrder,

    CAST(
        CONCAT(
            ar.ProjectGuid, N'|',
            ar.EntityTypeId, N'|',
            ar.RecordGuid, N'|',
            ISNULL(ar.AccountRole, N'')
        ) AS NVARCHAR(200)
    ) AS NavigationKey,

    ar.RecordId,
    ar.RecordGuid,
    ar.RecordNumber,
    ar.RecordTitle,
    ar.RecordSubtitle,
    ar.RecordSortValue,

    ar.RelatedAccountId,
    ar.RelatedAssetId,
    ar.AccountRole,

    ses.ID AS SharepointStructureId,
    ses.SharePointSiteID,
    sps.Name AS SharepointSiteName,
    sps.SiteIdentifier AS SharepointSiteIdentifier,
    sps.SiteUrl AS SharepointSiteUrl,

    CAST(CASE WHEN ses.ID IS NULL THEN 0 ELSE 1 END AS BIT) AS HasSharepointStructure,
    CAST(CASE WHEN et.HasDocuments = 1 AND ses.ID IS NOT NULL THEN 1 ELSE 0 END AS BIT) AS CanBrowseDocuments
FROM AllRows ar
INNER JOIN SSop.Projects p
    ON p.ID = ar.ProjectId
   AND p.RowStatus NOT IN (0, 254)
INNER JOIN SCore.EntityTypes et
    ON et.ID = ar.EntityTypeId
   AND et.RowStatus NOT IN (0, 254)
INNER JOIN SCore.EntityTypes etProject
    ON etProject.ID = 94
   AND etProject.RowStatus NOT IN (0, 254)
LEFT JOIN SCore.SharepointEntityStructure ses
    ON ses.EntityTypeID = ar.EntityTypeId
   AND ses.RowStatus NOT IN (0, 254)
LEFT JOIN SCore.SharepointSites sps
    ON sps.ID = ses.SharePointSiteID
   AND sps.RowStatus NOT IN (0, 254);
GO