SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SFin].[tvf_InvoiceScheduleMonthConfiguration] 
(
    @UserId INT,
    @ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
               --WITH SCHEMABINDING
AS
RETURN 

SELECT 
		root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.Guid,
		root_hobt.PeriodNumber,
		root_hobt.Amount,
		root_hobt.OnDayOfMonth,
		root_hobt.Description
FROM   [SFin].[InvoiceScheduleMonthConfiguration] AS root_hobt
JOIN   [SFin].[InvoiceSchedules] AS invsch ON (root_hobt.InvoiceScheduleId = invsch.ID)
WHERE   
			(root_hobt.RowStatus  NOT IN (0, 254))
		AND (invsch.Guid = @ParentGuid)
		AND	(EXISTS
				(
					SELECT	1
					FROM	SCore.ObjectSecurityForUser_CanRead (root_hobt.guid, @UserId) oscr
				)
			)
GO