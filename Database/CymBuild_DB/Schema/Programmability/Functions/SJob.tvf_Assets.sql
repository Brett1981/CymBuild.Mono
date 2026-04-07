SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE FUNCTION [SJob].[tvf_Assets]
	(
		@UserId INT
	)
RETURNS TABLE
       --WITH SCHEMABINDING
AS
RETURN SELECT		prop.ID,
					prop.RowStatus,
					prop.Guid,
					prop.AssetNumber AS UPRN,
					prop.FormattedAddressComma,
					prop.Name,
					la.Name AS LocalAuthority,
					oa.Name AS OwnerAccount
	   FROM			SJob.Assets				  AS prop
	   JOIN			SCrm.Accounts AS la ON (la.ID = prop.LocalAuthorityAccountID)
	   JOIN			SCrm.Accounts AS oa ON (oa.ID = prop.OwnerAccountID)
	   WHERE		(prop.ID > 0)
				AND (prop.RowStatus NOT IN (0, 254))
				AND	(EXISTS
			(
					SELECT
							1
					FROM
							SCore.ObjectSecurityForUser_CanRead(prop.Guid, @UserId) oscr
			)
		)
GO