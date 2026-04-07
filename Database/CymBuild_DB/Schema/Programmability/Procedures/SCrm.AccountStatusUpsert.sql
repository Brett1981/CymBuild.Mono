SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SCrm].[AccountStatusUpsert] 
								@Name NVARCHAR(100),
								@IsHold BIT,
								@Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	IF NOT EXISTS
	 (
		 SELECT 1
		 FROM	SCrm.AccountStatus
		 WHERE	(Guid = @Guid)
	 )
	BEGIN
		INSERT	SCrm.AccountStatus
			 (RowStatus,
			  Guid,
			  Name,
			  IsHold)
		VALUES
			 (
				 1,						-- RowStatus - tinyint
				 @Guid,				-- Guid - uniqueidentifier
				 @Name,
				 @IsHold
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SCrm.AccountStatus
		SET		Name = @Name,
				IsHold = @IsHold
		WHERE	(Guid = @Guid);
	END;
END;

GO