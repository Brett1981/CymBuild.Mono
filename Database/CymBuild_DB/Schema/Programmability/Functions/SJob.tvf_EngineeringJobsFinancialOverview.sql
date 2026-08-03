SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SJob].[tvf_EngineeringJobsFinancialOverview]')
GO

CREATE FUNCTION [SJob].[tvf_EngineeringJobsFinancialOverview] 
(
    @UserId INT
)
RETURNS TABLE
            --WITH SCHEMABINDING
AS
RETURN 
SELECT   j.ID,
        j.RowStatus,
        j.RowVersion,
        j.Guid,
        j.Number,
        j.JobDescription,
        j.JobTypeID,
        jt.Name AS JobTypeName,
		i.Guid SurveyorGuid,
		i.FullName AS SurveyorName, 
		prop.FormattedAddressComma,
		COALESCE(NULLIF(client.Name, N''), N'Client Not specified') + N' / ' +COALESCE(NULLIF(agent.Name, N''), N'Agent Not specified') AS ClientAgent,
		js.IsSubjectToNDA,
		j.IsComplete,
		js.JobStatus,
		org.Name AS OrgUnit,
		j.CreatedOn AS Date,
		j.ExternalReference,
        COALESCE(NULLIF(LTRIM(RTRIM(businessUnit.Name)), N''), N'') AS BusinessUnit,
        COALESCE(NULLIF(LTRIM(RTRIM(department.Name)), N''), N'') AS Department,
		FinanceInfo.Agreed,
		FinanceInfo.Remaining,
		FinanceInfo.Invoiced,
		Products.Products
FROM    SJob.Jobs j
JOIN	SJob.JobStatus js ON (js.ID = j.ID)
JOIN    SJob.JobTypes jt ON (j.JobTypeID = jt.ID)
JOIN    SCore.Identities i ON (j.SurveyorID = i.ID)
JOIN	SJob.Assets prop ON (prop.ID = j.UprnID)
JOIN	SCrm.Accounts client ON (client.ID = j.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = j.AgentAccountID)
JOIN    SCore.OrganisationalUnits as org ON (org.ID = j.OrganisationalUnitID)
OUTER APPLY
(
    SELECT TOP (1)
        ancestor.Name
    FROM SCore.OrganisationalUnits AS ancestor
    WHERE ancestor.RowStatus NOT IN (0,254)
      AND ISNULL(ancestor.IsBusinessUnit, 0) = 1
      AND org.OrgNode IS NOT NULL
      AND ancestor.OrgNode IS NOT NULL
      AND org.OrgNode.IsDescendantOf(ancestor.OrgNode) = 1
    ORDER BY ancestor.OrgNode.GetLevel() DESC,
             ancestor.ID DESC
) AS businessUnit
OUTER APPLY
(
    SELECT TOP (1)
        ancestor.Name
    FROM SCore.OrganisationalUnits AS ancestor
    WHERE ancestor.RowStatus NOT IN (0,254)
      AND ISNULL(ancestor.IsDepartment, 0) = 1
      AND org.OrgNode IS NOT NULL
      AND ancestor.OrgNode IS NOT NULL
      AND org.OrgNode.IsDescendantOf(ancestor.OrgNode) = 1
    ORDER BY ancestor.OrgNode.GetLevel() DESC,
             ancestor.ID DESC
) AS department
OUTER APPLY
(
	SELECT 
		fin.Agreed,
		fin.Remaining,
		fin.Invoiced
	FROM SJob.Job_FeeDrawdown fin
	WHERE 
			(fin.Guid = j.Guid)
		AND (fin.Stage LIKE N'%Total (inc. Fee Cap)%')

) AS FinanceInfo
OUTER APPLY
(
    SELECT STRING_AGG(d.Code, ',') AS Products
    FROM
    (
        SELECT DISTINCT p.Code
        FROM SSop.QuoteItems qi
        JOIN SJob.Jobs jobs
            ON jobs.ID = qi.CreatedJobId
        LEFT JOIN SProd.Products p
            ON p.ID = qi.ProductId
        WHERE qi.RowStatus NOT IN (0,254)
          AND jobs.Guid = j.Guid
    ) AS d
) AS Products
WHERE   (j.RowStatus  NOT IN (0, 254))
	AND	(j.Id > 0)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (j.guid, @UserId) oscr
			)
		)
GO