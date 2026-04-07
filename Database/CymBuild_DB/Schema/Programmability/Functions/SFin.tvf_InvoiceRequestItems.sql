SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SFin].[tvf_InvoiceRequestItems] 
(
    @UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN 
SELECT  iri.ID,
        iri.RowStatus,
        iri.RowVersion,
        iri.Guid,
		iri.Net,
        ir.Guid AS InvoiceRequestId,
		m.Guid AS MilestoneId,
		a.Guid AS ActivityId
FROM    SFin.InvoiceRequestItems iri 
JOIN	SFin.InvoiceRequests ir ON (ir.Id = iri.InvoiceRequestId)
JOIN	SJob.Milestones m ON (m.ID = iri.MilestoneId)
JOIN	SJob.Activities a ON (a.ID = iri.ActivityId)
WHERE   (iri.RowStatus  NOT IN (0, 254))
	AND	(iri.Id > 0)
	AND	(ir.Guid = @ParentGuid)
	AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(ir.Guid, @UserId) oscr
			)
		)
GO