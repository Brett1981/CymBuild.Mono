SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[EntityQueriesValidate]
	(
		@Guid UNIQUEIDENTIFIER,
		@IsDefaultRead BIT,
		@Statement NVARCHAR(2550),
		@IsManualStatement BIT 
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
	IF (@Statement NOT LIKE N'%root_hobt%')
			AND (@IsDefaultRead = 1)
			AND (@IsManualStatement = 1)
	BEGIN
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT
				 epfvv.Guid,
				 N'P',
				 0,
				 0,
				 1,
				 N'The read statement must use "root_hobt" as the alias for the Entity''s main HoBT.'
		FROM	SCore.EntityPropertiesForValidationV AS epfvv
		WHERE	(epfvv.[Schema] = N'SCore')
			AND	(epfvv.Hobt = N'EntityQueries')
			AND	(epfvv.Name = N'Statement')
	END;

	IF (@IsManualStatement = 0)
	BEGIN 
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, IsInformationOnly, Message)
		SELECT
				 epfvv.Guid,	-- TargetGuid - uniqueidentifier
				 'P',	-- TargetType - char(1)
				 1,	-- IsReadOnly - bit
				 0,	-- IsHidden - bit
				 0,	-- IsInvalid - bit
				 0,	-- IsInformationOnly - bit
				 N''	-- Message - nvarchar(2000)
		FROM	SCore.EntityPropertiesForValidationV AS epfvv
		WHERE	(epfvv.[Schema] = N'SCore')
			AND	(epfvv.Hobt = N'EntityQueries')
			AND	(epfvv.Name = N'Statement')
	END

	RETURN;
END;

GO