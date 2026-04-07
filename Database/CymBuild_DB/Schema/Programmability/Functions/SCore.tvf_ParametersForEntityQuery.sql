SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_ParametersForEntityQuery]
	(
		@Guid UNIQUEIDENTIFIER,
		@UserId INT
	)
RETURNS TABLE
              --WITH SCHEMABINDING
AS
RETURN SELECT		eqp.RowStatus,
					eqp.RowVersion,
					eqp.Guid,
					eqp.Name,
					edt.RowStatus AS EdtRowStatus,
					edt.RowVersion AS EdtRowVersion,
					edt.Guid AS EdtGuid,
					edt.Name AS EdtName,
					eqp.ID,
					ep.Name AS MappedEntityPropertyName,
					ep.Guid AS MappedEntityPropertyGuid
	   FROM			SCore.EntityQueryParametersV eqp
	   JOIN			SCore.EntityQueriesV eq ON(eqp.EntityQueryID = eq.ID)
	   JOIN			SCore.EntityDataTypesV edt ON(eqp.EntityDataTypeID = edt.ID)
	   JOIN			SCore.EntityPropertiesV ep ON(ep.ID = eqp.MappedEntityPropertyID)
	   OUTER APPLY	SCore.ObjectSecurityForUser(eqp.Guid, @UserId) os
	   WHERE		(eq.Guid = @Guid);
GO