SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_QueriesForEntityType]
	(
		@Guid UNIQUEIDENTIFIER,
		@UserId INT
	)
RETURNS TABLE
             --WITH SCHEMABINDING
AS
RETURN SELECT		eq.ID,
					eq.RowStatus,
					eq.RowVersion,
					eq.Guid,
					eq.Name,
					eq.Statement,
					e.Guid	AS EntityTypeGuid,
					eq.IsDefaultCreate,
					eq.IsDefaultRead,
					eq.IsDefaultUpdate,
					eq.IsDefaultDelete,
					eq.IsScalarExecute,
					eq.IsDefaultValidation,
					eq.IsDefaultDataPills,
					eq.IsProgressData,
					eh.Guid AS EntityHoBTGuid
	   FROM			SCore.EntityQueriesV		  AS eq
	   JOIN			SCore.EntityTypesV			  AS e ON (eq.EntityTypeID = e.ID)
	   JOIN			SCore.EntityHobtsV			  AS eh ON (eh.ID = eq.EntityHoBTID)
	   OUTER APPLY	SCore.ObjectSecurityForUser (	eq.Guid,
													@UserId
												) AS os
	   WHERE		(e.Guid = @Guid);
GO