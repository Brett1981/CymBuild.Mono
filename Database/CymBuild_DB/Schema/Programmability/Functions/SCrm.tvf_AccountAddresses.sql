SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCrm].[tvf_AccountAddresses]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
               --WITH SCHEMABINDING
AS RETURN	
SELECT  aa.ID,
        aa.RowStatus,
        aa.RowVersion,
        aa.Guid,
		a.FormattedAddressComma
FROM    SCrm.AccountAddresses aa
JOIN    SCrm.Addresses a ON (a.ID = aa.AddressID)
JOIN	SCrm.Accounts acc ON (acc.ID = aa.AccountID)
WHERE   (a.RowStatus NOT IN (0, 254))
	AND	(a.ID > 0)
	AND	(acc.Guid = @ParentGuid)
	AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(aa.Guid, @UserId) oscr
			)
		)
GO