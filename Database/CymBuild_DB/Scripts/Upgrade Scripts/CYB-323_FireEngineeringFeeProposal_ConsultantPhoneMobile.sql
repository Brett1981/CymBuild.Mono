/*
CYB-323 - Fire Engineering Fee Proposal Document Auto-Population
Registers QuotingConsultantPhone / QuotingConsultantMobile as merge fields on
SSop.FireEngineering_Fee_Proposal_MergeInfo (EntityHoBTID 161).

The view itself (Database\CymBuild_DB\Schema\Views\SSop.FireEngineering_Fee_Proposal_MergeInfo.sql)
already exposes these two columns as of this ticket - this script only registers them as
SCore.EntityProperties (+ LanguageLabels/LanguageLabelTranslations) so they appear in the
"Merge Document Fields" grid and are usable as «QuotingConsultantPhone» / «QuotingConsultantMobile»
in the template.

Idempotent: guarded by fixed Guids (not environment-specific numeric IDs), safe to re-run and
safe to promote unchanged to QA / UAT / LIVE.
*/
SET QUOTED_IDENTIFIER, ANSI_NULLS ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

DECLARE @EntityHoBTID INT = 161; -- SSop.FireEngineering_Fee_Proposal_MergeInfo
DECLARE @LanguageID INT = 1; -- British English, matching existing rows for this view

-- ===== QuotingConsultantPhone =====

DECLARE @PhoneLabelGuid UNIQUEIDENTIFIER = '5e3ecec7-e3aa-417e-a0f0-c3d16a5338f9';
DECLARE @PhoneTranslationGuid UNIQUEIDENTIFIER = '11a5d6fe-2500-43a0-abe6-ff20dd0e79c7';
DECLARE @PhonePropertyGuid UNIQUEIDENTIFIER = '9ae4223a-e06c-4a2f-b6f5-112fbf1170e5';

IF NOT EXISTS (SELECT 1 FROM SCore.LanguageLabels WHERE Guid = @PhoneLabelGuid)
    INSERT INTO SCore.LanguageLabels (RowStatus, Guid, Name)
    VALUES (1, @PhoneLabelGuid, N'[SSop].[FireEngineering_Fee_Proposal_MergeInfo].[QuotingConsultantPhone]');

DECLARE @PhoneLabelId INT = (SELECT ID FROM SCore.LanguageLabels WHERE Guid = @PhoneLabelGuid);

IF NOT EXISTS (SELECT 1 FROM SCore.LanguageLabelTranslations WHERE Guid = @PhoneTranslationGuid)
    INSERT INTO SCore.LanguageLabelTranslations (RowStatus, Guid, Text, TextPlural, LanguageLabelID, LanguageID, HelpText)
    VALUES (1, @PhoneTranslationGuid, N'Quoting Consultant Phone', N'Quoting Consultant Phone', @PhoneLabelId, @LanguageID, N'');

IF NOT EXISTS (SELECT 1 FROM SCore.EntityProperties WHERE Guid = @PhonePropertyGuid)
    INSERT INTO SCore.EntityProperties
        ([RowStatus], [Guid], [Name], [LanguageLabelID], [EntityHoBTID], [EntityDataTypeID], [IsReadOnly], [IsImmutable], [IsUppercase], [IsHidden], [IsCompulsory], [MaxLength], [Precision], [Scale], [DoNotTrackChanges], [EntityPropertyGroupID], [SortOrder], [GroupSortOrder], [IsObjectLabel], [DropDownListDefinitionID], [IsParentRelationship], [IsLongitude], [IsLatitude], [IsIncludedInformation], [FixedDefaultValue], [SqlDefaultValueStatement], [AllowBulkChange], [IsVirtual], [ShowOnMobile], [IsAlwaysVisibleInGroup], [IsAlwaysVisibleInGroup_Mobile])
    VALUES
        (1, @PhonePropertyGuid, N'QuotingConsultantPhone', @PhoneLabelId, @EntityHoBTID, 1, 0, 0, 0, 0, 0, 100, 0, 0, 0, -1, 0, 0, 0, -1, 0, 0, 0, 0, N'', N'', 0, 0, 0, 0, 0);

-- ===== QuotingConsultantMobile =====

DECLARE @MobileLabelGuid UNIQUEIDENTIFIER = '3e253b5f-5e0b-4ad8-b3b7-0ff3c8de3f8b';
DECLARE @MobileTranslationGuid UNIQUEIDENTIFIER = 'c4083b46-817c-4427-840c-ab8cf2f26013';
DECLARE @MobilePropertyGuid UNIQUEIDENTIFIER = 'be93312a-ce63-476e-8744-50380d98ced8';

IF NOT EXISTS (SELECT 1 FROM SCore.LanguageLabels WHERE Guid = @MobileLabelGuid)
    INSERT INTO SCore.LanguageLabels (RowStatus, Guid, Name)
    VALUES (1, @MobileLabelGuid, N'[SSop].[FireEngineering_Fee_Proposal_MergeInfo].[QuotingConsultantMobile]');

DECLARE @MobileLabelId INT = (SELECT ID FROM SCore.LanguageLabels WHERE Guid = @MobileLabelGuid);

IF NOT EXISTS (SELECT 1 FROM SCore.LanguageLabelTranslations WHERE Guid = @MobileTranslationGuid)
    INSERT INTO SCore.LanguageLabelTranslations (RowStatus, Guid, Text, TextPlural, LanguageLabelID, LanguageID, HelpText)
    VALUES (1, @MobileTranslationGuid, N'Quoting Consultant Mobile', N'Quoting Consultant Mobile', @MobileLabelId, @LanguageID, N'');

IF NOT EXISTS (SELECT 1 FROM SCore.EntityProperties WHERE Guid = @MobilePropertyGuid)
    INSERT INTO SCore.EntityProperties
        ([RowStatus], [Guid], [Name], [LanguageLabelID], [EntityHoBTID], [EntityDataTypeID], [IsReadOnly], [IsImmutable], [IsUppercase], [IsHidden], [IsCompulsory], [MaxLength], [Precision], [Scale], [DoNotTrackChanges], [EntityPropertyGroupID], [SortOrder], [GroupSortOrder], [IsObjectLabel], [DropDownListDefinitionID], [IsParentRelationship], [IsLongitude], [IsLatitude], [IsIncludedInformation], [FixedDefaultValue], [SqlDefaultValueStatement], [AllowBulkChange], [IsVirtual], [ShowOnMobile], [IsAlwaysVisibleInGroup], [IsAlwaysVisibleInGroup_Mobile])
    VALUES
        (1, @MobilePropertyGuid, N'QuotingConsultantMobile', @MobileLabelId, @EntityHoBTID, 1, 0, 0, 0, 0, 0, 100, 0, 0, 0, -1, 0, 0, 0, -1, 0, 0, 0, 0, N'', N'', 0, 0, 0, 0, 0);

COMMIT TRANSACTION;

-- ===== Verification =====
SELECT Name FROM SCore.EntityProperties WHERE EntityHoBTID = 161 AND Name IN (N'QuotingConsultantPhone', N'QuotingConsultantMobile') AND RowStatus NOT IN (0,254);
