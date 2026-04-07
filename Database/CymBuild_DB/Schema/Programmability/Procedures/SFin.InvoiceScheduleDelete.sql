SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE PROCEDURE [SFin].[InvoiceScheduleDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	
	DECLARE 
			--Monthly config
			@ActivityMilestoneConfigId	INT,
			@MonthlyConfigGuid  UNIQUEIDENTIFIER,
			
			--RIBA config.
			@RibaConfigId		INT,
			@RibaConfigGuid UNIQUEIDENTIFIER;


	
	SELECT 
			@ActivityMilestoneConfigId = ActivityMilestoneConfigurationId,
			@RibaConfigId = RibaConfigurationId
	FROM SFin.InvoiceSchedules
	WHERE ([Guid] = @Guid)


	--[Delete associated monthly config.]
	SELECT @MonthlyConfigGuid = Guid
	FROM SFin.InvoiceScheduleActivityMilestoneConfiguration
	WHERE (ID = @ActivityMilestoneConfigId);

	EXEC SCore.DeleteDataObject @Guid = @MonthlyConfigGuid	-- uniqueidentifier

	UPDATE	SFin.InvoiceScheduleActivityMilestoneConfiguration
	SET		RowStatus = 254
	WHERE	(Guid = @MonthlyConfigGuid)


	--[Delete associated RIBA config.]
	SELECT @RibaConfigGuid = Guid
	FROM SFin.InvoiceScheduleRibaConfiguration
	WHERE (ID = @RibaConfigId);

	EXEC SCore.DeleteDataObject @Guid = @RibaConfigGuid	-- uniqueidentifier

	UPDATE	[SFin].[InvoiceScheduleRibaConfiguration]
	SET		RowStatus = 254
	WHERE	(Guid = @RibaConfigGuid)
	
	

	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	

	UPDATE	[SFin].[InvoiceSchedules]
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)

END;

GO