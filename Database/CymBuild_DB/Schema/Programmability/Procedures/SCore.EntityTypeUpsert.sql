SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[EntityTypeUpsert]
  (
    @Name                 NVARCHAR(250),
    @RowStatus            TINYINT,
    @IsReadOnlyOffline    BIT,
    @IsRequiredSystemData BIT,
    @HasDocuments         BIT,
    @LanguageLabelGuid    UNIQUEIDENTIFIER,
    @DoNotTrackChanges    BIT,
    @IconGuid             UNIQUEIDENTIFIER,
    @IsRootEntity         BIT,
    @DetailPageUrl        NVARCHAR(250),
	@IsMetaData			  BIT,
    @Guid                 UNIQUEIDENTIFIER OUT
  )
AS
  BEGIN
    SET NOCOUNT ON

    DECLARE @ProcessMessages SCore.ProcessMessages,
            @LanguageLabelID INT,
            @IconId          INT

    -- If the name isn't set, then create a validation message. 
    IF (ISNULL(@Name,
      N''
      ) = N''
      )
      BEGIN
        INSERT @ProcessMessages
              (
                Type,
                Message
              )
        VALUES
                (
                  'V',
                  N'The name for the entity type cannot be blank.'
                );
      END;

    -- If the language label isn't set, create one based on the name. 
    SELECT
            @LanguageLabelID = ID
    FROM
            SCore.LanguageLabels
    WHERE
            (Guid = @LanguageLabelGuid);

    IF (@LanguageLabelID = -1)
      BEGIN
        EXECUTE SCore.LanguageLabelUpsert
          @Name = @Name,
          @Guid = @LanguageLabelGuid OUT;

        SELECT
                @LanguageLabelID = ID
        FROM
                SCore.LanguageLabels
        WHERE
                (Guid = @LanguageLabelGuid);
      END;

    SELECT
            @IconId = ID
    FROM
            SUserInterface.Icons i
    WHERE
            (Guid = @IconGuid)

    DECLARE @IsInsert BIT = 0;
    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SCore',				-- nvarchar(255)
      @ObjectName = N'EntityTypes',				-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SCore.EntityTypes
              (
                Guid,
                Name,
                RowStatus,
                IsReadOnlyOffline,
                IsRequiredSystemData,
                HasDocuments,
                LanguageLabelID,
                DoNotTrackChanges,
                IconId,
                IsRootEntity,
                DetailPageUrl,
				IsMetaData
              )
        VALUES
                (
                  @Guid,
                  @Name,
                  @RowStatus,
                  @IsReadOnlyOffline,
                  @IsRequiredSystemData,
                  @HasDocuments,
                  @LanguageLabelID,
                  @DoNotTrackChanges,
                  @IconId,
                  @IsRootEntity,
                  @DetailPageUrl,
				  @IsMetaData
                );
      END;
    ELSE
      BEGIN
        UPDATE  SCore.EntityTypes
        SET     Name = @Name,
                RowStatus = @RowStatus,
                IsReadOnlyOffline = @IsReadOnlyOffline,
                IsRequiredSystemData = @IsRequiredSystemData,
                HasDocuments = @HasDocuments,
                LanguageLabelID = @LanguageLabelID,
                DoNotTrackChanges = @DoNotTrackChanges,
                IconId = @IconId,
                IsRootEntity = @IsRootEntity,
                DetailPageUrl = @DetailPageUrl,
				IsMetaData = @IsMetaData
        WHERE
          (Guid = @Guid);
      END;


  END;
GO