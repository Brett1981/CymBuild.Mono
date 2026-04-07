SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_EnquiryKeyDates]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS RETURN	
SELECT  pkd.ID,
        pkd.RowStatus,
        pkd.RowVersion,
        pkd.Guid,
		pkd.Detail AS Details,
        pkd.DateTime
FROM    SSop.ProjectKeyDates pkd 
JOIN	SSop.Enquiries e ON (e.ProjectId = pkd.ProjectID)
WHERE   (pkd.RowStatus NOT IN (0, 254))
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(pkd.Guid, @UserId) oscr
			)
		)
	AND	(e.Guid = @ParentGuid)
GO