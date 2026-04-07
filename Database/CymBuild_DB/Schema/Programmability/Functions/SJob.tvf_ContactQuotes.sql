SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_ContactQuotes] 
(
    @UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS
RETURN 
SELECT  q.ID,
        q.RowStatus,
        q.RowVersion,
        q.Guid,
        q.Number,
		q.Date,
		LEFT(q.Overview, 200) AS Overview,
		i.Guid QuotingUserGuid,
		i.FullName AS QuotingUserName
FROM    SSop.Quotes q
JOIN	SCrm.Contacts c ON (c.ID = q.ClientContactId)
JOIN    SCore.Identities i ON (q.QuotingUserId = i.ID)
WHERE   (q.RowStatus  NOT IN (0, 254))
	AND	(q.Id > 0)
	AND	(c.Guid = @ParentGuid)
	AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
			)
		)
GO