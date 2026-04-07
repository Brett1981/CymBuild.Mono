SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION  [SJob].[tvf_AssetClients]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
          --WITH SCHEMABINDING
AS RETURN	

--FINANCE ACCOUNT
SELECT  
		acc.ID,
		acc.Guid,
		acc.RowStatus,
		acc.RowVersion,
		j.Number,
		acc.Name,
		N'Finance' AS AccountType
FROM	SCrm.Accounts as acc
JOIN	SJob.Jobs AS j ON (j.FinanceAccountID = acc.ID)
JOIN	SJob.Assets AS a ON (j.UprnID = a.ID)
WHERE   (j.RowStatus NOT IN (0, 254))
	AND (acc.RowStatus NOT IN (0,254))
	AND (acc.ID <> -1)
	AND (a.Guid = @ParentGuid)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (j.guid, @UserId) oscr
			)
		)
UNION

--CLIENT ACCOUNT
SELECT  
		acc.ID,
		acc.Guid,
		acc.RowStatus,
		acc.RowVersion,
		j.Number,
		acc.Name,
		N'Client' AS AccountType
FROM	SCrm.Accounts as acc
JOIN	SJob.Jobs AS j ON (j.ClientAccountID = acc.ID)
JOIN    SJob.Assets AS a ON (a.ID = j.UprnID)
WHERE   (j.RowStatus NOT IN (0, 254))
	AND	(a.Guid = @ParentGuid)
	AND (acc.RowStatus NOT IN (0,254))
	AND (acc.ID <> -1)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (j.guid, @UserId) oscr
			)
		)

UNION

--AGENT ACCOUNT
SELECT  
		acc.ID,
		acc.Guid,
		acc.RowStatus,
		acc.RowVersion,
		j.Number,
		acc.Name,
		N'Agent' AS AccountType
FROM	SCrm.Accounts as acc
JOIN	SJob.Jobs AS j ON (j.AgentAccountID = acc.ID)
JOIN    SJob.Assets AS a ON (a.ID = j.UprnID)
WHERE   (j.RowStatus NOT IN (0, 254))
	AND	(a.Guid = @ParentGuid)
	AND (acc.RowStatus NOT IN (0,254))
	AND (acc.ID <> -1)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (j.guid, @UserId) oscr
			)
		)

GO