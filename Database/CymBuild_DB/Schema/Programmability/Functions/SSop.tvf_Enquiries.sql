SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_Enquiries]
(
    @UserId INT
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN
(
    SELECT
          e.ID
        , e.RowStatus
        , e.RowVersion
        , e.Guid
        , CASE
              WHEN e.Revision = 0
                  THEN e.Number
              ELSE e.Number + N' (' + CONVERT(NVARCHAR(2), e.Revision) + N') '
          END AS Number
        , e.ExternalReference
        , LEFT(e.DescriptionOfWorks, 200) AS DescriptionOfWorks
        , CASE
              WHEN client.Name <> N'' THEN client.Name ELSE e.ClientName
          END
          + N' / ' +
          CASE
              WHEN agent.Name <> N'' THEN agent.Name ELSE e.AgentName
          END AS ClientAgentAccount
        , CASE
              WHEN uprn.AssetNumber > 0
                  THEN uprn.FormattedAddressComma
              ELSE e.PropertyNameNumber + N' ' + e.PropertyAddressLine1
          END AS Property
        , uprn.AssetNumber AS UPRN
        , ecf.EnquiryStatus
        , ISNULL(p.IsSubjectToNDA, e.IsSubjectToNDA) AS IsSubjectToNDA
        , CASE
              WHEN jtSingle.Name IS NULL
                  THEN N'Multi Discipline'
              ELSE jtSingle.Name
          END AS Disciplines
        , org.Name AS OrgUnit
        , e.[Date]
    FROM SSop.Enquiries AS e

    -- status from the optimised view
    LEFT JOIN SSop.Enquiry_CalculatedFields AS ecf
        ON ecf.ID = e.ID

    JOIN SCrm.Accounts AS client
        ON client.ID = e.ClientAccountID

    JOIN SCrm.Accounts AS agent
        ON agent.ID = e.AgentAccountId

    JOIN SJob.Assets AS uprn
        ON uprn.ID = e.PropertyId

    JOIN SSop.Projects AS p
        ON p.ID = e.ProjectId

    JOIN SCore.OrganisationalUnits AS org
        ON org.ID = e.OrganisationalUnitID
    -- Removed Distinct as it caused issues with Filtering the grids
    LEFT JOIN
        (
            SELECT
                  es.EnquiryId
                , SingleJobTypeId =
                    CASE
                        WHEN MIN(es.JobTypeId) = MAX(es.JobTypeId)
                            THEN MIN(es.JobTypeId)
                        ELSE NULL
                    END
            FROM SSop.EnquiryServices AS es
            JOIN SJob.JobTypes AS jt
                ON jt.ID = es.JobTypeId
               AND jt.RowStatus NOT IN (0, 254)
            WHERE
                es.RowStatus NOT IN (0, 254)
            GROUP BY
                es.EnquiryId
        ) AS st
            ON st.EnquiryId = e.ID

        LEFT JOIN SJob.JobTypes AS jtSingle
            ON jtSingle.ID = st.SingleJobTypeId
           AND jtSingle.RowStatus NOT IN (0, 254)

    WHERE
            e.RowStatus NOT IN (0, 254)
        AND e.ID > 0
        AND EXISTS
        (
            SELECT 1
            FROM SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) AS oscr
        )
);
GO