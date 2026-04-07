SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO





CREATE PROCEDURE [SCrm].[AccountAddressesDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	

	UPDATE	SCrm.AccountAddresses
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)

END;

GO