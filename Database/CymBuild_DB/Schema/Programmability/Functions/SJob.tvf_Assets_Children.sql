SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Assets_Children]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS RETURN	
	SELECT 
		a2.ID,
		a2.RowStatus,
		a2.Guid,
		la.Name AS LocalAuthority,
		a2.FormattedAddressComma,
		a2.Name,
		oa.Name AS OwnerAccount,
		a2.AssetNumber AS UPRN
	FROM 
		SJob.Assets a2
	JOIN
		SCrm.Accounts AS la ON (la.ID = a2.LocalAuthorityAccountID)
	JOIN 
		SCrm.Accounts AS oa ON (oa.ID = a2.OwnerAccountID)
	WHERE 
		(EXISTS
			(
				SELECT 1
				FROM  SJob.Assets AS a1
				WHERE 
					a2.ParentAssetID = a1.ID AND
					a1.Guid = @ParentGuid
				
			)
		)
	
		AND	(EXISTS
			(					
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(@ParentGuid, @UserId) oscr
			)
		)
GO