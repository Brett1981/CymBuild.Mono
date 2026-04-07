SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE FUNCTION [SCrm].[AccountMergeBatch_DataPills] 
(
    @Guid UNIQUEIDENTIFIER,
	@CheckedByUserGuid UNIQUEIDENTIFIER,
	@IsComplete BIT
)
RETURNS @DataPills TABLE 
(
    [ID] [INT] IDENTITY(1,1) NOT NULL,
	[Label] NVARCHAR(50) NOT NULL,
	[Class] NVARCHAR(50) NOT NULL, 
	[SortOrder] INT NOT NULL
)
AS
BEGIN

	IF (@IsComplete = 1)
	BEGIN 
		RETURN 
	END

    IF (@CheckedByUserGuid <> '00000000-0000-0000-0000-000000000000')
	BEGIN 
		INSERT @DataPills
			(
				Label, Class, SortOrder
			)
		VALUES(
				  N'The Accounts will be merged when you click save.',	-- Label - nvarchar(50)
				  N'bg-warning',	-- Class - nvarchar(50)
				  1		-- SortOrder - int
			  ),
			  (
				  N'This cannot be undone.',	-- Label - nvarchar(50)
				  N'bg-warning',	-- Class - nvarchar(50)
				  1		-- SortOrder - int
			  )
	END


    RETURN
END

GO