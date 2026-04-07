SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE PROCEDURE [SJob].[JobKeyDatesUpsert]
(
    @JobGuid UNIQUEIDENTIFIER,
	  @Detail nvarchar(500),
    @DateTime datetime2,
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
    DECLARE @PurposeGroupID INT,
            @JobID INT

    SELECT  @JobID = ID 
    FROM    SJob.Jobs 
    WHERE   ([Guid] = @JobGuid)

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'JobKeyDates',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SJob.JobKeyDates
			 (RowStatus, Guid, JobID, Detail, DateTime)
		VALUES
			 (
				 1,	
				 @Guid,	
         @JobId, 
				 @Detail,
				 @DateTime
			 )

    END
    ELSE
    BEGIN 
        UPDATE  SJob.JobKeyDates
        SET     Detail = @Detail,
                DateTime = @DateTime
        WHERE   ([Guid] = @Guid)
    END
END
GO