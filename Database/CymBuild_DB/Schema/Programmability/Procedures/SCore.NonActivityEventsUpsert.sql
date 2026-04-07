SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[NonActivityEventsUpsert]
(
	@AbsenceTypeGuid UNIQUEIDENTIFIER,
	@StartTime DATETIME,
	@EndTime DATETIME,
	@TeamId SMALLINT,
	@MemberId SMALLINT,
	@Guid UNIQUEIDENTIFIER
) 
AS
BEGIN


	DECLARE @AbsenceTypeID INT;

	 SELECT  @AbsenceTypeID = ID 
    FROM    SCore.NonActivityTypes 
    WHERE   ([Guid] = @AbsenceTypeGuid)


	DECLARE	@IsInsert bit
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SCore',				-- nvarchar(255)
							@ObjectName = N'NonActivityEvents',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0,
							@IsInsert = @IsInsert OUTPUT	-- bit


	IF (@IsInsert = 1)
    BEGIN 
        INSERT  SCore.NonActivityEvents 
        (
            RowStatus,
            Guid,
			AbsenceTypeID,
			StartTime,
			EndTime,
			TeamGroupId,
			MemberIdentityId
			
        )
        VALUES
        (
            1,
            @Guid,
			@AbsenceTypeID,
            @StartTime,
			@EndTime,
			@TeamId,
			@MemberId
        )
    END
    ELSE
    BEGIN 
        UPDATE  SCore.NonActivityEvents
        SET     RowStatus = 1,
                AbsenceTypeID = @AbsenceTypeID,
				StartTime = @StartTime,
				EndTime = @EndTime,
				TeamGroupId = @TeamId,
				MemberIdentityId = @MemberId
        WHERE   ([Guid] = @Guid)
    END


END;
GO