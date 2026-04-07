SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Assets_PossibleDuplicates]
	(
		@UserId INT
	)
RETURNS TABLE
--WITH SCHEMABINDING
AS
RETURN SELECT	apd.ID,
		apd.RowStatus,
		apd.RowVersion,
		apd.Guid,
		a.AssetNumber,
		a.FormattedAddressComma,
		a.Latitude,
		a.Longitude,
		a2.Guid AS DupGuid,
		a2.AssetNumber AS DupAssetNumber,
		a2.FormattedAddressComma AS DupFormattedAddressComma,
		a2.Latitude AS DupLatitude,
		a2.Longitude AS DupLongitude
FROM	SJob.AssetPossibleDuplicates AS apd	
JOIN	SJob.Assets AS a ON (a.Id = apd.SourceAssetID)
JOIN	SJob.Assets AS a2 ON (a2.ID = apd.TargetAssetID)
WHERE	(EXISTS
				(
						SELECT
								1
						FROM
								SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) oscr
				)
			)
	AND	(EXISTS
				(
						SELECT
								1
						FROM
								SCore.ObjectSecurityForUser_CanRead(a2.Guid, @UserId) oscr
				)
			)
	AND	(apd.IsDifferent = 0)
	AND	(apd.IsDuplicate = 0)
	
GO