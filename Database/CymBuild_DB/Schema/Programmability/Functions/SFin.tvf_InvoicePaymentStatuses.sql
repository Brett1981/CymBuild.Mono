SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SFin].[tvf_InvoicePaymentStatuses]
	(
		@UserId INT
	)
RETURNS TABLE
      --WITH SCHEMABINDING
AS
RETURN 


SELECT 
	root_hobt.ID,
	root_hobt.Guid,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	root_hobt.Name
FROM SFin.InvoicePaymentStatus AS root_hobt
WHERE	
		(root_hobt.Guid <> N'00000000-0000-0000-0000-000000000000')
	AND (root_hobt.RowStatus NOT IN (0,254))
	AND EXISTS (SELECT 1 FROM SCore.ObjectSecurityForUser_CanRead(root_hobt.Guid, @UserId) oscr)
	

GO