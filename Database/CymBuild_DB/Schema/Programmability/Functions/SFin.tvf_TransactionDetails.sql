SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SFin].[tvf_TransactionDetails] 
(
    @UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS
RETURN 
SELECT  td.ID,
		td.RowStatus,
		td.RowVersion,
		td.Guid,
		m.Guid AS MilestoneID,
		a.Guid AS ActivityID,
		td.Net,
		td.Description
FROM    SFin.TransactionDetails td 
JOIN	SFin.Transactions t ON (t.ID = td.TransactionID)
JOIN	SJob.Milestones m ON (m.Id = td.MilestoneID)
JOIN	SJob.Activities a ON (a.ID = td.ActivityID)
WHERE   (td.RowStatus  NOT IN (0, 254))
	AND	(td.Id > 0)
	AND	(t.Guid = @ParentGuid)
	AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(td.Guid, @UserId) oscr
			)
		)
GO