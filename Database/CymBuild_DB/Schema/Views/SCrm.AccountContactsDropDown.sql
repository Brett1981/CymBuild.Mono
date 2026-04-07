SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW	[SCrm].[AccountContactsDropDown]
           --WITH SCHEMABINDING 
AS 
SELECT	ac.Guid,
		ac.RowStatus,
		c.DisplayName,
		a.Guid AS AccountGuid,
		c.Guid AS ContactGuid
FROM	SCrm.Contacts c 
JOIN	SCrm.AccountContacts ac  ON (c.ID = ac.ContactID)
JOIN	SCrm.Accounts a ON (a.ID = ac.AccountID)
WHERE	(c.RowStatus NOT IN (0, 254))
	AND	(a.RowStatus NOT IN (0, 254))
	AND	(ac.RowStatus NOT IN (0, 254))
GO