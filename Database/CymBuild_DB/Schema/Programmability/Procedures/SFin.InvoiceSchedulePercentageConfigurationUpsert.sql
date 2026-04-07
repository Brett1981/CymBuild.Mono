SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE PROCEDURE [SFin].[InvoiceSchedulePercentageConfigurationUpsert]
  (
    @Guid        UNIQUEIDENTIFIER,
	@InvoiceScheduleGuid UNIQUEIDENTIFIER,
	@OnDayOfMonth DATE,
	@PeriodNumber INT,
	@Percentage	  DECIMAL(19,2),
	@Description NVARCHAR(MAX)
  )
AS
  BEGIN
    SET NOCOUNT ON;

    DECLARE 
			@InvoiceScheduleId INT,
			@IsInsert BIT = 0;


	SELECT @InvoiceScheduleId = ID 
	FROM SFin.InvoiceSchedules
	WHERE([Guid] = @InvoiceScheduleGuid)




    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SFin',			-- nvarchar(255)
      @ObjectName = N'InvoiceSchedulePercentageConfiguration',		-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT;	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT INTO SFin.InvoiceSchedulePercentageConfiguration
                  (
                    RowStatus,
                    Guid,
					InvoiceScheduleId,
					OnDayOfMonth,
					PeriodNumber,
					Percentage,
					Description
                  )
        VALUES
                (
                  1,
                  @Guid,
                  @InvoiceScheduleId,
				  @OnDayOfMonth,
				  @PeriodNumber,
				  @Percentage,
				  @Description
                );
      END;
    ELSE
      BEGIN
        UPDATE  SFin.InvoiceSchedulePercentageConfiguration
        SET     InvoiceScheduleId = @InvoiceScheduleId,
                OnDayOfMonth = @OnDayOfMonth,
				PeriodNumber = @PeriodNumber,
				Percentage = @Percentage,
				Description = @Description
        WHERE
          (Guid = @Guid);
      END;
  END;
GO