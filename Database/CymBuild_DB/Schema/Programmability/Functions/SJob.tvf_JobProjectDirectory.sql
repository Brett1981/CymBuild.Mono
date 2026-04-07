SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_JobProjectDirectory]
	(
		@UserId INT,
		@ParentGuid UNIQUEIDENTIFIER
	)
RETURNS TABLE
              --WITH SCHEMABINDING
AS
RETURN SELECT		pd.ID,
					pd.RowStatus,
					pd.RowVersion,
					pd.Guid,
					pdr.Name	  AS Role,
					a.Name		  AS Account,
					c.DisplayName AS Contact
	   FROM			SJob.ProjectDirectory		  AS pd
	   JOIN			SJob.ProjectDirectoryRoles	  AS pdr ON (pdr.ID = pd.ProjectDirectoryRoleID)
	   JOIN			SCrm.Accounts				  AS a ON (a.ID = pd.AccountID)
	   JOIN			SCrm.Contacts				  AS c ON (c.ID = pd.ContactID)
	   JOIN			SJob.Jobs					  AS j ON (j.ProjectId = pd.ProjectID)
	   WHERE		(pd.RowStatus NOT IN (0, 254))
				AND (j.Guid		= @ParentGuid)
				AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (pd.guid, @UserId) oscr
			)
		)
GO