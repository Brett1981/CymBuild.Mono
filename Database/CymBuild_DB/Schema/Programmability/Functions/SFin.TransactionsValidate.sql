SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SFin].[TransactionsValidate]
	(
		@Guid UNIQUEIDENTIFIER,
		@AccountGuid UNIQUEIDENTIFIER,
		@TransactionTypeGuid UNIQUEIDENTIFIER,
		@Batched BIT
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
	DECLARE @EntityPropertyGuid UNIQUEIDENTIFIER


	IF(@Batched = 0)
		BEGIN
			SELECT	@EntityPropertyGuid = ep.Guid
			FROM	SCore.EntityPropertiesV ep
			JOIN	SCore.EntityHobtsV eh ON (eh.ID = ep.EntityHoBTID)
			WHERE	(eh.SchemaName = N'SFin')
				AND (eh.ObjectName = N'Transactions')
				AND (ep.Name = N'Date')
			

			INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			VALUES
				 (
					 @EntityPropertyGuid,
					 N'P',
					 1,
					 0,
					 0,
					 N''
				 );

			SELECT	@EntityPropertyGuid = ep.Guid
			FROM	SCore.EntityPropertiesV ep
			JOIN	SCore.EntityHobtsV eh ON (eh.ID = ep.EntityHoBTID)
			WHERE	(eh.SchemaName = N'SFin')
				AND (eh.ObjectName = N'Transactions')
				AND (ep.Name = N'AccountID')
			

			INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			VALUES
				 (
					 @EntityPropertyGuid,
					 N'P',
					 1,
					 0,
					 0,
					 N''
				 );

				SELECT	@EntityPropertyGuid = ep.Guid
			FROM	SCore.EntityPropertiesV ep
			JOIN	SCore.EntityHobtsV eh ON (eh.ID = ep.EntityHoBTID)
			WHERE	(eh.SchemaName = N'SFin')
				AND (eh.ObjectName = N'Transactions')
				AND (ep.Name = N'TransactionTypeID')
			

			INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			VALUES
				 (
					 @EntityPropertyGuid,
					 N'P',
					 1,
					 0,
					 0,
					 N''
				 );

		END;
            
	-- Hide Terms for Bank Transactions 
	IF (EXISTS
			(
				SELECT	1
				FROM	SFin.TransactionTypes 
				WHERE	(Guid = @TransactionTypeGuid)
					AND	(IsBank = 1)
			)
		)
	BEGIN 
		SELECT	@EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SFin', N'Transactions', N'CreditTermsId')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 1,
				 0,
				 N''
			 );
	END

	IF (EXISTS
	 (
		 SELECT 1
		 FROM	SCrm.Accounts	  AS a
		 WHERE	(a.Guid = @AccountGuid)
			AND	(a.Code = N'')
	 )
	   )
	
	BEGIN 
		SELECT	@EntityPropertyGuid = ep.Guid
		FROM	SCore.EntityPropertiesV ep
		JOIN	SCore.EntityHobtsV eh ON (eh.ID = ep.EntityHoBTID)
		WHERE	(eh.SchemaName = N'SFin')
			AND (eh.ObjectName = N'Transactions')
			AND	(ep.Name	 = N'AccountId')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 0,
				 1,
				 N'An account must have a Sage Account Code before it can be used on transactions.'
			 );
	END;

	
	RETURN;
END;

GO