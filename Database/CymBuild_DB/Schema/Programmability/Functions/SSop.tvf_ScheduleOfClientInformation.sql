SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO






CREATE FUNCTION [SSop].[tvf_ScheduleOfClientInformation]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS RETURN	
SELECT  soci.ID,
        soci.RowStatus,
        soci.RowVersion,
        soci.Guid,
		soci.Item
FROM    SSop.ScheduleOfClientInformation AS soci

WHERE   (soci.RowStatus NOT IN (0, 254))
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(soci.Guid, @UserId) oscr
			)
		)
	AND	(EXISTS 
			(
				SELECT	1
				FROM	SSop.Enquiries AS e
				WHERE	(e.Guid = @ParentGuid)
					AND	(e.ID = soci.EnquiryId)
			)
		)
GO