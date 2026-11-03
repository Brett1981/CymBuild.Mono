SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionBatchDelete]')
GO

/* =============================================================================
   Default delete query for SFin.Transactions (EntityQuery d9343718-...).

   A Batched transaction can be deleted, as before.

   CYB-555 (12/10/2026): a non-batched Receipt can also be deleted. Sage does
   not return a distinct row for a credit-note settlement, so the type 4
   fallback records it as a Receipt; Finance must be able to remove those.
   The receipt's lines and every allocation it takes part in are retired with
   it, otherwise the invoice it paid would still show as allocated.
   SFin.SageInboundReceiptAndAllocation_Materialise leaves a receipt deleted
   here deleted.
   Any other non-batched transaction is still refused.
============================================================================= */
CREATE PROCEDURE [SFin].[TransactionBatchDelete]
								@Guid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @IsBatched BIT = 0,
            @IsReceipt BIT = 0,
            @TransactionId BIGINT,
            @TransactionNumber NVARCHAR(30),
            @ErrorMessage NVARCHAR(4000);

	-- CYB-555-RECEIPT-DELETE: the type is matched by name, as
	-- SFin.SageInboundReceiptAndAllocation_Materialise resolves it; the
	-- TransactionTypes Guids are not the same in every environment.
	SELECT	@TransactionId = t.ID,
			@IsBatched = t.Batched,
			@TransactionNumber = t.Number,
			@IsReceipt = CASE WHEN UPPER(LTRIM(RTRIM(tt.Name))) = N'RECEIPT' THEN 1 ELSE 0 END
	FROM SFin.Transactions AS t
	JOIN SFin.TransactionTypes AS tt ON (tt.ID = t.TransactionTypeID)
	WHERE (t.[Guid] = @Guid)

	-- Only delete if @IsBatched = 1
	IF(@IsBatched = 1)
		BEGIN
			EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier


			UPDATE	SFin.Transactions
			SET		RowStatus = 254
			WHERE	(Guid = @Guid)
		END;
	-- CYB-555: or a non-batched Receipt, with its lines and allocations.
	ELSE IF(@IsReceipt = 1)
		BEGIN
			BEGIN TRANSACTION;

			UPDATE	dob
			SET		RowStatus = 254
			FROM	SCore.DataObjects AS dob
			JOIN	SFin.TransactionAllocations AS ta ON (ta.Guid = dob.Guid)
			WHERE	(ta.RowStatus NOT IN (0, 254))
				AND	((ta.SourceTransactionID = @TransactionId) OR (ta.TargetTransactionID = @TransactionId));

			UPDATE	SFin.TransactionAllocations
			SET		RowStatus = 254
			WHERE	(RowStatus NOT IN (0, 254))
				AND	((SourceTransactionID = @TransactionId) OR (TargetTransactionID = @TransactionId));

			UPDATE	dob
			SET		RowStatus = 254
			FROM	SCore.DataObjects AS dob
			JOIN	SFin.TransactionDetails AS td ON (td.Guid = dob.Guid)
			WHERE	(td.RowStatus NOT IN (0, 254))
				AND	(td.TransactionID = @TransactionId);

			UPDATE	SFin.TransactionDetails
			SET		RowStatus = 254
			WHERE	(RowStatus NOT IN (0, 254))
				AND	(TransactionID = @TransactionId);

			EXEC SCore.DeleteDataObject @Guid = @Guid;

			UPDATE	SFin.Transactions
			SET		RowStatus = 254
			WHERE	(ID = @TransactionId);

			COMMIT TRANSACTION;
		END;
	-- Otherwise, throw an error.
	ELSE
		BEGIN
			SET @ErrorMessage = CONCAT('Cannot delete transaction ', @TransactionNumber);

			;THROW 51003, @ErrorMessage, 1;
		END;



END;

GO
