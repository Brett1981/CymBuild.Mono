SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCrm].[tvf_Addresses]
(
	@UserId INT
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS RETURN	
SELECT  a.ID,
        a.RowStatus,
        a.RowVersion,
        a.Guid,
        a.AddressNumber,
        a.FormattedAddressComma,
		a.Name
FROM    SCrm.Addresses a
WHERE   (a.RowStatus NOT IN (0, 254))
	AND	(a.ID > 0)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (a.guid, @UserId) oscr
			)
		)
GO