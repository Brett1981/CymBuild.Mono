SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SFin].[tvf_JobInvoiceProcessingModeHistory] 
(
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
                  --WITH SCHEMABINDING
AS
RETURN
SELECT	
		root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Reason,
		id.FullName AS Requester,
		root_hobt.ChangedDateTimeUTC,
		CASE 
			WHEN root_hobt.OldMode = 0 THEN N'Automated'
			WHEN root_hobt.OldMode = 1 THEN N'Manual'
			ELSE N'Paused' 
		END AS OldMode,
		CASE 
			WHEN root_hobt.NewMode = 0 THEN N'Automated'
			WHEN root_hobt.NewMode = 1 THEN N'Manual'
			ELSE N'Paused' 
		END AS NewMode
FROM SFin.InvoiceProcessingModeHistory root_hobt
JOIN SCore.Identities id ON (id.ID = root_hobt.ChangedByUserId)
WHERE root_hobt.JobGuid = @ParentGuid
GO