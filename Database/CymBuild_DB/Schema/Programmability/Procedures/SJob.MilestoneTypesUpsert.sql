SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[MilestoneTypesUpsert] @Name NVARCHAR(100),
										  @Code NVARCHAR(20),
										  @IsActive BIT,
										  @IsInvoiceTrigger BIT,
										  @IsReviewRequired BIT,
										  @HelpText NVARCHAR(2000),
										  @Hasdescription BIT,
										  @IsCompulsory BIT,
										  @IncludeStart BIT,
										  @IncludeSchedule BIT,
										  @IncludeDueDate BIT,
										  @HasExternalSubmission BIT,
										  @Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE @IsInsert BIT;
	EXEC SCore.UpsertDataObject @Guid = @Guid,						-- uniqueidentifier
								@SchemeName = N'SJob',				-- nvarchar(255)
								@ObjectName = N'MilestoneTypes',	-- nvarchar(255)
								@IncludeDefaultSecurity = 0,        --bit
								@IsInsert = @IsInsert OUTPUT;		-- bit

	IF (@IsInsert = 1)
	BEGIN
		INSERT	SJob.MilestoneTypes
			 (RowStatus,
			  Guid,
			  Name,
			  Code,
			  IsActive,
			  IsInvoiceTrigger,
			  IsReviewRequired,
			  HelpText,
			  HasDescription,
			  IsCompulsory,
			  IncludeStart,
			  IncludeSchedule,
			  IncludeDueDate,
			  HasExternalSubmission)
		VALUES
			 (
				 1,		-- RowStatus - tinyint
				 @Guid, -- Guid - uniqueidentifier
				 @Name,
				 @Code,
				 @IsActive,
				 @IsInvoiceTrigger,
				 @IsReviewRequired,
				 @HelpText,
				 @Hasdescription,
				 @IsCompulsory,
				 @IncludeStart,
				 @IncludeSchedule,
				 @IncludeDueDate,
				 @HasExternalSubmission
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SJob.MilestoneTypes
		SET		Name = @Name,
				Code = @Code,
				IsActive = @IsActive,
				IsInvoiceTrigger = @IsInvoiceTrigger,
				IsReviewRequired = @IsReviewRequired,
				HelpText = @HelpText,
				HasDescription = @Hasdescription,
				IsCompulsory = @IsCompulsory,
				IncludeStart = @IncludeStart,
				IncludeSchedule = @IncludeSchedule,
				IncludeDueDate = @IncludeDueDate,
				HasExternalSubmission = @HasExternalSubmission
		WHERE	(Guid = @Guid);
	END;
END;

GO