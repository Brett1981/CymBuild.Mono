SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE VIEW	[SSop].[Contracts_DDL]
AS
SELECT	root_hobt.Guid, 
		root_hobt.RowStatus,
		LEFT(root_hobt.Details, 200) AS Name,
		a.Guid AS AccountGuid
FROM	SSop.Contracts root_hobt
JOIN	SCrm.Accounts AS a ON (a.ID = root_hobt.AccountID)
GO