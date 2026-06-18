SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SJob].[RibaStagesValidate]')
GO

CREATE FUNCTION [SJob].[RibaStagesValidate]
	(
		@Guid UNIQUEIDENTIFIER,
		@Description NVARCHAR(1000),
		@IsCustomStage BIT,
		@Number INT
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
			@EntityPropertyGuid UNIQUEIDENTIFIER



	--Ensure no duplicate "Number" field
	IF(EXISTS(SELECT 1 FROM SJob.RibaStages WHERE Description = @Description AND Guid <> @Guid AND Description <> N''))
		BEGIN
		-- Force the user set a  different number
			INSERT INTO @ValidationResult
				(TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT epfvv.Guid,
				   N'P',
				   0,
				   0,
				   1,
				   N'Description must be unique.'
			FROM SCore.EntityPropertiesForValidationV AS epfvv
			WHERE epfvv.[Schema] = N'SJob'
			  AND epfvv.Hobt     = N'RibaStages'
			  AND epfvv.Name     = N'Description';
		END;

	--Ensure no duplicate "Number" field
	IF(EXISTS(SELECT 1 FROM SJob.RibaStages WHERE Number = @Number AND Guid <> @Guid))
		BEGIN
		-- Force the user set a  different number
			INSERT INTO @ValidationResult
				(TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT epfvv.Guid,
				   N'P',
				   0,
				   0,
				   1,
				   N'This number has already been specified.'
			FROM SCore.EntityPropertiesForValidationV AS epfvv
			WHERE epfvv.[Schema] = N'SJob'
			  AND epfvv.Hobt     = N'RibaStages'
			  AND epfvv.Name     = N'Number';
		END;

	IF(NOT EXISTS(SELECT 1 FROM SJob.RibaStages WHERE Guid = @Guid) AND @IsCustomStage = 0)
	BEGIN
			-- Force the user to tick "Is Custom Stage"
			INSERT INTO @ValidationResult
				(TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT epfvv.Guid,
				   N'P',
				   0,
				   0,
				   1,
				   N'This field must be enabled for custom RIBA stages.'
			FROM SCore.EntityPropertiesForValidationV AS epfvv
			WHERE epfvv.[Schema] = N'SJob'
			  AND epfvv.Hobt     = N'RibaStages'
			  AND epfvv.Name     = N'IsCustomStage';
	END;
	
	IF (EXISTS(SELECT 1 FROM SJob.RibaStages WHERE Guid = @Guid) AND @IsCustomStage = 0)
		BEGIN

			-- First, disable all fields.
			INSERT INTO @ValidationResult
				(TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT epfvv.Guid,
				   N'P',
				   1,
				   0,
				   0,
				   N''
			FROM SCore.EntityPropertiesForValidationV AS epfvv
			WHERE epfvv.[Schema] = N'SJob'
			  AND epfvv.Hobt     = N'RibaStages'
			  


			-- Next, add message "Editing default RIBA stages is not permitted."
			INSERT INTO @ValidationResult
				(TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT epfvv.Guid,
				   N'P',
				   0,
				   0,
				   1,
				   N'Editing default RIBA stages is not permitted.'
			FROM SCore.EntityPropertiesForValidationV AS epfvv
			WHERE epfvv.[Schema] = N'SJob'
			  AND epfvv.Hobt     = N'RibaStages'
			  AND epfvv.Name     = N'Description';
		END


	RETURN;
END;

GO