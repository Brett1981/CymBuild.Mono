SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCrm].[ContactPositionsUpsert]
	@Name NVARCHAR(100),
	@Guid UNIQUEIDENTIFIER OUT
AS
	BEGIN
		DECLARE @IsInsert BIT

		EXEC SCore.UpsertDataObject
			@Guid					= @Guid,
			@SchemeName				= N'SCrm',
			@ObjectName				= N'ContactPositions',
			@IncludeDefaultSecurity = 0,
			@IsInsert				= @IsInsert OUT

		IF
			(
			@IsInsert = 1
			)
			BEGIN
				INSERT SCrm.ContactPositions
						(
							RowStatus,
							Guid,
							Name
						)
				VALUES
						(
							1,						-- RowStatus - tinyint
							@Guid,				-- Guid - uniqueidentifier
							@Name
						);
			END;
		ELSE
			BEGIN
				UPDATE  SCrm.ContactPositions
				SET		Name = @Name
				WHERE
					(Guid = @Guid);
			END;
	END;
GO