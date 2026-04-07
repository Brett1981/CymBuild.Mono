SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCrm].[AccountMergeBatchUpsert]
	(	@SourceAccountGuid UNIQUEIDENTIFIER,
		@TargetAccountGuid UNIQUEIDENTIFIER,
		@CreatedByUserGuid UNIQUEIDENTIFIER,
		@CheckedByUserGuid UNIQUEIDENTIFIER,
		@Guid UNIQUEIDENTIFIER
	)
AS
BEGIN
	DECLARE @SourceAccountId INT,
			@TargetAccountId INT,
			@CreatedByUserId INT,
			@CheckedByUserId INT;

	SELECT	@SourceAccountId = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @SourceAccountGuid);

	SELECT	@TargetAccountId = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @TargetAccountGuid);

	SELECT	@CreatedByUserId = ID
	FROM	SCore.Identities
	WHERE	(Guid = @CreatedByUserGuid);

	SELECT	@CheckedByUserId = ID
	FROM	SCore.Identities
	WHERE	(Guid = @CheckedByUserGuid);

	DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@IncludeDefaultSecurity = 0,
							@SchemeName = N'SCrm',				-- nvarchar(255)
							@ObjectName = N'AccountMergeBatch',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SCrm.AccountMergeBatch
			 (RowStatus, Guid, SourceAccountId, TargetAccountId, CreatedByUserId, CheckedByUserId, IsComplete)
		VALUES
			 (
				 1,					-- RowStatus - tinyint
				 @Guid,				-- Guid - uniqueidentifier
				 @SourceAccountId,	-- SourceAccountId - int
				 @TargetAccountId,	-- TargetAccountId - int
				 @CreatedByUserId,	-- CreatedByUserId - int
				 @CheckedByUserId,	-- CheckedByUserId - int
				 0					-- IsComplete - bit
			 );

	END;
	ELSE
	BEGIN
		UPDATE	SCrm.AccountMergeBatch
		SET		SourceAccountId = @SourceAccountId,
				TargetAccountId = @TargetAccountId,
				CheckedByUserId = @CheckedByUserId
		WHERE	(Guid = @Guid);
	END;

	IF (@CheckedByUserId > -1)
	BEGIN
		EXEC SCrm.MergeAccounts @FromAccountGuid = @SourceAccountGuid,	-- uniqueidentifier
								@ToAccountGuid = @TargetAccountGuid;	-- uniqueidentifier

		UPDATE	SCrm.AccountMergeBatch
		SET		IsComplete = 1
		WHERE	(Guid = @Guid);	
	END;

END;
GO