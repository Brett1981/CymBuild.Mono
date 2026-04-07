SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SJob].[ProductJobActivitiesUpsert]
(
	@ProductGuid UNIQUEIDENTIFIER,
	@JobTypeActivityTypeGuid UNIQUEIDENTIFIER,
	@ActivityTitle NVARCHAR(250),
	@OffsetDays INT,
	@OffsetWeeks INT,
	@OffsetMonths INT,
	@JobTypeMilestoneTemplateGuid UNIQUEIDENTIFIER,
	@PercentageOfProductValue DECIMAL(5,2),
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
    DECLARE @ProductId INT,
			@JobActivityTypeId INT,
			@JobTypeMilestoneTemplateId INT

	SELECT  @ProductId = ID 
    FROM    SProd.Products AS p
    WHERE   ([Guid] = @ProductGuid)

	SELECT	@JobActivityTypeId = ID 
	FROM	SJob.JobTypeActivityTypes AS jtat 
	WHERE	([Guid] = @JobTypeActivityTypeGuid)

	SELECT	@JobTypeMilestoneTemplateId = ID 
	FROM	SJob.JobTypeMilestoneTemplates AS jtmt  
	WHERE	([Guid] = @JobTypeMilestoneTemplateGuid)

	DECLARE @IsInsert BIT;
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
								@SchemeName = N'SProd',				-- nvarchar(255)
								@ObjectName = N'Products',				-- nvarchar(255)
								@IncludeDefaultSecurity = 1, -- bit
								@IsInsert = @IsInsert OUTPUT	-- bit	

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SJob.ProductJobActivities
			 (RowStatus,
			  Guid,
			  ProductId,
			  JobTypeActivityTypeId,
			  ActivityTitle,
			  OffsetDays,
			  OffsetWeeks,
			  OffsetMonths,
			  JobTypeMilestoneTemplateId,
			  PercentageOfProductValue)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @ProductId,	-- ProductId - int
				 @JobActivityTypeId,	-- JobTypeActivityTypeId - int
				 @ActivityTitle,	-- ActivityTitle - nvarchar(250)
				 @OffsetDays,	-- OffsetDays - int
				 @OffsetWeeks,	-- OffsetWeeks - int
				 @OffsetMonths,	-- OffsetMonths - int
				 @JobTypeMilestoneTemplateId,	-- JobTypeMilestoneTemplateId - int
				 @PercentageOfProductValue	-- PercentageOfProductValue - decimal(5, 2)
			 )
    END
    ELSE
    BEGIN 
        UPDATE  SJob.ProductJobActivities
        SET     ProductId = @ProductId,
				JobTypeActivityTypeId = @JobActivityTypeId,
				ActivityTitle = @ActivityTitle,
				OffsetDays = @OffsetDays,
				OffsetWeeks = @OffsetWeeks,
				OffsetMonths = @OffsetMonths,
				JobTypeMilestoneTemplateId = @JobTypeMilestoneTemplateId,
				PercentageOfProductValue = @PercentageOfProductValue
		WHERE   ([Guid] = @Guid)
    END
END
GO