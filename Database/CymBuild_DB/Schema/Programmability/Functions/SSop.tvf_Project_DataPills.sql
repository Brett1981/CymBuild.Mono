SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO




CREATE FUNCTION [SSop].[tvf_Project_DataPills] 
(
    @Guid UNIQUEIDENTIFIER,
	@IsSubjectToNDA BIT
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
	IF (@IsSubjectToNDA = 1)
      BEGIN
        INSERT @DataPills
              (
                Label,
                Class,
                SortOrder
              )
        VALUES
                (
                  N'NDA',	-- Label - nvarchar(50)
                  N'bg-danger',	-- Class - nvarchar(50)
                  1		-- SortOrder - int
                )
      END


    RETURN
END

GO