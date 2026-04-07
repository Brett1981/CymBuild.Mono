SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE FUNCTION [SCrm].[tvf_ContactsValidate]
	(
		@Guid UNIQUEIDENTIFIER
	)
RETURNS @ValidationResult TABLE
	(
		ID INT IDENTITY(1, 1) NOT NULL,
		TargetGuid UNIQUEIDENTIFIER NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
		TargetType CHAR(1) NOT NULL DEFAULT (''),
		IsReadOnly BIT NOT NULL DEFAULT ((0)),
		IsHidden BIT NOT NULL DEFAULT ((0)),
		IsInvalid BIT NOT NULL DEFAULT ((0)),
		[IsInformationOnly] [BIT] NOT NULL DEFAULT((0)),
		Message NVARCHAR(2000) NOT NULL DEFAULT ('')
	)
AS
BEGIN
	DECLARE @EntityHoBTGuid UNIQUEIDENTIFIER,
          @CurrentUserId INT

  SELECT
          @CurrentUserId = SCore.GetCurrentUserId();  
            
	-- Hide Terms for Bank Transactions 
	IF ((EXISTS
			(
				SELECT  1
      FROM    SCore.Identities i 
      JOIN    SCrm.Contacts c ON i.ContactId = c.ID
      WHERE   (i.ContactId = c.Id)
        AND   (c.Guid = @Guid)
			)
		) AND 
    (NOT EXISTS
      (
        SELECT  1
        FROM    SCore.UserGroups ug
        JOIN    SCore.Groups g ON (ug.GroupID = g.ID)
        WHERE   (g.Code = N'SYSADM')
          AND   (ug.IdentityID = @CurrentUserId)
      )
    ))
	BEGIN 
		SELECT	@EntityHoBTGuid = guid 
    FROM    SCore.EntityHobts eh
    WHERE   (eh.SchemaName = N'SCrm')
      AND   (eh.ObjectName = N'Contacts')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityHoBTGuid,
				 N'H',
				 1,
				 0,
				 0,
				 N''
			 );
	END
	
	RETURN;
END;

GO