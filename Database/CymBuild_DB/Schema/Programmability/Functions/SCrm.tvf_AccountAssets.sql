SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCrm].[tvf_AccountAssets]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
          --WITH SCHEMABINDING
AS RETURN
SELECT
		a.ID,
		a.RowStatus,
		a.RowVersion,
		a.Guid,
		a.AssetNumber AS Number,
		a.FormattedAddressComma,
		j.Number AS JobNumber
FROM
		SJob.Assets AS a
JOIN
		SJob.Jobs AS j ON (j.UprnID = a.ID)
JOIN   
		SCrm.Accounts AS ac ON (ac.ID = a.OwnerAccountId)
WHERE
		(a.RowStatus NOT IN (0, 254))
		AND (j.RowStatus NOT IN (0,254))
		AND (
					(a.Guid = @ParentGuid)
				OR  (a.OwnerAccountId = ac.ID)
			)

		AND (EXISTS
		(
			SELECT
					1
			FROM
					SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
		)
		)
GO