SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO





CREATE PROCEDURE [SCrm].[ContactDetailsDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	UPDATE	SCrm.ContactDetails
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)

END;

GO