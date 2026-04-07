SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO




CREATE FUNCTION [SJob].[tvf_Assets_DataPills] 
(
    @Guid UNIQUEIDENTIFIER,
	@RowStatus TINYINT,
	@Number NVARCHAR(50),
	@AddressLine1 NVARCHAR(50),
	@AddressLine2 NVARCHAR(50),
	@AddressLine3 NVARCHAR(50),
	@Town NVARCHAR(50),
	@CountyGuid UNIQUEIDENTIFIER,
	@PostCode NVARCHAR(50)
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
	DECLARE @CountyName NVARCHAR(50)

    SELECT  @CountyName = Name
    FROM    SCrm.Counties 
    WHERE   ([Guid] = @CountyGuid)

    IF (@RowStatus = 0)
	BEGIN 
		IF (EXISTS
				(
					SELECT	1				
					FROM	SJob.Assets p
					WHERE	(DIFFERENCE(p.Number, @Number) = 4)
					AND	(
							@AddressLine1 IS NULL OR 
							@AddressLine1 != '' AND 
							p.AddressLine1 != '' AND DIFFERENCE(p.AddressLine1, @AddressLine1) = 4
						)
					AND	(
							@AddressLine2 IS NULL OR 
							@AddressLine2 != '' AND 
							p.AddressLine2 != '' AND DIFFERENCE(p.AddressLine2, @AddressLine2) = 4
						)
					AND	(
							@AddressLine3 IS NULL OR 
							@AddressLine3 != '' AND 
							p.AddressLine3 != '' AND DIFFERENCE(p.AddressLine3, @AddressLine3) = 4
						)
					AND	(
							@Town IS NULL OR 
							@Town != '' AND 
							p.Town != '' AND DIFFERENCE(p.Town, @Town) = 4
						)
					AND	(
							@PostCode IS NULL OR 
							@PostCode != '' AND 
							p.Postcode != '' AND DIFFERENCE(p.Postcode, @PostCode) = 4
						)
					AND	(p.RowStatus NOT IN (0, 254))
					AND	(p.id > 0)				
					AND p.Guid <> @Guid		
				)
			)
		BEGIN 
			INSERT @DataPills
				(
					Label, Class, SortOrder
				)
			VALUES(
					  N'A similar property to this already exists!',	-- Label - nvarchar(50)
					  N'bg-warning',	-- Class - nvarchar(50)
					  1		-- SortOrder - int
				  )
		END
	END

	

    RETURN
END

GO