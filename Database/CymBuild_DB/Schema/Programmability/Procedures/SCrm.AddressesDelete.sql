SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO






CREATE PROCEDURE [SCrm].[AddressesDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	UPDATE	a 
	SET		RowStatus = 254
	FROM	SCrm.Addresses a
	WHERE	(Guid = @Guid)
		AND	(NOT EXISTS
				(
					SELECT	1
					FROM	SCrm.AccountAddresses aa 
					WHERE	(aa.AddressID = a.ID)
						AND	(aa.RowStatus NOT IN (0, 254))
				)
			)
END;

GO