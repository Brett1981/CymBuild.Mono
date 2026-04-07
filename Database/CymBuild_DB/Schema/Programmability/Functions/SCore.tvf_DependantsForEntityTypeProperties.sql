SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_DependantsForEntityTypeProperties]
	(
		@EntityTypeGuid UNIQUEIDENTIFIER
	)
RETURNS TABLE
	   --WITH SCHEMABINDING
AS
RETURN SELECT		epd.Guid,
					epd.RowStatus,
					p.Guid AS SourcePropertyGuid,
					tp.Guid AS DependantPropertyGuid
	   FROM			SCore.EntityPropertyDependants AS epd
	   JOIN			SCore.EntityProperties					AS p ON (p.ID = epd.ParentEntityPropertyID)
	   JOIN			SCore.EntityProperties					AS tp ON (tp.ID = epd.DependantPropertyID)
	   JOIN			SCore.EntityHobts AS eh ON (eh.ID = p.EntityHoBTID)
	   JOIN			SCore.EntityTypes						AS et ON (et.ID = eh.EntityTypeId)
	   WHERE		(et.Guid = @EntityTypeGuid)
				AND	(epd.RowStatus NOT IN (0, 254))

GO