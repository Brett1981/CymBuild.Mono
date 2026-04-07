SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE PROCEDURE [SFin].[InvoiceSchedulesUpsert]
(
    @Guid								UNIQUEIDENTIFIER,
	@Name								NVARCHAR(100),
	@TriggerGuid						UNIQUEIDENTIFIER,
	@ExpectedDate						DATE,
	@DescriptionOfWork					NVARCHAR(MAX),
	@Amount								DECIMAL (19,2),
	@QuoteGuid							UNIQUEIDENTIFIER,

	--RIBA Config. params
	@RibaOnCompletion					BIT,
	@RibaOnPartCompletion				BIT,

	--Monthly Config. params			 
	@OnMilestoneCompletion				BIT,
	@OnActivityCompletion				BIT,
	@OnActivityAndMilestonCompletion	BIT
)
AS 
BEGIN 

   DECLARE	@TriggerId INT = -1,
			@QuoteId   INT,
			@IsInsert BIT;


	DECLARE 
			--Guids & IDs for the config tables.
			@RibaConfigGuid UNIQUEIDENTIFIER = NEWID(),
			@MonthlyConfigGuid UNIQUEIDENTIFIER = NEWID(),
			@RibaConfigId		INT,
			@ActivityMilestoneConfigId	INT







	--Get the triggerId.
	SELECT  @TriggerId = ID
	FROM [SFin].[InvoiceScheduleTrigger]
	WHERE ([Guid] = @TriggerGuid);

	--Get the ID for the quote
	SELECT @QuoteId = ID
	FROM SSop.Quotes
	WHERE ([Guid] = @QuoteGuid)


			
    EXEC SCore.UpsertDataObject @Guid = @Guid,					
							@SchemeName = N'SFin',				
							@ObjectName = N'InvoiceSchedules',				
							@IsInsert = @IsInsert OUTPUT,	
							@IncludeDefaultSecurity = 0
    IF (@IsInsert = 1)
    BEGIN

		


		/*
			=================================================
							RIBA CONFIG
			=================================================
		*/

		--Upsert Riba configuration
		EXEC SCore.UpsertDataObject @Guid = @RibaConfigGuid,					
							@SchemeName = N'SFin',				
							@ObjectName = N'InvoiceSchedule_Riba_Config',				
							@IsInsert = @IsInsert OUTPUT,	
							@IncludeDefaultSecurity = 0


		--Insert it into the table.
		 INSERT SFin.InvoiceScheduleRibaConfiguration
				(
					RowStatus,
					Guid,
					RibaOnCompletion,
					RibaOnPartCompletion
				)
		VALUES  (
					1,
					@RibaConfigGuid,
					@RibaOnCompletion,
					@RibaOnPartCompletion
				);


		--Get the ID for inserting it.
		SELECT @RibaConfigId = ID
		FROM SFin.InvoiceScheduleRibaConfiguration
		WHERE Guid = @RibaConfigGuid;



		/*
			=================================================
							MONTHLY CONFIG
			=================================================
		*/


		--Upsert Monthly configuration
		EXEC SCore.UpsertDataObject @Guid = @MonthlyConfigGuid,					
							@SchemeName = N'SFin',				
							@ObjectName = N'InvoiceSchedule_ActMil_Config',				
							@IsInsert = @IsInsert OUTPUT,	
							@IncludeDefaultSecurity = 0


		--Insert it into the table.
		 INSERT SFin.InvoiceScheduleActivityMilestoneConfiguration
				(
					RowStatus,
					Guid,
					OnMilestoneCompletion,
					OnActivityCompletion,
					OnActivityAndMilestonCompletion
				)
		VALUES  (
					1,
					@MonthlyConfigGuid,
					@OnMilestoneCompletion,
					@OnActivityCompletion,
					@OnActivityAndMilestonCompletion
					
				);


		--Get the ID for inserting it.
		SELECT @ActivityMilestoneConfigId = ID
		FROM SFin.InvoiceScheduleActivityMilestoneConfiguration
		WHERE Guid = @MonthlyConfigGuid;




		INSERT	SFin.InvoiceSchedules
				(
					RowStatus,
					Guid, 
					Name,
					TriggerId,
					ExpectedDate,
					DescriptionOfWork,
					Amount,
					QuoteId,
					RibaConfigurationId,
					ActivityMilestoneConfigurationId
				)
		VALUES
				(
					 1,						-- RowStatus - tinyint
					 @Guid,					-- Guid - uniqueidentifier
					 @Name,
					 @TriggerId,
					 @ExpectedDate,
					 @DescriptionOfWork,
					 @Amount,
					 @QuoteId,
					 @RibaConfigId,
					 @ActivityMilestoneConfigId
				 )
    END
    ELSE
    BEGIN 
		
		--Get the IDs for the config tables.
		SELECT @RibaConfigId = RibaConfigurationId
		FROM SFin.InvoiceSchedules
		WHERE Guid = @Guid;

		SELECT @ActivityMilestoneConfigId = ActivityMilestoneConfigurationId
		FROM SFin.InvoiceSchedules
		WHERE Guid = @Guid;


		--Now, get the Guids
		SELECT @RibaConfigGuid = Guid
		FROM SFin.InvoiceScheduleRibaConfiguration
		WHERE ID = @RibaConfigId

		SELECT @MonthlyConfigGuid = Guid
		FROM SFin.InvoiceScheduleActivityMilestoneConfiguration
		WHERE ID = @ActivityMilestoneConfigId

		



        UPDATE  SFin.InvoiceSchedules
		SET		Name = @Name,
				TriggerId = @TriggerId,
				ExpectedDate = @ExpectedDate,
				DescriptionOfWork = @DescriptionOfWork,
				Amount = @Amount,
				QuoteId = @QuoteId
        WHERE   ([Guid] = @Guid)


		--Update the config tables.
		UPDATE SFin.InvoiceScheduleActivityMilestoneConfiguration
		SET	OnMilestoneCompletion = @OnMilestoneCompletion,
			OnActivityCompletion = @OnActivityCompletion,
			OnActivityAndMilestonCompletion = @OnActivityAndMilestonCompletion
		WHERE ([Guid] = @MonthlyConfigGuid)

		UPDATE SFin.InvoiceScheduleRibaConfiguration
		SET RibaOnCompletion = @RibaOnCompletion,
			RibaOnPartCompletion = @RibaOnPartCompletion
		WHERE ([Guid] = @RibaConfigGuid)


    END
END
GO