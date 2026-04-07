SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_AssetQuotes] 
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
		i.FullName AS QuotingUserName,
		qc.FullName AS QuotingConsultant
FROM    SSop.Quotes q
JOIN	SSop.EnquiryServices es on (es.Id = q.EnquiryServiceID)
join	SSop.Enquiries e on (e.Id = es.EnquiryId)
JOIN	SJob.Assets p ON (p.ID = e.PropertyId)
JOIN    SCore.Identities i ON (q.QuotingUserId = i.ID)
JOIN	SCore.Identities qc ON (qc.ID = q.QuotingConsultantId)
WHERE   (q.RowStatus  NOT IN (0, 254))
	AND	(q.Id > 0)
	AND	(p.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
			)
		)
	AND	(p.Guid = @ParentGuid)
GO