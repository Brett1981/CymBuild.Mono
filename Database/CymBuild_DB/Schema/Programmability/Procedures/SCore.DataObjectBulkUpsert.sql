SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create procedure [SCore].[DataObjectBulkUpsert]')
GO


CREATE PROCEDURE [SCore].[DataObjectBulkUpsert]
	(	@GuidList SCore.GuidUniqueList READONLY,
		@SchemeName NVARCHAR(255),
		@ObjectName NVARCHAR(255),
		@IncludeDefaultSecurity BIT = 1,
		@IsInsert BIT OUT
	)
AS
BEGIN
	SET NOCOUNT ON;

	IF (EXISTS
	 (
		 SELECT 1
		 FROM	SCore.DataObjects AS do
		 JOIN	@GuidList		  AS gl ON (gl.GuidValue = do.Guid)
	 )
	   )
	BEGIN
		SET @IsInsert = 0;
		RETURN;
	END;
	ELSE
	BEGIN
		DECLARE @EntityTypeId INT;

		SELECT	@EntityTypeId = eh.EntityTypeID
		FROM	SCore.EntityHobts AS eh
		WHERE	(eh.SchemaName = @SchemeName)
			AND (eh.ObjectName = @ObjectName);

		INSERT	SCore.DataObjects
			 (Guid, RowStatus, EntityTypeId)
		SELECT	GuidValue,		-- Guid - uniqueidentifier
				1,				-- RowStatus - tinyint
				@EntityTypeId	-- EntityTypeId - int
		FROM	@GuidList;

		IF (@IncludeDefaultSecurity = 1)
		BEGIN
			-- Create the default security record based on the User's profile. 
			DECLARE @DefaultSecurityGroupId INT;
					
			DECLARE	@SecurityRecords SCore.TwoGuidUniqueList

			INSERT	@SecurityRecords (GuidValue, GuidValueTwo)
			SELECT	GuidValue, newID()
			FROM	@GuidList

			-- Ensure bulk upsert always uses the legacy default group path
			EXEC sys.sp_set_session_context @key = N'new_entity_type_guid', @value = NULL, @read_only = 0;
			EXEC sys.sp_set_session_context @key = N'record_guid',         @value = NULL, @read_only = 0;

			SET @DefaultSecurityGroupId = SCore.GetCurrentUserDefaultGroup();

			IF (@DefaultSecurityGroupId > 0)
			BEGIN
				INSERT INTO SCore.DataObjects
					 (Guid, RowStatus, EntityTypeId)
				SELECT	GuidValueTwo,
						1,
						et.ID
				FROM	SCore.EntityHobts AS eh
				JOIN	SCore.EntityTypes AS et ON (et.ID = eh.EntityTypeID)
				CROSS JOIN @SecurityRecords
				WHERE	(eh.SchemaName = N'SCore')
					AND (eh.ObjectName = N'ObjectSecurity');

				/* Add the default  Security */
				INSERT	SCore.ObjectSecurity
					 (RowStatus, Guid, ObjectGuid, UserId, GroupId, CanRead, DenyRead, CanWrite, DenyWrite)
				SELECT	1,
						sr.GuidValueTwo,
						gl.GuidValue,
						-1,
						@DefaultSecurityGroupId,
						1,
						0,
						1,
						0
				FROM	@GuidList gl
				JOIN	@SecurityRecords sr ON (sr.GuidValue = gl.GuidValue)
			END;
		END;

		SET @IsInsert = 1;
		RETURN;
	END;
END;
GO