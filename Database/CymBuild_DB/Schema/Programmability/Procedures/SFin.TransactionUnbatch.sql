SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SFin].[TransactionUnbatch] 
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



	IF(@IsBatched = 1)
		BEGIN
		
			UPDATE	SFin.Transactions
			SET		Batched = 0
			WHERE	(Guid = @Guid)
		END;
	-- Otherwise, throw an error.
	ELSE
		BEGIN
			SET @ErrorMessage = CONCAT('Cannot unbatch transaction ', @TransactionNumber);

			;THROW 51003, @ErrorMessage, 1;
		END;

	

END;

GO