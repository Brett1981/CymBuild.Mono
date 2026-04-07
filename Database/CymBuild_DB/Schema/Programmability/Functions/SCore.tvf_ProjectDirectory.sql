SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_ProjectDirectory] 
(
    @UserId INT,
    @ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
               --WITH SCHEMABINDING
AS
RETURN 
SELECT  pd.ID,
        pd.RowStatus, 
        pd.RowVersion,
        pd.Guid,
		pdr.Name AS Role,
		c.DisplayName AS Contact
FROM    SJob.ProjectDirectory pd
JOIN	SJob.Jobs j ON (j.ID = pd.JobID)
JOIN	SCrm.Accounts a ON (a.ID = pd.AccountID)
JOIN	SJob.ProjectDirectoryRoles pdr ON (pdr.ID = pd.ProjectDirectoryRoleID)
JOIN	SCrm.Contacts c ON (c.ID = pd.ContactID)
WHERE   (pd.RowStatus  NOT IN (0, 254))
    AND (j.Guid = @ParentGuid)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(pd.Guid, @UserId) oscr
			)
		)
GO