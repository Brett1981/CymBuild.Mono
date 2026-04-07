SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_EntityTypeList]
	(
		@UserId INT
	)
RETURNS TABLE
            --WITH SCHEMABINDING
AS
RETURN	
SELECT	et.ID, 
		et.RowStatus,
		et.RowVersion,
		et.Guid, 
		et.Name,
		et.IsMetaData,
		et.HasDocuments
FROM	SCore.EntityTypes et
 WHERE		(et.ID > 0)
				AND (et.RowStatus NOT IN (0, 254))
				AND	(EXISTS
			(
					SELECT
							1
					FROM
							SCore.ObjectSecurityForUser_CanRead(et.Guid, @UserId) oscr
			)
		)

GO