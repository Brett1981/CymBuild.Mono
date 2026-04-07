SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[UpsertObjectSharePointPath]
  (
    @ObjectGuid               UNIQUEIDENTIFIER,
    @SharePointSiteIdentifier NVARCHAR(500),
    @FolderPath               NVARCHAR(500)
  )
AS
  BEGIN
    IF (@FolderPath = N'')
      BEGIN
        RETURN;
      END

    DECLARE @SharePointSiteID INT,
            @IsInsert         BIT,
            @Guid             UNIQUEIDENTIFIER = NEWID();

    SELECT
            @SharePointSiteID = ID
    FROM
            SCore.SharepointSites
    WHERE
            (SiteIdentifier = @SharePointSiteIdentifier)
            AND (RowStatus NOT IN (0, 254))

    SELECT
            @Guid = Guid
    FROM
            SCore.ObjectSharePointFolder ospf
    WHERE
            (ospf.ObjectGuid = @ObjectGuid)

	IF (@Guid IS NULL)
	BEGIN 
		SET @Guid = NEWID()
	END

    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SCore',				-- nvarchar(255)
      @ObjectName = N'ObjectSharePointFolder',				-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SCore.ObjectSharePointFolder
              (
                RowStatus,
                Guid,
                ObjectGuid,
                SharepointSiteId,
                FolderPath
              )
        VALUES
                (
                  1, -- RowStatus - tinyint
                  @Guid, -- Guid - uniqueidentifier
                  @ObjectGuid, -- ObjectGuid - uniqueidentifier
                  @SharePointSiteID, -- SharepointSiteId - int
                  @FolderPath  -- FolderPath - nvarchar(500)
                )
      END
    ELSE
      BEGIN
        UPDATE  SCore.ObjectSharePointFolder
        SET     SharepointSiteId = @SharePointSiteID,
                FolderPath = @FolderPath
        WHERE
          (ObjectGuid = @ObjectGuid)
      END
  END
GO