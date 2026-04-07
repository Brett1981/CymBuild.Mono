SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[ObjectSecurity_ClearForEntityType]
(
	@EntityTypeGuid UNIQUEIDENTIFIER
)
AS
BEGIN

	DECLARE	@MainHobtSchema nvarchar(255),
			@MainHobtTable nvarchar(255),
			@stmt nvarchar(4000)

	SELECT	@MainHobtTable = eh.ObjectName,
			@MainHobtSchema = eh.SchemaName
	FROM	SCore.EntityTypes et
	JOIN	SCore.EntityHobts eh on (eh.EntityTypeID = et.ID)
	WHERE	(eh.IsMainHoBT = 1)
		AND	(et.Guid = @EntityTypeGuid)


	set @stmt = N'
	DECLARE	@GuidList SCore.GuidUniqueList
	INSERT	@GuidList (GuidValue)
	SELECT	Guid
	FROM	[' + @MainHobtSchema + '].[' + @MainHobtTable + ']
	WHERE	(id > 0)

	DELETE	os
	FROM SCore.ObjectSecurity os
	WHERE	(EXISTS 
				(
					SELECT	1	
					FROM	@GuidList gl
					WHERE	(gl.GuidValue = os.ObjectGuid)
				)
			)
	'	


	exec sp_executesql @stmt

END
GO