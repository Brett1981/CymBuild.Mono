SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_HoBTsForEntityType]
	(
		@Guid UNIQUEIDENTIFIER,
		@UserId INT
	)
RETURNS TABLE
              --WITH SCHEMABINDING
AS
RETURN SELECT		hobt.ID,
					hobt.RowStatus,
					hobt.RowVersion,
					hobt.Guid,
					hobt.EntityTypeID,
					e.Guid EntityTypeGuid,
					hobt.IsMainHoBT,
					hobt.IsReadOnlyOffline,
					hobt.SchemaName,
					hobt.ObjectName,
					hobt.ObjectType,
					os.CanRead,
					os.CanWrite
	   FROM			[SCore].[EntityHobtsV] hobt
	   JOIN			SCore.EntityTypesV e ON(hobt.EntityTypeID = e.ID)
	   OUTER APPLY	SCore.ObjectSecurityForUser(hobt.Guid, @UserId) os
	   WHERE		(e.Guid = @Guid)
				AND (e.RowStatus = 1)
				AND (hobt.RowStatus = 1);
GO