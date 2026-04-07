SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SFin].[InvoicePaymentStatusUpsert] 
								@Name NVARCHAR(100),
								@Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					
							@SchemeName = N'SFin',				
							@ObjectName = N'InvoicePaymentStatus',				
							@IsInsert = @IsInsert OUTPUT	

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SFin.InvoicePaymentStatus
			 (RowStatus,
			  Guid,
			  Name)
		VALUES
			 (
				 1,						-- RowStatus - tinyint
				 @Guid,				-- Guid - uniqueidentifier
				 @Name
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SFin.InvoicePaymentStatus
		SET		Name = @Name
		WHERE	(Guid = @Guid);
	END;
END;

GO