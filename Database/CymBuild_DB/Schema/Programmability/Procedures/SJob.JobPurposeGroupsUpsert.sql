SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE PROCEDURE [SJob].[JobPurposeGroupsUpsert]
(
    @JobGuid UNIQUEIDENTIFIER,
	@PurposeGroupGuid UNIQUEIDENTIFIER,
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
    DECLARE @PurposeGroupID INT,
            @JobID INT

    SELECT  @PurposeGroupID = ID 
    FROM    SJob.PurposeGroups 
    WHERE   ([Guid] = @PurposeGroupGuid)

    SELECT  @JobID = ID 
    FROM    SJob.Jobs 
    WHERE   ([Guid] = @JobGuid)

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'JobPurposeGroups',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SJob.JobPurposeGroups
			 (RowStatus, Guid, JobID, PurposeGroupID)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @JobID,	-- JobID - int
				 @PurposeGroupID	-- PurposeGroupID - int
			 )

    END
    ELSE
    BEGIN 
        UPDATE  SJob.JobPurposeGroups
        SET     JobID = @JobID,
                PurposeGroupID = @PurposeGroupID
        WHERE   ([Guid] = @Guid)
    END
END
GO