SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[ProjectsUpsert] 
								@ExternalReference NVARCHAR(50),
								@ProjectDescription NVARCHAR(MAX),
								@ProjectProjectedStartDate date,
								@ProjectProjectedEndDate date,
								@ProjectCompleted DATE,
								@IsSubjectToNDA BIT,
								@Guid UNIQUEIDENTIFIER
AS
BEGIN
	DECLARE	@IsInsert BIT = 0;

	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SSop',				-- nvarchar(255)
							@ObjectName = N'Projects',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0,
							@IsInsert = @IsInsert OUTPUT	-- bit

	IF @IsInsert = 1
	BEGIN
		INSERT	SSop.Projects
			 (RowStatus,
			  Guid,
			  Number,
			  ExternalReference,
			  ProjectDescription,
			  ProjectProjectsStartDate,
			  ProjectProjectedEndDate,
			  ProjectCompleted,
			  IsSubjectToNDA)
		VALUES
			 (
				 0,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 0,	-- Number - int
				 @ExternalReference,	-- ExternalReference - nvarchar(50)
				 @ProjectDescription,	-- ProjectDescription - nvarchar(max)
				 @ProjectProjectedStartDate,		-- ProjectProjectsStartDate - date
				 @ProjectProjectedEndDate,		-- ProjectProjectedEndDate - date
				 @ProjectCompleted,		-- ProjectCompleted - date
				 @IsSubjectToNDA
			 )
	END;
	ELSE
	BEGIN
		UPDATE	SSop.Projects
		SET		ExternalReference = @ExternalReference,
				ProjectDescription = @ProjectDescription,
				ProjectProjectsStartDate = @ProjectProjectedStartDate,
				ProjectProjectedEndDate = @ProjectProjectedEndDate,
				ProjectCompleted = @ProjectCompleted,
				IsSubjectToNDA = @IsSubjectToNDA
		WHERE	(Guid = @Guid)
	END;

	IF (@IsInsert = 1)
	BEGIN
		DECLARE	@ProjectNumber int

		SELECT	@ProjectNumber = NEXT VALUE FOR SSop.ProjectNumber;

		UPDATE	SSop.Projects
		SET		Number = @ProjectNumber,
				RowStatus = 1
		WHERE	(Guid = @Guid);
	END;
END;

GO