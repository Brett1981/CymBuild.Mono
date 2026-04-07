SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_JobTypeProjectDirectoryRoles] 
(
    @UserId INT,
    @ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS
RETURN 
SELECT  jtpr.ID,
        jtpr.RowStatus, 
        jtpr.RowVersion,
        jtpr.Guid,
		pdr.Name,
		jtpr.SortOrder
FROM    SJob.JobTypeProjectDirectoryRoles jtpr
JOIN	SJob.ProjectDirectoryRoles pdr ON (pdr.ID = jtpr.ProjectDirectoryRoleID)
JOIN	SJob.JobTypes jt ON (jt.ID = jtpr.JobTypeID)
WHERE   (jtpr.RowStatus  NOT IN (0, 254))
    AND (jt.Guid = @ParentGuid)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(jtpr.Guid, @UserId) oscr
			)
		)
GO