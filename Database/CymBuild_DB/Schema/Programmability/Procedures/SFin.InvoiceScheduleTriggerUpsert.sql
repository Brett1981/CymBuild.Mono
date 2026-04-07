SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE PROCEDURE [SFin].[InvoiceScheduleTriggerUpsert]
(
    @Guid UNIQUEIDENTIFIER,
	@Name NVARCHAR(100)
)
AS 
BEGIN 

   DECLARE @IsInsert BIT
			

    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SFin',				-- nvarchar(255)
							@ObjectName = N'InvoiceScheduleTrigger',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT,	-- bit
							@IncludeDefaultSecurity = 0
    IF (@IsInsert = 1)
    BEGIN
		INSERT	SFin.InvoiceScheduleTrigger
				(
					RowStatus,
					Guid, 
					Name
				)
		VALUES
				(
					 1,						-- RowStatus - tinyint
					 @Guid,					-- Guid - uniqueidentifier
					 @Name
				 )
    END
    ELSE
    BEGIN 
        UPDATE  SFin.InvoiceScheduleTrigger
		SET		Name = @Name
        WHERE   ([Guid] = @Guid)
    END
END
GO