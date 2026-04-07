SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



CREATE PROCEDURE [SJob].[JobMemosUpsert]
(
    @JobGuid UNIQUEIDENTIFIER,
	@Memo NVARCHAR(MAX),
	@CreatedDateTimeUTC DATETIME2,
	@CreatedByUserGuid UNIQUEIDENTIFIER,
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
    DECLARE @CreatedByUserID INT,
            @JobID INT

    SELECT  @CreatedByUserID = ID 
    FROM    SCore.Identities 
    WHERE   ([Guid] = @CreatedByUserGuid)

    SELECT  @JobID = ID 
    FROM    SJob.Jobs 
    WHERE   ([Guid] = @JobGuid)

	IF (@CreatedDateTimeUTC IS NULL)
	BEGIN 
		SET @CreatedDateTimeUTC = GETUTCDATE()
	END

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'JobMemos',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SJob.JobMemos
			 (RowStatus, Guid, JobID, Memo, CreatedDateTimeUTC, CreatedByUserId)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @JobID,	-- JobID - int
				 @Memo,	-- Memo - nvarchar(max)
				 @CreatedDateTimeUTC,	-- CreatedDateTimeUTC - datetime2(7)
				 @CreatedByUserID	-- CreatedByUserId - int
			 )
    END
    ELSE
    BEGIN 
        UPDATE  SJob.JobMemos
        SET     JobID = @JobID,
                Memo = @Memo,
				CreatedDateTimeUTC = @CreatedDateTimeUTC,
				CreatedByUserId = @CreatedByUserID
        WHERE   ([Guid] = @Guid)
    END
END
GO