SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SProd].[ProductsUpsert]
(
	@Code NVARCHAR(30),
	@Description NVARCHAR(2000),
	@CreatedJobTypeGuid UNIQUEIDENTIFIER,
	@NeverConsolidate BIT,
	@RibaStageGuid UNIQUEIDENTIFIER,
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
    DECLARE @CreatedJobTypeId INT,
			@RibaStageId INT

	SELECT  @CreatedJobTypeId = ID 
    FROM    SJob.JobTypes
    WHERE   ([Guid] = @CreatedJobTypeGuid)

	SELECT	@RibaStageId = ID 
	FROM	SJob.RibaStages 
	WHERE	([Guid] = @RibaStageGuid)

	DECLARE @IsInsert BIT;
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
								@SchemeName = N'SProd',				-- nvarchar(255)
								@ObjectName = N'Products',				-- nvarchar(255)
								@IncludeDefaultSecurity = 0, -- bit
								@IsInsert = @IsInsert OUTPUT	-- bit
	

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SProd.Products
			 (RowStatus, Guid, Code, Description, CreatedJobType, NeverConsolidate, RibaStageId)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @Code,	-- Code - nvarchar(30)
				 @Description,	-- Description - nvarchar(2000)
				 @CreatedJobTypeId,	-- CreatedJobType - int
				 @NeverConsolidate,	-- NeverConsolidate - bit
				 @RibaStageId
			 )
    END
    ELSE
    BEGIN 
        UPDATE  SProd.Products
        SET     Code = @Code,
				Description = @Description,
				CreatedJobType = @CreatedJobTypeId,
				NeverConsolidate = @NeverConsolidate,
				RibaStageId = @RibaStageId
		WHERE   ([Guid] = @Guid)
    END
END
GO