/*
    CYB-496: Inactive/Active option for Merge Documents - metadata.

    Adds the "Active" property to the Merge Documents admin screen and carries it
    through the save (EntityQuery [SCore].[MergeDocumentsUpsert]) and read
    (EntityQuery "Merge Documents Read") statements.

    Prerequisites (schema, deployed first):
      - SCore.MergeDocuments.IsActive BIT NOT NULL DEFAULT (1)
      - SCore.MergeDocumentsUpsert with the @IsActive parameter

    Idempotent: every row is keyed by a stable Guid; sibling metadata (HoBT, data
    type, property group, language) is resolved from the existing
    AllowExcelOutputOnly property by Guid, never by environment-specific ID.
    The history trigger picks up the new property on the next
    SCore.RebuildRecordHistoryTriggers run (post-deployment).
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @LabelGuid               UNIQUEIDENTIFIER = '2BDC50CE-D88B-420F-82FD-62308E76D83F',
        @TranslationGuid         UNIQUEIDENTIFIER = '735D245B-EDD9-4426-893C-71304E6293FE',
        @PropertyGuid            UNIQUEIDENTIFIER = '4AFA8E03-6D1F-4AF0-827A-2D3D647D4532',
        @ParameterGuid           UNIQUEIDENTIFIER = 'F3473DE2-18BF-4EC2-B29A-F5DB06130A49',
        @SiblingPropertyGuid     UNIQUEIDENTIFIER = '26E17968-6122-4224-887C-8BD2B8C68E9D', -- AllowExcelOutputOnly
        @SiblingLabelGuid        UNIQUEIDENTIFIER = '06D10959-6809-41C6-BBB2-E071D1FF95EF', -- SCore.MergeDocuments.AllowExcelOutputOnly
        @UpsertQueryGuid         UNIQUEIDENTIFIER = 'D802F6C7-7B1E-4836-BD6D-B8C1F1560CD1', -- [SCore].[MergeDocumentsUpsert]
        @ReadQueryGuid           UNIQUEIDENTIFIER = '65C80205-75BC-4F89-A64B-B2FAFA07FB56', -- Merge Documents Read
        @LabelName               NVARCHAR(250)    = N'SCore.MergeDocuments.IsActive',
        @HobtGuid                UNIQUEIDENTIFIER,
        @DataTypeGuid            UNIQUEIDENTIFIER,
        @GroupGuid               UNIQUEIDENTIFIER,
        @LanguageGuid            UNIQUEIDENTIFIER,
        @EmptyGuid               UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

IF COL_LENGTH(N'SCore.MergeDocuments', N'IsActive') IS NULL
    THROW 60000, N'CYB-496: SCore.MergeDocuments.IsActive is missing. Deploy the schema change first.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID(N'SCore.MergeDocumentsUpsert') AND name = N'@IsActive')
    THROW 60000, N'CYB-496: SCore.MergeDocumentsUpsert has no @IsActive parameter. Deploy the procedure change first.', 1;

SELECT  @HobtGuid     = h.Guid,
        @DataTypeGuid = dt.Guid,
        @GroupGuid    = g.Guid
FROM    SCore.EntityProperties      AS ep
JOIN    SCore.EntityHobts           AS h  ON (h.ID = ep.EntityHoBTID)
JOIN    SCore.EntityDataTypes       AS dt ON (dt.ID = ep.EntityDataTypeID)
JOIN    SCore.EntityPropertyGroups  AS g  ON (g.ID = ep.EntityPropertyGroupID)
WHERE   (ep.Guid = @SiblingPropertyGuid);

SELECT  TOP (1) @LanguageGuid = lng.Guid
FROM    SCore.LanguageLabelTranslations AS t
JOIN    SCore.LanguageLabels            AS ll  ON (ll.ID = t.LanguageLabelID)
JOIN    SCore.Languages                 AS lng ON (lng.ID = t.LanguageID)
WHERE   (ll.Guid = @SiblingLabelGuid)
    AND (t.RowStatus NOT IN (0, 254))
ORDER BY t.ID;

IF (@HobtGuid IS NULL OR @DataTypeGuid IS NULL OR @GroupGuid IS NULL OR @LanguageGuid IS NULL)
    THROW 60000, N'CYB-496: could not resolve the AllowExcelOutputOnly sibling metadata (HoBT/data type/group/language).', 1;

IF NOT EXISTS (SELECT 1 FROM SCore.EntityQueries WHERE Guid = @UpsertQueryGuid)
   OR NOT EXISTS (SELECT 1 FROM SCore.EntityQueries WHERE Guid = @ReadQueryGuid)
    THROW 60000, N'CYB-496: Merge Documents upsert/read EntityQueries not found by Guid.', 1;

IF EXISTS
    (
        SELECT  1
        FROM    SCore.EntityProperties AS ep
        JOIN    SCore.EntityHobts      AS h ON (h.ID = ep.EntityHoBTID)
        WHERE   (h.Guid = @HobtGuid)
            AND (ep.Name = N'IsActive')
            AND (ep.Guid <> @PropertyGuid)
    )
    THROW 60000, N'CYB-496: an IsActive property already exists on SCore.MergeDocuments with a different Guid.', 1;

-- Reuse an existing label of the same name rather than creating a duplicate.
SELECT  @LabelGuid = ll.Guid
FROM    SCore.LanguageLabels AS ll
WHERE   (ll.Name = @LabelName);

BEGIN TRANSACTION;

EXEC SCore.LanguageLabelUpsert
    @Name = @LabelName,
    @Guid = @LabelGuid OUTPUT;

IF NOT EXISTS
    (
        SELECT  1
        FROM    SCore.LanguageLabelTranslations AS t
        JOIN    SCore.LanguageLabels            AS ll  ON (ll.ID = t.LanguageLabelID)
        JOIN    SCore.Languages                 AS lng ON (lng.ID = t.LanguageID)
        WHERE   (ll.Guid = @LabelGuid)
            AND (lng.Guid = @LanguageGuid)
            AND (t.Guid <> @TranslationGuid)
    )
BEGIN
    EXEC SCore.LanguageLabelTranslationUpsert
        @Text              = N'Active',
        @TextPlural        = N'Active',
        @HelpText          = N'Untick to take this document offline. Inactive documents are only offered to Super Users and System Administrators.',
        @LanguageLabelGuid = @LabelGuid,
        @LanguageGuid      = @LanguageGuid,
        @Guid              = @TranslationGuid OUTPUT;
END;

EXEC SCore.EntityPropertyUpsert
    @Name                          = N'IsActive',
    @RowStatus                     = 1,
    @LanguageLabelGuid             = @LabelGuid,
    @EntityHobtGuid                = @HobtGuid,
    @EntityDataTypeGuid            = @DataTypeGuid,
    @IsReadOnly                    = 0,
    @IsImmutable                   = 0,
    @IsUppercase                   = 0,
    @IsHidden                      = 0,
    @IsCompulsory                  = 0,
    @MaxLength                     = 1,
    @Precision                     = 1,
    @Scale                         = 0,
    @DoNotTrackChanges             = 0,
    @EntityPropertyGroupGuid       = @GroupGuid,
    @SortOrder                     = 0,
    @GroupSortOrder                = 0,
    @IsObjectLabel                 = 0,
    @DropDownListDefinitionGuid    = @EmptyGuid,
    @IsParentRelationship          = 0,
    @IsIncludedInformation         = 0,
    @IsLatitude                    = 0,
    @IsLongitude                   = 0,
    @FixDefaultValue               = N'',
    @SqlDefaultValueStatement      = N'SELECT CONVERT(BIT, 1)',
    @AllowBulkChange               = 0,
    @IsVirtual                     = 0,
    @ShowOnMobile                  = 0,
    @IsAlwaysVisibleInGroup        = 0,
    @IsAlwaysVisibleInGroup_Mobile = 0,
    @Guid                          = @PropertyGuid OUTPUT;

EXEC SCore.EntityQueryParameterUpsert
    @Name                     = N'@IsActive',
    @RowStatus                = 1,
    @EntityQueryGuid          = @UpsertQueryGuid,
    @EntityDataTypeGuid       = @DataTypeGuid,
    @MappedEntityPropertyGuid = @PropertyGuid,
    @DefaultValue             = N'',
    @IsInput                  = 1,
    @IsOutput                 = 0,
    @IsReturnColumn           = 0,
    @Guid                     = @ParameterGuid OUTPUT;

UPDATE  SCore.EntityQueries
SET     Statement = N'EXEC [SCore].[MergeDocumentsUpsert]
	@Name = @Name,
	@FilenameTemplate = @FilenameTemplate,
	@EntityTypeGuid = @EntityTypeGuid,
	@SharepointSiteGuid = @SharepointSiteGuid,
	@DocumentId = @DocumentId,
	@LinkedEntityTypeGuid = @LinkedEntityTypeGuid,
	@AllowPDFOutputOnly = @AllowPDFOutputOnly,
	@AllowExcelOutputOnly = @AllowExcelOutputOnly,
	@ProduceOneOutputPerRow = @ProduceOneOutputPerRow,
	@IsActive = @IsActive,
	@Guid = @Guid'
WHERE   (Guid = @UpsertQueryGuid);

UPDATE  SCore.EntityQueries
SET     Statement = N'SELECT
	root_hobt.AllowPDFOutputOnly,
        root_hobt.AllowExcelOutputOnly,
	root_hobt.DocumentId,
	[2F88C3FF-B564-4B42-84BA-8B527EBABED6].Guid AS EntityTypeId,
	root_hobt.FilenameTemplate,
	root_hobt.Guid,
	root_hobt.ID,
	root_hobt.IsActive,
	[FEFEFAA1-DFB4-49FD-BBF6-563AE47DF1C0].Guid AS LinkedEntityTypeId,
	root_hobt.Name,
	root_hobt.ProduceOneOutputPerRow,
	root_hobt.RowStatus,
	root_hobt.RowVersion,
	[6551966B-1294-437E-8E20-E9771C9F2D1E].Guid AS SharepointSiteId
FROM SCore.MergeDocuments AS root_hobt
JOIN SCore.EntityTypes AS [2F88C3FF-B564-4B42-84BA-8B527EBABED6] ON ([2F88C3FF-B564-4B42-84BA-8B527EBABED6].ID = root_hobt.EntityTypeId)
 JOIN SCore.EntityTypes AS [FEFEFAA1-DFB4-49FD-BBF6-563AE47DF1C0] ON ([FEFEFAA1-DFB4-49FD-BBF6-563AE47DF1C0].ID = root_hobt.LinkedEntityTypeId)
 JOIN SCore.SharepointSites AS [6551966B-1294-437E-8E20-E9771C9F2D1E] ON ([6551966B-1294-437E-8E20-E9771C9F2D1E].ID = root_hobt.SharepointSiteId)
'
WHERE   (Guid = @ReadQueryGuid);

COMMIT TRANSACTION;

PRINT N'CYB-496: Merge Documents IsActive metadata applied.';
