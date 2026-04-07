SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO




CREATE FUNCTION [SSop].[tvf_ProjectKeyDates]
	(
		@UserId INT,
		@ParentGuid UNIQUEIDENTIFIER
	)
RETURNS TABLE
              --WITH SCHEMABINDING
AS
RETURN SELECT		pkd.ID,
					pkd.RowStatus,
					pkd.RowVersion,
					pkd.Guid,
					pkd.DateTime,
					pkd.Detail
	   FROM			SSop.ProjectKeyDates AS pkd
	   JOIN			SSop.Projects AS p				 ON (p.ID = pkd.ProjectID)
	   WHERE		(pkd.RowStatus NOT IN (0, 254))
				AND (p.Guid		= @ParentGuid)
				AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (pkd.guid, @UserId) oscr
			)
		)
GO