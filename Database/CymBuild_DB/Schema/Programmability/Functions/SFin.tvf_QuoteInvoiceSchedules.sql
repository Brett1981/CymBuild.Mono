SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SFin].[tvf_QuoteInvoiceSchedules]
  (
    @UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
  )
RETURNS TABLE
      --WITH SCHEMABINDING
AS
  RETURN
  SELECT
        invs.ID,
		invs.RowStatus,
		invs.RowVersion,
		invs.Guid,
		invs.Name,
		invs.DescriptionOfWork,
		invs.Amount,
		ist.Name AS TriggerId, --has to be guid
		invs.ExpectedDate
  FROM
			SFin.InvoiceSchedules AS invs
  JOIN		SSop.Quotes AS q ON (q.ID = invs.QuoteId)
  JOIN		SFin.InvoiceScheduleTrigger AS ist ON (ist.ID = invs.TriggerId)
  WHERE
				(q.Guid = @ParentGuid)
		  AND	(invs.RowStatus NOT IN (0, 254))
		  AND	(EXISTS
					(
						SELECT
								1
						FROM
								SCore.ObjectSecurityForUser_CanRead(invs.Guid, @UserId) oscr
					)
				)
GO