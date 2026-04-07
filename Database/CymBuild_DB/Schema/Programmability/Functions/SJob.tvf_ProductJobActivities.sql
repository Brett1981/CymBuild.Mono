SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_ProductJobActivities] 
(
    @UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS
RETURN 
SELECT  pja.ID,
        pja.RowStatus,
        pja.RowVersion,
        pja.Guid,
		a.Name AS ActivityType,
		pja.ActivityTitle,
		pja.OffsetMonths,
		pja.OffsetWeeks,
		pja.OffsetDays
FROM    SJob.ProductJobActivities pja
JOIN	SJob.JobTypeActivityTypes jtat ON (pja.JobTypeActivityTypeId = jtat.ID)
JOIN	SJob.ActivityTypes a ON (a.ID = jtat.ActivityTypeID)
join	SProd.Products p ON (p.ID = pja.ProductId)
WHERE   (pja.RowStatus  NOT IN (0, 254))
	AND	(pja.Id > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(pja.Guid, @UserId) oscr
			)
		)
	AND	(p.Guid = @ParentGuid)
GO