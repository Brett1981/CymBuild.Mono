SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[UpsertEntityTypeFromSchema]
  (
    @HobtList SCore.TwoStringBitIndexedList READONLY
  )
AS
  BEGIN
    IF NOT EXISTS
      (
          SELECT
                  1
          FROM
                  @HobtList
          WHERE
                  [BitValue1] = 1
      )
      BEGIN
        ;
        THROW 60000, N'You must specify the main HoBT', 1;
      END

    DECLARE @EntityTypeID                          INT,
            @LanguageID                            INT,
            @LanguageLabelID                       INT,
            @EntityTypeName                        NVARCHAR(250),
            @NewGuid                               UNIQUEIDENTIFIER,
            @LanguageLabelsEntityTypeID            INT,
            @LanguageLabelTranslationsEntityTypeID INT,
            @EntityTypesEntityTypeID               INT,
            @EntityHoBTsEntityTypeID               INT,
            @EntityPropertiesEntityTypeID          INT

    SELECT
            @LanguageID = l.ID
    FROM
            [SCore].[Languages] l
    WHERE
            (l.Locale = N'en_GB')

    SELECT
            @EntityTypeName = SCore.[SplitOnUpperCase](StringValue2)
    FROM
            @HobtList
    WHERE
            ([BitValue1] = 1)

    SELECT
            @LanguageLabelsEntityTypeID = ID
    FROM
            SCore.EntityTypes
    WHERE
            (Guid = '36c0faca-c59c-4afd-b45f-6a4752ae23bb')

    SELECT
            @LanguageLabelTranslationsEntityTypeID = ID
    FROM
            SCore.EntityTypes
    WHERE
            (Guid = 'f9048b37-4e10-45cc-9f6f-d7948098afb7')

    SELECT
            @EntityTypesEntityTypeID = ID
    FROM
            SCore.EntityTypes
    WHERE
            (Guid = '215834a4-e08a-4141-b915-58394b2041cf')


    PRINT N'Checking the the Entity Type alread exists'
    SELECT
            @EntityTypeID = eh.EntityTypeId
    FROM
            [SCore].[EntityHobts] eh
    WHERE
            (EXISTS
            (
                SELECT
                        1
                FROM
                        @HobtList hl
                WHERE
                        (hl.BitValue1 = 1)
                        AND (hl.StringValue1 = eh.SchemaName)
                        AND (hl.StringValue2 = eh.ObjectName)
            )
            )


    IF (@@ROWCOUNT < 1)
      BEGIN
        PRINT N'Creating a new entity type record.'

        -- The Entity doesn't exist from create a new language label and entity type record. 
        SET @NewGuid = NEWID()



        INSERT SCore.DataObjects
              (
                Guid,
                RowStatus,
                EntityTypeId
              )
        VALUES
                (
                  @NewGuid,	-- Guid - uniqueidentifier
                  1,	-- RowStatus - tinyint
                  @LanguageLabelsEntityTypeID			-- EntityTypeId - int
                )

        INSERT [SCore].[LanguageLabels]
              (
                [RowStatus],
                [Guid],
                [Name]
              )
        VALUES
                (
                  1,
                  @NewGuid,
                  @EntityTypeName
                )

        SELECT
                @LanguageLabelID = SCOPE_IDENTITY()

        SET @NewGuid = NEWID()

        INSERT SCore.DataObjects
              (
                Guid,
                RowStatus,
                EntityTypeId
              )
        VALUES
                (
                  @NewGuid,	-- Guid - uniqueidentifier
                  1,	-- RowStatus - tinyint
                  @LanguageLabelTranslationsEntityTypeID			-- EntityTypeId - int
                )

        INSERT [SCore].[LanguageLabelTranslations]
              (
                [RowStatus],
                [Guid],
                [LanguageID],
                [LanguageLabelID],
                [Text]
              )
        VALUES
                (
                  1,
                  @NewGuid,
                  @LanguageID,
                  @LanguageLabelID,
                  @EntityTypeName
                )



        SET @NewGuid = NEWID()

        INSERT SCore.DataObjects
              (
                Guid,
                RowStatus,
                EntityTypeId
              )
        VALUES
                (
                  @NewGuid,	-- Guid - uniqueidentifier
                  1,	-- RowStatus - tinyint
                  @EntityTypesEntityTypeID			-- EntityTypeId - int
                )

        INSERT [SCore].[EntityTypes]
              (
                [RowStatus],
                [Guid],
                [Name],
                [LanguageLabelID]
              )
        VALUES
                (
                  1,
                  @NewGuid,
                  @EntityTypeName,
                  @LanguageLabelID
                )

        SELECT
                @EntityTypeID = SCOPE_IDENTITY()
      END

    SELECT
            @EntityHoBTsEntityTypeID = ID
    FROM
            SCore.EntityTypes
    WHERE
            (Guid = 'c66cb5f6-7c65-46bf-aac3-70574ad209b1')

    SELECT
            @EntityPropertiesEntityTypeID = ID
    FROM
            SCore.EntityTypes
    WHERE
            (Guid = '81575be7-247d-45c6-ad63-f7290cd1d759')

    DECLARE @CurrentHoBTName   NVARCHAR(250),
            @CurrentHoBTSchema NVARCHAR(250),
            @CurrentHoBTID     INT,
            @MaxHoBTListID     INT,
            @CurrentHobtListID INT,
            @CurrentHoBTIsMain BIT

    DECLARE @PropertiesToCreateTable TABLE
        (
          ID                             INT              NULL,
          RowStatus                      TINYINT          NULL,
          [Name]                         NVARCHAR(250)    NULL,
          [LanguageLabelID]              INT              NULL,
          [EntityHoBTID]                 INT              NULL,
          [IsReadOnly]                   BIT              NULL,
          [IsHidden]                     BIT              NULL,
          [Precision]                    INT              NULL,
          [Scale]                        INT              NULL,
          [MaxLength]                    INT              NULL,
          [DoNotTrackChanges]            BIT              NULL,
          [EntityDataTypeID]             INT              NOT NULL DEFAULT (-1),
          [EntityPropertyID]             INT              NOT NULL DEFAULT (-1),
          [EntityPropertyGuid]           UNIQUEIDENTIFIER NULL,
          [LanguageLabelGuid]            UNIQUEIDENTIFIER NULL,
          [LanguageLabelTranslationGuid] UNIQUEIDENTIFIER NULL
        )

    DECLARE @NewLabels TABLE
        (
          ID           INT              NULL,
          [ColumnName] NVARCHAR(250)    NULL,
          [Name]       NVARCHAR(250)    NULL,
          [Guid]       UNIQUEIDENTIFIER NULL
        )

    SELECT
            @MaxHoBTListID     = MAX(h.ID),
            @CurrentHobtListID = -1
    FROM
            @HobtList h

    WHILE (@CurrentHobtListID < @MaxHoBTListID)
    BEGIN
      SELECT TOP (1)
              @CurrentHobtListID = h.ID,
              @CurrentHoBTSchema = h.StringValue1,
              @CurrentHoBTName   = h.StringValue2,
              @CurrentHoBTIsMain = h.[BitValue1]
      FROM
              @HobtList h
      WHERE
              (h.ID > @CurrentHobtListID)
      ORDER BY
              h.ID

      PRINT N'Processing HoBT ' + @CurrentHoBTName

      SELECT
              @CurrentHoBTID = eh.ID
      FROM
              SCore.EntityHobts eh
      WHERE
              (SchemaName = @CurrentHoBTSchema)
              AND (ObjectName = @CurrentHoBTName)

      IF (@@ROWCOUNT < 1)
        BEGIN
          PRINT N'Creating new HoBT record.'
          SET @NewGuid = NEWID()

          INSERT SCore.DataObjects
                (
                  Guid,
                  RowStatus,
                  EntityTypeId
                )
          VALUES
                  (
                    @NewGuid,	-- Guid - uniqueidentifier
                    1,	-- RowStatus - tinyint
                    @EntityHoBTsEntityTypeID			-- EntityTypeId - int
                  )

          INSERT [SCore].[EntityHobts]
                (
                  [RowStatus],
                  [Guid],
                  [SchemaName],
                  [ObjectName],
                  [ObjectType],
                  [EntityTypeId],
                  [IsMainHoBT]
                )
              SELECT
                      1,
                      @NewGuid,
                      SCHEMA_NAME(t.schema_id),
                      t.Name,
                      t.[Type],
                      @EntityTypeID,
                      @CurrentHoBTIsMain
              FROM
                      sys.objects t
              WHERE
                      (SCHEMA_NAME(t.schema_id) = @CurrentHoBTSchema)
                      AND (t.Name = @CurrentHoBTName)
                      AND (t.Type IN (N'V', N'U'))

          SELECT
                  @CurrentHoBTID = SCOPE_IDENTITY()
        END

      DELETE FROM
      @PropertiesToCreateTable

      DELETE FROM
      @NewLabels

      /*
  			Build a collection of all the properties on the specified HoBTS
  		*/
      PRINT N'Building property collection.'

      INSERT @PropertiesToCreateTable
            (
              ID,
              RowStatus,
              [Name],
              [LanguageLabelID],
              [EntityHoBTID],
              [IsReadOnly],
              [IsHidden],
              [Precision],
              [Scale],
              [MaxLength],
              [DoNotTrackChanges],
              [EntityDataTypeID],
              [EntityPropertyID],
              EntityPropertyGuid,
              LanguageLabelGuid,
              LanguageLabelTranslationGuid
            )
          SELECT
                  ep.ID,
                  1,
                  c.Name,
                  ISNULL(ep.LanguageLabelID, -1),
                  @CurrentHoBTID,
                  CASE
                          WHEN c.Name IN (N'ID', N'Guid', N'RowVersion', N'RowVesion') THEN
                            1
                          ELSE
                          0
                  END,
                  CASE
                          WHEN c.Name IN (N'Guid', N'RowVersion', N'ID', N'RowStatus') THEN
                            1
                          ELSE
                          0
                  END,
                  c.Precision,
                  c.Scale,
                  c.max_length,
                  CASE
                          WHEN c.Name IN (N'ID', N'Guid', N'RowVersion') THEN
                            1
                          ELSE
                          0
                  END,
                  ISNULL(calc_type.ID, -1),
                  ISNULL(ep.ID, -1),
                  ISNULL(ep.Guid, NEWID()),
                  ISNULL(epll.Guid, NEWID()),
                  ISNULL(epllt.Guid, NEWID())
          FROM
                  sys.columns c
          JOIN
                  sys.objects t ON (c.object_id = t.object_id)
          JOIN
                  sys.types ty ON (ty.user_type_id = c.user_type_id)
          LEFT JOIN
                  [SCore].[EntityProperties] ep ON (ep.Name = c.Name)
                      AND (ep.EntityHoBTID = @CurrentHoBTID)
          LEFT JOIN
                  SCore.LanguageLabels epll ON (epll.ID = ep.LanguageLabelID)
          LEFT JOIN
                  SCore.LanguageLabelTranslations epllt ON (epllt.LanguageLabelID = epll.ID)
                      AND (epllt.LanguageID = @LanguageID)
          OUTER APPLY
                  (
                      SELECT
                              edt.ID
                      FROM
                              SCore.EntityDataTypes edt
                      WHERE
                              (
                                      (       (c.max_length = -1)
                                              OR (c.max_length > 800))
                                      AND (ty.Name = 'nvarchar')
                                      AND (edt.Name = N'nvarchar(max)')
                              )
                              OR (
                                      (
                                              (       (       (c.max_length <> -1)
                                                              AND (c.max_length <= 800))
                                                      AND (ty.Name = 'nvarchar'))
                                              OR (ty.Name <> 'nvarchar')
                                      )
                                      AND (edt.Name = ty.Name)
                              )
                              OR (
                                      (ty.Name = 'decimal')
                                      AND (edt.Name = N'double')
                              )
                  ) AS calc_type
          WHERE
                  (SCHEMA_NAME(t.schema_id) = @CurrentHoBTSchema)
                  AND (t.Name = @CurrentHoBTName)
                  AND (t.Type IN (N'V', N'U'))

      /* Add the needed data object records */
      PRINT N'Creating the needed Data Object records.'

      INSERT SCore.DataObjects
            (
              Guid,
              RowStatus,
              EntityTypeId
            )
          SELECT
                  LanguageLabelGuid,
                  1,
                  @LanguageLabelsEntityTypeID
          FROM
                  @PropertiesToCreateTable
          WHERE
                  (NOT EXISTS
                  (
                      SELECT
                              1
                      FROM
                              SCore.DataObjects do1
                      WHERE
                              (do1.Guid = LanguageLabelGuid)
                  )
                  )

      INSERT SCore.DataObjects
            (
              Guid,
              RowStatus,
              EntityTypeId
            )
          SELECT
                  LanguageLabelTranslationGuid,
                  1,
                  @LanguageLabelTranslationsEntityTypeID
          FROM
                  @PropertiesToCreateTable
          WHERE
                  (NOT EXISTS
                  (
                      SELECT
                              1
                      FROM
                              SCore.DataObjects do1
                      WHERE
                              (do1.Guid = LanguageLabelTranslationGuid)
                  )
                  )

      INSERT SCore.DataObjects
            (
              Guid,
              RowStatus,
              EntityTypeId
            )
          SELECT
                  EntityPropertyGuid,
                  1,
                  @EntityPropertiesEntityTypeID
          FROM
                  @PropertiesToCreateTable
          WHERE
                  (NOT EXISTS
                  (
                      SELECT
                              1
                      FROM
                              SCore.DataObjects do1
                      WHERE
                              (do1.Guid = EntityPropertyGuid)
                  )
                  )

      /*
  			Create the language labels
  		*/
      PRINT N'Creating the language labels for the properties.'

      MERGE [SCore].[LanguageLabels] tgt
        USING
        (
            SELECT
                    N'[' + @CurrentHoBTSchema + N'].[' + @CurrentHoBTName + N'].[' + [Name] + N']' AS ColumnName,
                    [Name],
                    LanguageLabelGuid
            FROM
                    @PropertiesToCreateTable
            WHERE
                    (LanguageLabelID = -1)
        ) AS src (ColumnName, [Name], [LanguageLabelGuid])
      ON (tgt.Name = src.ColumnName)
      WHEN NOT MATCHED
        THEN INSERT
            (
              [RowStatus],
              [Guid],
              [Name]
            )
          VALUES
            (
              1, LanguageLabelGuid, src.ColumnName
            )
      OUTPUT
        INSERTED.ID,
        src.ColumnName,
        src.[Name],
        src.LanguageLabelGuid INTO @NewLabels (ID, ColumnName, [Name], [Guid]);

      /*
  			Create / update the language translations
  		*/
      PRINT N'Creating the language label translations.'

      INSERT INTO [SCore].[LanguageLabelTranslations]
                (
                  RowStatus,
                  Guid,
                  LanguageID,
                  LanguageLabelID,
                  [Text]
                )
          SELECT
                  1,
                  ptct.LanguageLabelTranslationGuid,
                  @LanguageID,
                  nl.ID,
                  SCore.SplitOnUpperCase(nl.Name)
          FROM
                  @NewLabels nl
          JOIN
                  @PropertiesToCreateTable ptct ON (ptct.LanguageLabelGuid = nl.Guid)


      UPDATE  t
      SET     LanguageLabelID = ll.ID
      FROM
              @PropertiesToCreateTable t
      JOIN
              [SCore].[LanguageLabels] ll ON (ll.Guid = t.LanguageLabelGuid)

      /*
  			Add the properties that should be flagged for deletion. 
  		*/
      PRINT N'Calculate any properties to be deleted.'

      INSERT @PropertiesToCreateTable
            (
              ID,
              Name,
              LanguageLabelID,
              EntityHoBTID,
              IsReadOnly,
              IsHidden,
              Precision,
              Scale,
              MaxLength,
              DoNotTrackChanges,
              RowStatus
            )
          SELECT
                  ep.ID,
                  ep.Name,
                  ep.LanguageLabelID,
                  ep.EntityHoBTID,
                  ep.IsReadOnly,
                  ep.IsHidden,
                  ep.Precision,
                  ep.Scale,
                  ep.MaxLength,
                  ep.DoNotTrackChanges,
                  254
          FROM
                  SCore.EntityPropertiesV ep
          JOIN
                  SCore.EntityHobts h ON (h.ID = ep.EntityHoBTID)
          JOIN
                  @HobtList hl ON (hl.StringValue1 = h.SchemaName)
                      AND (hl.StringValue2 = h.ObjectName)
          WHERE
                  (NOT EXISTS
                  (
                      SELECT
                              1
                      FROM
                              sys.columns c
                      JOIN
                              sys.objects t ON (c.object_id = t.object_id)
                      WHERE
                              (c.Name = ep.Name)
                              AND (SCHEMA_NAME(t.schema_id) = hl.StringValue1)
                              AND (t.Name = hl.StringValue2)
                              AND (t.Type IN (N'V', N'U'))
                  )
                  )

      /*
  			Create / update the Entity Properties
  		*/
      PRINT N'Upserting Entity Properties'

      MERGE [SCore].[EntityProperties] tgt
        USING
        (
            SELECT
                    ID,
                    EntityHoBTID,
                    [Name],
                    [LanguageLabelID],
                    [IsReadOnly],
                    [IsHidden],
                    [MaxLength],
                    [Precision],
                    [Scale],
                    [DoNotTrackChanges],
                    RowStatus,
                    EntityDataTypeID,
                    EntityPropertyGuid
            FROM
                    @PropertiesToCreateTable
        ) AS src
      ON (tgt.ID = src.ID)
        AND (tgt.EntityHoBTID = src.EntityHoBTID)
        AND (tgt.Name = src.Name)
      WHEN NOT MATCHED
        THEN INSERT
            (
              [RowStatus],
              [Guid],
              [Name],
              [EntityHoBTID],
              [LanguageLabelID],
              [IsReadOnly],
              [IsHidden],
              [MaxLength],
              [Precision],
              [Scale],
              [DoNotTrackChanges],
              EntityDataTypeID
            )
          VALUES
            (
              1, src.EntityPropertyGuid, src.Name, src.EntityHoBTID, src.LanguageLabelID, src.[IsReadOnly], src.[IsHidden], src.[MaxLength], src.[Precision], src.[Scale], src.[DoNotTrackChanges], src.EntityDataTypeID
            )
      WHEN MATCHED
        THEN UPDATE SET
            RowStatus = src.RowStatus,
            Scale = src.Scale,
            tgt.Precision = src.Precision,
            tgt.EntityDataTypeID = src.EntityDataTypeID;
    END
  END
GO