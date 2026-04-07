SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[ObjectSecurityUpsert]
	(	@ObjectGuid UNIQUEIDENTIFIER,
		@UserGuid UNIQUEIDENTIFIER,
		@GroupGuid UNIQUEIDENTIFIER,
		@CanRead BIT,
		@DenyRead BIT,
		@CanWrite BIT,
		@DenyWrite BIT,
		@Guid UNIQUEIDENTIFIER OUT
	)
AS
BEGIN
	DECLARE @UserId	 INT = -1,
			@GroupId INT = -1;

	SELECT	@UserId = i.ID
	FROM	SCore.Identities AS i
	WHERE	(i.Guid = @UserGuid);

	SELECT	@GroupId = g.ID
	FROM	SCore.Groups AS g
	WHERE	(g.Guid = @GroupGuid);

	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,						-- uniqueidentifier
								@SchemeName = N'SCore',				-- nvarchar(255)
								@ObjectName = N'ObjectSecurity',	-- nvarchar(255)
								@IncludeDefaultSecurity = 0,        -- bit
								@IsInsert = @IsInsert OUTPUT;		-- bit

	IF (@IsInsert = 1)
	BEGIN
		INSERT	SCore.ObjectSecurity
			 (RowStatus, Guid, ObjectGuid, UserId, GroupId, CanRead, DenyRead, CanWrite, DenyWrite)
		VALUES
			 (
				 1,				-- RowStatus - tinyint
				 @Guid,			-- Guid - uniqueidentifier
				 @ObjectGuid,	-- ObjectGuid - uniqueidentifier
				 @UserId,		-- UserId - int
				 @GroupId,		-- GroupId - int
				 @CanRead,		-- CanRead - bit
				 @DenyRead,		-- DenyRead - bit
				 @CanWrite,		-- CanWrite - bit
				 @DenyWrite		-- DenyWrite - bit
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SCore.ObjectSecurity
		SET		ObjectGuid = @ObjectGuid,
				UserId = @UserId,
				GroupId = @GroupId,
				CanRead = @CanRead,
				DenyRead = @DenyRead,
				CanWrite = @CanWrite,
				DenyWrite = @DenyWrite
		WHERE	(Guid = @Guid);
	END;
END;
GO