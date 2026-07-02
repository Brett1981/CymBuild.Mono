SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SJob].[tvf_Jobs]')
GO
CREATE FUNCTION [SJob].[tvf_Jobs] 
(
    @UserId INT
)
RETURNS TABLE
            --WITH SCHEMABINDING
AS
RETURN 
SELECT  j.ID,
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
		client.Name + N' / ' + agent.Name AS  ClientAgent,
		js.IsSubjectToNDA,
		j.IsComplete,
		js.JobStatus,
		org.Name AS OrgUnit,
		j.CreatedOn AS Date,
		j.ExternalReference,
        COALESCE(NULLIF(LTRIM(RTRIM(businessUnit.Name)), N''), N'') AS BusinessUnit,
        COALESCE(NULLIF(LTRIM(RTRIM(department.Name)), N''), N'') AS Department
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
WHERE   (j.RowStatus  NOT IN (0, 254))
	AND	(j.Id > 0)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (j.guid, @UserId) oscr
			)
		)
GO