SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCrm].[tvf_AccountMemos]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS RETURN
SELECT
		am.ID,
		am.RowStatus,
		am.RowVersion,
		am.Guid,
		am.Memo,
		a.Guid AS AccountId
FROM
		SCrm.AccountMemos am
JOIN
		SCrm.Accounts a ON (a.ID = am.AccountID)
WHERE
		(am.RowStatus NOT IN (0, 254))
		AND (am.ID > 0)
		AND (EXISTS
		(
			SELECT
					1
			FROM
					SCore.ObjectSecurityForUser_CanRead(am.Guid, @UserId) oscr
		)
		)
		AND (a.Guid = @ParentGuid)
GO