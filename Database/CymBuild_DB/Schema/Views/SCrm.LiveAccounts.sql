SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SCrm].[LiveAccounts]
           --WITH SCHEMABINDING 
AS 
SELECT	root_hobt.Guid,
		root_hobt.RowStatus,
		root_hobt.Name
FROM	SCrm.Accounts root_hobt
JOIN	SCrm.AccountStatus stat ON (stat.ID = root_hobt.AccountStatusID)
WHERE	(stat.IsLive = 1)
GO