SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SJob].[PurchaseOrdersUpsert]')
GO


CREATE PROCEDURE [SJob].[PurchaseOrdersUpsert]
	(
		@Guid			UNIQUEIDENTIFIER,
		@Number			NVARCHAR(15),
		@Description	NVARCHAR(MAX),
		@Value			DECIMAL(19,2),
		@DateReceived	DATE,
		@ValidUntilDate DATE,
		@ActivityGuid	UNIQUEIDENTIFIER,
		@JobGuid		UNIQUEIDENTIFIER

	)
AS
	BEGIN

		DECLARE 
				@ActivityId		INT = -1,
				@StageId		INT = -1,
				@AssetId		INT = -1,
				@JobId			INT = -1;
				

		SELECT @ActivityId = ID
		FROM SJob.Activities
		WHERE (Guid = @ActivityGuid);

		--SELECT @StageId = ID 
		--FROM SJob.RibaStages
		--WHERE (Guid = @StageGuid);

		--SELECT @AssetId = ID
		--FROM SJob.Assets
		--WHERE (Guid = @StageGuid);

		SELECT @JobId = ID
		FROM SJob.Jobs
		WHERE (Guid = @JobGuid);




		DECLARE @IsInsert BIT
		EXEC SCore.UpsertDataObject
			@Guid		= @Guid,					-- uniqueidentifier
			@SchemeName = N'SJob',				-- nvarchar(255)
			@ObjectName = N'PurchaseOrders',				-- nvarchar(255)
			@IsInsert   = @IsInsert OUTPUT	-- bit

		IF (@IsInsert = 1)
			BEGIN
				INSERT SJob.PurchaseOrders
						(
							RowStatus,
							Guid,
							Number,
							Description,
							StageId,
							SiteId,
							Value,
							DateReceived,
							ValidUntilDate,
							ActivityId,
							JobId
						)
				VALUES
						(
							1,	-- RowStatus - tinyint
							@Guid,	-- Guid - uniqueidentifier
							@Number,
							@Description,
							@StageId,
							@AssetId,
							@Value,
							@DateReceived,
							@ValidUntilDate,
							@ActivityId,
							@JobId
						)
			END
		ELSE
			BEGIN
				UPDATE  SJob.PurchaseOrders
				SET		
					Number			= @Number,
					Description		= @Description,
					StageId			= @StageId,
					SiteId			= @AssetId,
					Value			= @Value,
					DateReceived	= @DateReceived,
					ValidUntilDate	= @ValidUntilDate,
					ActivityId		= @ActivityId,
					JobId			= @JobId
				WHERE
					([Guid] = @Guid)
			END
	END
GO