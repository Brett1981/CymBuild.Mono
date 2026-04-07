SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[ActivityTypesUpsert] 
								@Name NVARCHAR(100),
								@IsActive BIT,
								@SortOrder INT,
								@IsFeeTrigger BIT,
								@IsLiveTrigger BIT,
								@IsAdmin BIT,
								@IsScheduleItem BIT, 
								@Colour NVARCHAR(6),
								@IsMeeting BIT,
								@IsSiteVisit BIT,
								@IsCommencementTrigger BIT,
								@Guid UNIQUEIDENTIFIER OUT,
								@IsBillable BIT
AS
BEGIN
	DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'ActivityTypes',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0, -- bit
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SJob.ActivityTypes
			 (RowStatus,
			  Guid,
			  Name,
			  IsActive,
			  SortOrder,
			  IsFeeTrigger,
			  IsLiveTrigger,
			  IsAdmin,
			  IsScheduleItem,
              Colour,
			  IsMeeting,
			  IsSiteVisit,
			  IsCommencementTrigger,
			  IsBillable
			)
		VALUES
			 (
				 1,						-- RowStatus - tinyint
				 @Guid,				-- Guid - uniqueidentifier
				 @Name,
				 @IsActive,
				 @SortOrder,
				 @IsFeeTrigger,
				 @IsLiveTrigger,
				 @IsAdmin,
				 @IsScheduleItem,
				 @Colour,
				 @IsMeeting,
				 @IsSiteVisit,
				 @IsCommencementTrigger,
				 @IsBillable
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SJob.ActivityTypes
		SET		Name = @Name,
				IsActive = @IsActive,
				SortOrder = @SortOrder,
				IsFeeTrigger = @IsFeeTrigger,
				IsLiveTrigger = @IsLiveTrigger,
				IsAdmin = @IsAdmin,
				IsScheduleItem = @IsScheduleItem,
				Colour = @Colour,
				IsMeeting = @IsMeeting,
				IsSiteVisit = @IsSiteVisit,
				IsCommencementTrigger = @IsCommencementTrigger,
				IsBillable = @IsBillable
		WHERE	(Guid = @Guid);
	END;
END;

GO