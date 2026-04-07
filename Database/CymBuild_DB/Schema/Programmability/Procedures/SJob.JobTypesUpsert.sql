SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[JobTypesUpsert]
  @Name     NVARCHAR(100),
  @IsActive BIT,
  @UseTimeSheets bit,
  @OrganisationalUnitGuid UNIQUEIDENTIFIER,
  @Guid     UNIQUEIDENTIFIER OUT
AS
  BEGIN

	DECLARE	@OrganisationalUnitId INT

	SELECT	@OrganisationalUnitId = ID 
	FROM	SCore.OrganisationalUnits AS ou
	WHERE	(guid = @OrganisationalUnitGuid)

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SJob',				-- nvarchar(255)
      @ObjectName = N'JobTypes',				-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SJob.JobTypes
              (
                RowStatus,
                Guid,
                Name,
                IsActive,
				UseTimeSheets,
				OrganisationalUnitID
              )
        VALUES
                (
                  1,						-- RowStatus - tinyint
                  @Guid,				-- Guid - uniqueidentifier
                  @Name,
                  @IsActive,
				  @UseTimeSheets,
				  @OrganisationalUnitId
                );
      END;
    ELSE
      BEGIN
        UPDATE  SJob.JobTypes
        SET     Name = @Name,
                IsActive = @IsActive,
				UseTimeSheets = @UseTimeSheets,
				OrganisationalUnitID = @OrganisationalUnitId
        WHERE
          (Guid = @Guid);
      END;
  END;

GO