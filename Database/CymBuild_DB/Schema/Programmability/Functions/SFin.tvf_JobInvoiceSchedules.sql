SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SFin].[tvf_JobInvoiceSchedules]
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
  JOIN		SFin.InvoiceScheduleTrigger AS ist ON (ist.ID = invs.TriggerId)
  JOIN      SJob.Job_ExtendedInfo as jex ON (jex.Guid = @ParentGuid)
  JOIN      SSop.Quotes AS q ON (q.Guid = jex.QuoteGuid)
  JOIN		SSop.QuoteItems as qi ON (qi.QuoteId = q.ID)
  WHERE
				
		  		(invs.RowStatus NOT IN (0, 254))
			AND (invs.QuoteId = q.ID)
			AND (qi.InvoicingSchedule = invs.ID)
			AND (qi.CreatedJobId = jex.Id)
			AND	(EXISTS
					(
						SELECT
								1
						FROM
								SCore.ObjectSecurityForUser_CanRead(invs.Guid, 1479) oscr
					)
				)
GO