SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO






CREATE PROCEDURE [SCrm].[ContactsDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	UPDATE	c
	SET		RowStatus = 254
	FROM	SCrm.Contacts c
	WHERE	(Guid = @Guid)
		AND	(NOT EXISTS
				(
					SELECT	1
					FROM	SCrm.AccountContacts ac
					WHERE	(ac.ContactID = c.ID)
						AND	(ac.RowStatus NOT IN (0, 254))
				)
			)
END;

GO