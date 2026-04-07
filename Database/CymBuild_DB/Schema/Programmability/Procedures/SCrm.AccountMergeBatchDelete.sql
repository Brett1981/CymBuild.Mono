SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO





CREATE PROCEDURE [SCrm].[AccountMergeBatchDelete]
  @Guid      UNIQUEIDENTIFIER
AS
  BEGIN
   EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	

	UPDATE	SCrm.AccountMergeBatch
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)
  END;

GO