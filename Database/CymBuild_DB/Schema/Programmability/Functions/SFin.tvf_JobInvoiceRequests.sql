SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SFin].[tvf_JobInvoiceRequests] 
(
	@JobGuid UNIQUEIDENTIFIER,
    @UserId INT
)
RETURNS TABLE
         --WITH SCHEMABINDING
AS
RETURN 
SELECT  ir.ID,
        ir.RowStatus,
        ir.RowVersion,
        ir.Guid,
        ir.Notes,
		ir.CreatedDateTimeUTC,
		i.Guid RequesterUserId,
		j.Guid JobId,
		-- New: Get the status of an invoice request.
		(
			SELECT 
				CASE 
					WHEN EXISTS 
					(
						SELECT
						1
							FROM
									SFin.TransactionDetails td
							INNER JOIN
									SFin.InvoiceRequestItems iri on (iri.Id = td.InvoiceRequestItemId)
							WHERE	
									(iri.InvoiceRequestId = ir.ID) 
					) THEN N'Yes' ELSE N'No'
				END) AS IsProcessed
FROM    SFin.InvoiceRequests ir
JOIN	SJob.Jobs j ON (j.ID = ir.JobId)
JOIN	SCore.Identities i ON (i.ID = ir.RequesterUserId)
WHERE   (ir.RowStatus  NOT IN (0, 254))
	AND	(ir.Id > 0)
	AND	(j.Guid = @JobGuid)
	AND (ir.IsMerged = 0)
	AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
			)
		)
	AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(ir.Guid, @UserId) oscr
			)
		)
GO