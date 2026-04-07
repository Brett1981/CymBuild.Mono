SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SFin].[TransactionBatchDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN

    DECLARE @IsBatched BIT = 0,
            @TransactionNumber NVARCHAR(10),
            @ErrorMessage NVARCHAR(4000);

	SELECT	@IsBatched = Batched,
			@TransactionNumber = Number
	FROM SFin.Transactions
	WHERE ([Guid] = @Guid)




	-- Only delete if @IsBatched = 1
	IF(@IsBatched = 1)
		BEGIN
			EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	

			UPDATE	SFin.Transactions
			SET		RowStatus = 254
			WHERE	(Guid = @Guid)
		END;
	-- Otherwise, throw an error.
	ELSE
		BEGIN
			SET @ErrorMessage = CONCAT('Cannot delete transaction ', @TransactionNumber);

			;THROW 51003, @ErrorMessage, 1;
		END;

	

END;

GO