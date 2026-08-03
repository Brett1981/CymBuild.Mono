SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SSop].[tvf_ProjectDocumentNavigation]')
GO
PRINT (N'Create function [SSop].[tvf_ProjectDocumentNavigation]')
GO

CREATE FUNCTION [SSop].[tvf_ProjectDocumentNavigation]
(
    @UserId      INT,
    @EntityTypeId INT,
    @RecordGuid  UNIQUEIDENTIFIER
)
RETURNS TABLE
AS
RETURN
(
    WITH
    ResolvedProjects AS
    (
        /* Project */
        SELECT
            p.ID   AS ProjectId,
            p.Guid AS ProjectGuid
        FROM SSop.Projects AS p
        WHERE @EntityTypeId = 94
          AND p.Guid = @RecordGuid
          AND p.RowStatus NOT IN (0, 254)
          AND EXISTS
          (
              SELECT 1
              FROM SCore.ObjectSecurityForUser_CanRead(p.Guid, @UserId) AS oscr
          )

        UNION

        /* Enquiry -> Project */
        SELECT
            p.ID,
            p.Guid
        FROM SSop.Enquiries AS e
        INNER JOIN SSop.Projects AS p
            ON p.ID = e.ProjectId
           AND p.RowStatus NOT IN (0, 254)
        WHERE @EntityTypeId = 83
          AND e.Guid = @RecordGuid
          AND e.RowStatus NOT IN (0, 254)
          AND EXISTS
          (
              SELECT 1
              FROM SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) AS oscr
          )

        UNION

        /* Quote -> Project */
        SELECT
            p.ID,
            p.Guid
        FROM SSop.Quotes AS q
        INNER JOIN SSop.Projects AS p
            ON p.ID = q.ProjectId
           AND p.RowStatus NOT IN (0, 254)
        WHERE @EntityTypeId = 55
          AND q.Guid = @RecordGuid
          AND q.RowStatus NOT IN (0, 254)
          AND EXISTS
          (
              SELECT 1
              FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) AS oscr
          )

        UNION

        /* Job -> Project */
        SELECT
            p.ID,
            p.Guid
        FROM SJob.Jobs AS j
        INNER JOIN SSop.Projects AS p
            ON p.ID = j.ProjectId
           AND p.RowStatus NOT IN (0, 254)
        WHERE @EntityTypeId = 9
          AND j.Guid = @RecordGuid
          AND j.RowStatus NOT IN (0, 254)
          AND EXISTS
          (
              SELECT 1
              FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
          )

        UNION

        /* Asset -> all linked Projects */
        SELECT DISTINCT
            p.ID,
            p.Guid
        FROM SJob.Assets AS a
        INNER JOIN SSop.Projects AS p
            ON p.RowStatus NOT IN (0, 254)
        WHERE @EntityTypeId = 27
          AND a.Guid = @RecordGuid
          AND a.ID > 0
          AND a.RowStatus NOT IN (0, 254)
          AND EXISTS
          (
              SELECT 1
              FROM SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) AS oscr
          )
          AND
          (
              EXISTS
              (
                  SELECT 1
                  FROM SSop.Enquiries AS e
                  WHERE e.ProjectId = p.ID
                    AND e.RowStatus NOT IN (0, 254)
                    AND e.PropertyId = a.ID
                    AND EXISTS
                    (
                        SELECT 1
                        FROM SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) AS oscr
                    )
              )
              OR EXISTS
              (
                  SELECT 1
                  FROM SSop.Quotes AS q
                  WHERE q.ProjectId = p.ID
                    AND q.RowStatus NOT IN (0, 254)
                    AND q.UprnId = a.ID
                    AND EXISTS
                    (
                        SELECT 1
                        FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) AS oscr
                    )
              )
              OR EXISTS
              (
                  SELECT 1
                  FROM SJob.Jobs AS j
                  WHERE j.ProjectId = p.ID
                    AND j.RowStatus NOT IN (0, 254)
                    AND j.UprnID = a.ID
                    AND EXISTS
                    (
                        SELECT 1
                        FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
                    )
              )
          )

        UNION

        /* Account -> all linked Projects */
        SELECT DISTINCT
            p.ID,
            p.Guid
        FROM SCrm.Accounts AS a
        INNER JOIN SSop.Projects AS p
            ON p.RowStatus NOT IN (0, 254)
        WHERE @EntityTypeId = 15
          AND a.Guid = @RecordGuid
          AND a.ID > 0
          AND a.RowStatus NOT IN (0, 254)
          AND EXISTS
          (
              SELECT 1
              FROM SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) AS oscr
          )
          AND
          (
              EXISTS
              (
                  SELECT 1
                  FROM SSop.Enquiries AS e
                  WHERE e.ProjectId = p.ID
                    AND e.RowStatus NOT IN (0, 254)
                    AND a.ID IN
                    (
                        e.ClientAccountId,
                        e.AgentAccountId,
                        e.FinanceAccountId
                    )
                    AND EXISTS
                    (
                        SELECT 1
                        FROM SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) AS oscr
                    )
              )
              OR EXISTS
              (
                  SELECT 1
                  FROM SSop.Quotes AS q
                  WHERE q.ProjectId = p.ID
                    AND q.RowStatus NOT IN (0, 254)
                    AND a.ID IN
                    (
                        q.ClientAccountId,
                        q.AgentAccountId
                    )
                    AND EXISTS
                    (
                        SELECT 1
                        FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) AS oscr
                    )
              )
              OR EXISTS
              (
                  SELECT 1
                  FROM SJob.Jobs AS j
                  WHERE j.ProjectId = p.ID
                    AND j.RowStatus NOT IN (0, 254)
                    AND a.ID IN
                    (
                        j.ClientAccountID,
                        j.AgentAccountID,
                        j.FinanceAccountID
                    )
                    AND EXISTS
                    (
                        SELECT 1
                        FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
                    )
              )
          )
    ),
    ProjectRows AS
    (
        SELECT
            rp.ProjectId,
            rp.ProjectGuid,
            CAST(94 AS INT) AS EntityTypeId,
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
        FROM ResolvedProjects AS rp
        INNER JOIN SSop.Projects AS p
            ON p.ID = rp.ProjectId
           AND p.RowStatus NOT IN (0, 254)
        WHERE EXISTS
        (
            SELECT 1
            FROM SCore.ObjectSecurityForUser_CanRead(p.Guid, @UserId) AS oscr
        )
    ),
    EnquiryRows AS
    (
        SELECT
            rp.ProjectId,
            rp.ProjectGuid,
            CAST(83 AS INT) AS EntityTypeId,
            CAST(N'Enquiries' AS NVARCHAR(50)) AS NavigationGroup,
            CAST(20 AS INT) AS NavigationSortOrder,
            e.ID AS RecordId,
            e.Guid AS RecordGuid,
            CAST(e.Number AS NVARCHAR(50)) AS RecordNumber,
            CAST(CONCAT(N'Enquiry ', e.Number) AS NVARCHAR(250)) AS RecordTitle,
            CAST(e.DescriptionOfWorks AS NVARCHAR(1000)) AS RecordSubtitle,
            NULLIF(e.ClientAccountId, -1) AS RelatedAccountId,
            NULLIF(e.PropertyId, -1) AS RelatedAssetId,
            CAST(N'Client' AS NVARCHAR(50)) AS AccountRole,
            CAST(e.Number AS NVARCHAR(100)) AS RecordSortValue
        FROM ResolvedProjects AS rp
        INNER JOIN SSop.Enquiries AS e
            ON e.ProjectId = rp.ProjectId
           AND e.RowStatus NOT IN (0, 254)
        WHERE EXISTS
        (
            SELECT 1
            FROM SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) AS oscr
        )
    ),
    QuoteRows AS
    (
        SELECT
            rp.ProjectId,
            rp.ProjectGuid,
            CAST(55 AS INT) AS EntityTypeId,
            CAST(N'Quotes' AS NVARCHAR(50)) AS NavigationGroup,
            CAST(30 AS INT) AS NavigationSortOrder,
            q.ID AS RecordId,
            q.Guid AS RecordGuid,
            CAST(q.FullNumber AS NVARCHAR(50)) AS RecordNumber,
            CAST(CONCAT(N'Quote ', q.FullNumber) AS NVARCHAR(250)) AS RecordTitle,
            CAST(
                COALESCE(NULLIF(q.Overview, N''), q.DescriptionOfWorks)
                AS NVARCHAR(1000)
            ) AS RecordSubtitle,
            NULLIF(q.ClientAccountId, -1) AS RelatedAccountId,
            NULLIF(q.UprnId, -1) AS RelatedAssetId,
            CAST(N'Client' AS NVARCHAR(50)) AS AccountRole,
            CAST(q.FullNumber AS NVARCHAR(100)) AS RecordSortValue
        FROM ResolvedProjects AS rp
        INNER JOIN SSop.Quotes AS q
            ON q.ProjectId = rp.ProjectId
           AND q.RowStatus NOT IN (0, 254)
        WHERE EXISTS
        (
            SELECT 1
            FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) AS oscr
        )
    ),
    JobRows AS
    (
        SELECT
            rp.ProjectId,
            rp.ProjectGuid,
            CAST(9 AS INT) AS EntityTypeId,
            CAST(N'Jobs' AS NVARCHAR(50)) AS NavigationGroup,
            CAST(40 AS INT) AS NavigationSortOrder,
            j.ID AS RecordId,
            j.Guid AS RecordGuid,
            CAST(j.Number AS NVARCHAR(50)) AS RecordNumber,
            CAST(CONCAT(N'Job ', j.Number) AS NVARCHAR(250)) AS RecordTitle,
            CAST(j.JobDescription AS NVARCHAR(1000)) AS RecordSubtitle,
            NULLIF(j.ClientAccountID, -1) AS RelatedAccountId,
            NULLIF(j.UprnID, -1) AS RelatedAssetId,
            CAST(N'Client' AS NVARCHAR(50)) AS AccountRole,
            CAST(j.Number AS NVARCHAR(100)) AS RecordSortValue
        FROM ResolvedProjects AS rp
        INNER JOIN SJob.Jobs AS j
            ON j.ProjectId = rp.ProjectId
           AND j.RowStatus NOT IN (0, 254)
        WHERE EXISTS
        (
            SELECT 1
            FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
        )
    ),
    ProjectAssetSource AS
    (
        /*
            Resolve only Asset IDs linked to the selected Project(s).
            Security is evaluated against the already project-scoped source
            record before the Asset itself is read.
        */
        SELECT
            rp.ProjectId,
            rp.ProjectGuid,
            e.PropertyId AS AssetId
        FROM ResolvedProjects AS rp
        INNER JOIN SSop.Enquiries AS e
            ON e.ProjectId = rp.ProjectId
           AND e.RowStatus NOT IN (0, 254)
           AND e.PropertyId > 0
        WHERE EXISTS
        (
            SELECT 1
            FROM SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) AS oscr
        )

        UNION

        SELECT
            rp.ProjectId,
            rp.ProjectGuid,
            q.UprnId
        FROM ResolvedProjects AS rp
        INNER JOIN SSop.Quotes AS q
            ON q.ProjectId = rp.ProjectId
           AND q.RowStatus NOT IN (0, 254)
           AND q.UprnId > 0
        WHERE EXISTS
        (
            SELECT 1
            FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) AS oscr
        )

        UNION

        SELECT
            rp.ProjectId,
            rp.ProjectGuid,
            j.UprnID
        FROM ResolvedProjects AS rp
        INNER JOIN SJob.Jobs AS j
            ON j.ProjectId = rp.ProjectId
           AND j.RowStatus NOT IN (0, 254)
           AND j.UprnID > 0
        WHERE EXISTS
        (
            SELECT 1
            FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
        )
    ),
    AssetRows AS
    (
        SELECT
            pas.ProjectId,
            pas.ProjectGuid,
            CAST(27 AS INT) AS EntityTypeId,
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
            CAST(
                RIGHT(REPLICATE(N'0', 10) + CAST(a.ID AS NVARCHAR(10)), 10)
                AS NVARCHAR(100)
            ) AS RecordSortValue
        FROM ProjectAssetSource AS pas
        INNER JOIN SJob.Assets AS a
            ON a.ID = pas.AssetId
           AND a.ID > 0
           AND a.RowStatus NOT IN (0, 254)
        WHERE EXISTS
        (
            SELECT 1
            FROM SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) AS oscr
        )
    ),
    AccountRoleSource AS
    (
        /*
            Each business table is now read once and is restricted to the
            resolved Project before role expansion and security evaluation.
        */
        SELECT
            rp.ProjectId,
            rp.ProjectGuid,
            roleValues.AccountId,
            roleValues.NavigationGroup,
            roleValues.NavigationSortOrder,
            roleValues.AccountRole
        FROM ResolvedProjects AS rp
        INNER JOIN SSop.Enquiries AS e
            ON e.ProjectId = rp.ProjectId
           AND e.RowStatus NOT IN (0, 254)
        CROSS APPLY
        (
            VALUES
                (
                    e.ClientAccountId,
                    CAST(N'Clients' AS NVARCHAR(50)),
                    CAST(60 AS INT),
                    CAST(N'Client' AS NVARCHAR(50))
                ),
                (
                    e.AgentAccountId,
                    CAST(N'Agents' AS NVARCHAR(50)),
                    CAST(70 AS INT),
                    CAST(N'Agent' AS NVARCHAR(50))
                ),
                (
                    e.FinanceAccountId,
                    CAST(N'Finance' AS NVARCHAR(50)),
                    CAST(80 AS INT),
                    CAST(N'Finance' AS NVARCHAR(50))
                )
        ) AS roleValues
        (
            AccountId,
            NavigationGroup,
            NavigationSortOrder,
            AccountRole
        )
        WHERE roleValues.AccountId > 0
          AND EXISTS
          (
              SELECT 1
              FROM SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) AS oscr
          )

        UNION ALL

        SELECT
            rp.ProjectId,
            rp.ProjectGuid,
            roleValues.AccountId,
            roleValues.NavigationGroup,
            roleValues.NavigationSortOrder,
            roleValues.AccountRole
        FROM ResolvedProjects AS rp
        INNER JOIN SSop.Quotes AS q
            ON q.ProjectId = rp.ProjectId
           AND q.RowStatus NOT IN (0, 254)
        CROSS APPLY
        (
            VALUES
                (
                    q.ClientAccountId,
                    CAST(N'Clients' AS NVARCHAR(50)),
                    CAST(60 AS INT),
                    CAST(N'Client' AS NVARCHAR(50))
                ),
                (
                    q.AgentAccountId,
                    CAST(N'Agents' AS NVARCHAR(50)),
                    CAST(70 AS INT),
                    CAST(N'Agent' AS NVARCHAR(50))
                )
        ) AS roleValues
        (
            AccountId,
            NavigationGroup,
            NavigationSortOrder,
            AccountRole
        )
        WHERE roleValues.AccountId > 0
          AND EXISTS
          (
              SELECT 1
              FROM SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) AS oscr
          )

        UNION ALL

        SELECT
            rp.ProjectId,
            rp.ProjectGuid,
            roleValues.AccountId,
            roleValues.NavigationGroup,
            roleValues.NavigationSortOrder,
            roleValues.AccountRole
        FROM ResolvedProjects AS rp
        INNER JOIN SJob.Jobs AS j
            ON j.ProjectId = rp.ProjectId
           AND j.RowStatus NOT IN (0, 254)
        CROSS APPLY
        (
            VALUES
                (
                    j.ClientAccountID,
                    CAST(N'Clients' AS NVARCHAR(50)),
                    CAST(60 AS INT),
                    CAST(N'Client' AS NVARCHAR(50))
                ),
                (
                    j.AgentAccountID,
                    CAST(N'Agents' AS NVARCHAR(50)),
                    CAST(70 AS INT),
                    CAST(N'Agent' AS NVARCHAR(50))
                ),
                (
                    j.FinanceAccountID,
                    CAST(N'Finance' AS NVARCHAR(50)),
                    CAST(80 AS INT),
                    CAST(N'Finance' AS NVARCHAR(50))
                )
        ) AS roleValues
        (
            AccountId,
            NavigationGroup,
            NavigationSortOrder,
            AccountRole
        )
        WHERE roleValues.AccountId > 0
          AND EXISTS
          (
              SELECT 1
              FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
          )
    ),
    AccountRows AS
    (
        SELECT DISTINCT
            rp.ProjectId,
            rp.ProjectGuid,
            CAST(15 AS INT) AS EntityTypeId,
            roles.NavigationGroup,
            roles.NavigationSortOrder,
            a.ID AS RecordId,
            a.Guid AS RecordGuid,
            CAST(a.Code AS NVARCHAR(50)) AS RecordNumber,
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
        FROM ResolvedProjects AS rp
        INNER JOIN AccountRoleSource AS roles
            ON roles.ProjectId = rp.ProjectId
           AND roles.ProjectGuid = rp.ProjectGuid
        INNER JOIN SCrm.Accounts AS a
            ON a.ID = roles.AccountId
           AND a.ID > 0
           AND a.RowStatus NOT IN (0, 254)
        WHERE EXISTS
        (
            SELECT 1
            FROM SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) AS oscr
        )
    ),
    AllRows AS
    (
        SELECT
            pr.ProjectId,
            pr.ProjectGuid,
            pr.EntityTypeId,
            pr.NavigationGroup,
            pr.NavigationSortOrder,
            pr.RecordId,
            pr.RecordGuid,
            pr.RecordNumber,
            pr.RecordTitle,
            pr.RecordSubtitle,
            pr.RelatedAccountId,
            pr.RelatedAssetId,
            pr.AccountRole,
            pr.RecordSortValue
        FROM ProjectRows AS pr

        UNION ALL

        SELECT
            er.ProjectId,
            er.ProjectGuid,
            er.EntityTypeId,
            er.NavigationGroup,
            er.NavigationSortOrder,
            er.RecordId,
            er.RecordGuid,
            er.RecordNumber,
            er.RecordTitle,
            er.RecordSubtitle,
            er.RelatedAccountId,
            er.RelatedAssetId,
            er.AccountRole,
            er.RecordSortValue
        FROM EnquiryRows AS er

        UNION ALL

        SELECT
            qr.ProjectId,
            qr.ProjectGuid,
            qr.EntityTypeId,
            qr.NavigationGroup,
            qr.NavigationSortOrder,
            qr.RecordId,
            qr.RecordGuid,
            qr.RecordNumber,
            qr.RecordTitle,
            qr.RecordSubtitle,
            qr.RelatedAccountId,
            qr.RelatedAssetId,
            qr.AccountRole,
            qr.RecordSortValue
        FROM QuoteRows AS qr

        UNION ALL

        SELECT
            jr.ProjectId,
            jr.ProjectGuid,
            jr.EntityTypeId,
            jr.NavigationGroup,
            jr.NavigationSortOrder,
            jr.RecordId,
            jr.RecordGuid,
            jr.RecordNumber,
            jr.RecordTitle,
            jr.RecordSubtitle,
            jr.RelatedAccountId,
            jr.RelatedAssetId,
            jr.AccountRole,
            jr.RecordSortValue
        FROM JobRows AS jr

        UNION ALL

        SELECT
            ar.ProjectId,
            ar.ProjectGuid,
            ar.EntityTypeId,
            ar.NavigationGroup,
            ar.NavigationSortOrder,
            ar.RecordId,
            ar.RecordGuid,
            ar.RecordNumber,
            ar.RecordTitle,
            ar.RecordSubtitle,
            ar.RelatedAccountId,
            ar.RelatedAssetId,
            ar.AccountRole,
            ar.RecordSortValue
        FROM AssetRows AS ar

        UNION ALL

        SELECT
            acr.ProjectId,
            acr.ProjectGuid,
            acr.EntityTypeId,
            acr.NavigationGroup,
            acr.NavigationSortOrder,
            acr.RecordId,
            acr.RecordGuid,
            acr.RecordNumber,
            acr.RecordTitle,
            acr.RecordSubtitle,
            acr.RelatedAccountId,
            acr.RelatedAssetId,
            acr.AccountRole,
            acr.RecordSortValue
        FROM AccountRows AS acr
    )
    SELECT
        ar.ProjectId,
        ar.ProjectGuid,
        p.Number AS ProjectNumber,
        CAST(94 AS INT) AS ProjectEntityTypeId,
        etProject.Name AS ProjectEntityTypeName,

        ar.EntityTypeId,
        et.Name AS EntityTypeName,
        et.Guid AS EntityTypeGuid,
        et.HasDocuments,

        ar.NavigationGroup,
        ar.NavigationSortOrder,

        CAST(
            CONCAT(
                ar.ProjectGuid,
                N'|',
                ar.EntityTypeId,
                N'|',
                ar.RecordGuid,
                N'|',
                ISNULL(ar.AccountRole, N'')
            )
            AS NVARCHAR(200)
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
        CAST(
            CASE
                WHEN et.HasDocuments = 1
                 AND ses.ID IS NOT NULL
                    THEN 1
                ELSE 0
            END
            AS BIT
        ) AS CanBrowseDocuments
    FROM AllRows AS ar
    INNER JOIN SSop.Projects AS p
        ON p.ID = ar.ProjectId
       AND p.RowStatus NOT IN (0, 254)
    INNER JOIN SCore.EntityTypes AS et
        ON et.ID = ar.EntityTypeId
       AND et.RowStatus NOT IN (0, 254)
    INNER JOIN SCore.EntityTypes AS etProject
        ON etProject.ID = 94
       AND etProject.RowStatus NOT IN (0, 254)
    LEFT JOIN SCore.SharepointEntityStructure AS ses
        ON ses.EntityTypeID = ar.EntityTypeId
       AND ses.RowStatus NOT IN (0, 254)
    LEFT JOIN SCore.SharepointSites AS sps
        ON sps.ID = ses.SharePointSiteID
       AND sps.RowStatus NOT IN (0, 254)
);
GO