
BEGIN TRAN 

EXEC sys.sp_set_session_context @key = 'S_disable_triggers',
								@value = 1;

DECLARE	@NextProjectNumber INT = NEXT VALUE FOR SSop.ProjectNumber

DECLARE	@Jobs TABLE	(
	id INT IDENTITY(1,1) NOT NULL,
	JobID INT NOT NULL, 
	ExternalReference NVARCHAR(50) NOT NULL DEFAULT '',
	StartDate DATE NULL, 
	CompletedDate DATE NULL, 
	NDA BIT NOT NULL DEFAULT((0)),
	NewProjectGuid UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID()
)

INSERT	@Jobs
	 (JobID, NDA, ExternalReference, StartDate, CompletedDate)
SELECT	j.ID, 
		j.IsSubjectToNDA, 
		j.ExternalReference, 
		j.CreatedOn, 
		ISNULL(j.JobCompleted, j.JobCancelled)
FROM	SJob.Jobs AS j
WHERE	(j.ProjectId < 0)

DECLARE	@GuidList SCore.GuidUniqueList

INSERT	@GuidList
	 (GuidValue)
SELECT	NewProjectGuid 
FROM	@Jobs AS j

DECLARE @IsInsert BIT;
EXEC SCore.DataObjectBulkUpsert @GuidList = @GuidList,				-- GuidUniqueList
								@SchemeName = N'SSop',				-- nvarchar(255)
								@ObjectName = N'Projects',				-- nvarchar(255)
								@IncludeDefaultSecurity = False, -- bit
								@IsInsert = @IsInsert OUTPUT	-- bit

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
SELECT
		 1,	-- RowStatus - tinyint
		 js.NewProjectGuid,	-- Guid - uniqueidentifier
		 @NextProjectNumber + js.id,	-- Number - int
		 js.ExternalReference,	-- ExternalReference - nvarchar(50)
		 N'',	-- ProjectDescription - nvarchar(max)
		 js.StartDate,		-- ProjectProjectsStartDate - date
		 js.CompletedDate,		-- ProjectProjectedEndDate - date
		 js.CompletedDate,		-- ProjectCompleted - date
		 js.NDA	-- IsSubjectToNDA - bit
FROM	@Jobs AS js

SELECT @NextProjectNumber = MAX(Number) + 1 FROM SSop.Projects AS p

DECLARE	@stmt NVARCHAR(4000) = N'ALTER SEQUENCE SSop.ProjectNumber RESTART WITH ' + CONVERT(NVARCHAR(4000), @NextProjectNumber)

EXEC sp_executesql @stmt

-- Update the Job with the new project number 
UPDATE t
SET		t.ProjectId = p.ID
FROM	SJob.Jobs AS t
JOIN	@Jobs AS j ON (t.ID = j.JobID)
JOIN	SSop.Projects AS p ON (p.Guid = j.NewProjectGuid)
WHERE	(t.ProjectId < 0)

-- Update the Quotes related to the job with the new project number. 
UPDATE	q
SET		q.ProjectId = j.ProjectID
FROM	SSop.Quotes AS q 
JOIN	SSop.QuoteSections AS qs ON (qs.QuoteId = q.ID)
JOIN	SSop.QuoteItems AS qi ON (qi.QuoteSectionId = qs.ID)
JOIN	SJob.Jobs AS j ON (j.ID = qi.CreatedJobId)
WHERE	(q.ProjectId < 0)

-- Create Projects for Quotes that don't have a job. 
DECLARE	@QuotesWithoutProjects TABLE	(
	id INT IDENTITY(1,1) NOT NULL,
	QuoteID INT NOT NULL, 
	ExternalReference NVARCHAR(50) NOT NULL DEFAULT '',
	NDA BIT NOT NULL DEFAULT((0)),
	NewProjectGuid UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID()
)

INSERT	@QuotesWithoutProjects
	 (QuoteID, ExternalReference, NDA, NewProjectGuid)
SELECT	q.ID, q.ExternalReference, q.IsSubjectToNDA,  NEWID()
FROM	SSop.Quotes AS q 
WHERE	(q.ProjectId < 0)
	AND	(q.ID > 0)

DELETE FROM @GuidList

INSERT	@GuidList
	 (GuidValue)
SELECT	qwp.NewProjectGuid 
FROM	@QuotesWithoutProjects AS qwp

EXEC SCore.DataObjectBulkUpsert @GuidList = @GuidList,				-- GuidUniqueList
								@SchemeName = N'SSop',				-- nvarchar(255)
								@ObjectName = N'Projects',				-- nvarchar(255)
								@IncludeDefaultSecurity = False, -- bit
								@IsInsert = @IsInsert OUTPUT	-- bit

SELECT @NextProjectNumber = NEXT VALUE FOR SSop.ProjectNumber

INSERT	SSop.Projects
	 (RowStatus,
	  Guid,
	  Number,
	  ExternalReference,
	  ProjectDescription,
	  IsSubjectToNDA)
SELECT
		 1,	-- RowStatus - tinyint
		 qwp.NewProjectGuid,	-- Guid - uniqueidentifier
		 @NextProjectNumber + qwp.id,	-- Number - int
		 qwp.ExternalReference,	-- ExternalReference - nvarchar(50)
		 N'',	-- ProjectDescription - nvarchar(max)
		 qwp.NDA	-- IsSubjectToNDA - bit
FROM	@QuotesWithoutProjects AS qwp

SELECT @NextProjectNumber = MAX(Number) + 1 FROM SSop.Projects AS p

SET	@stmt = N'ALTER SEQUENCE SSop.ProjectNumber RESTART WITH ' + CONVERT(NVARCHAR(4000), @NextProjectNumber)

EXEC sp_executesql @stmt

UPDATE	q
SET		q.ProjectId = p.ID
FROM	SSop.Quotes AS q
JOIN	@QuotesWithoutProjects AS qwp ON (qwp.QuoteID = q.ID)
JOIN	SSop.Projects AS p ON (p.Guid = qwp.NewProjectGuid)


-- Update enquiries to match the project on the quote. 
UPDATE	e
SET		e.ProjectId = q.ProjectId
FROM	SSop.Enquiries AS e 
JOIN	SSop.EnquiryServices AS es ON (es.EnquiryId = e.ID)
JOIN	SSop.Quotes q ON (q.ID = es.QuoteId)
WHERE	(e.ProjectId <> q.ProjectId)
	AND	(e.ProjectId < 0)


-- Create Projects for Enquiries that don't have a job. 
DECLARE	@EnquiriesWithoutProjects TABLE	(
	id INT IDENTITY(1,1) NOT NULL,
	EnquiryID INT NOT NULL, 
	ExternalReference NVARCHAR(50) NOT NULL DEFAULT '',
	NDA BIT NOT NULL DEFAULT((0)),
	NewProjectGuid UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID()
)

INSERT	@EnquiriesWithoutProjects
	 (EnquiryID, ExternalReference, NDA, NewProjectGuid)
SELECT	e.ID, e.ExternalReference, e.IsSubjectToNDA,  NEWID()
FROM	SSop.Enquiries AS e 
WHERE	(e.ProjectId < 0)
	AND	(e.ID > 0)

DELETE FROM @GuidList

INSERT	@GuidList
	 (GuidValue)
SELECT	qwp.NewProjectGuid 
FROM	@QuotesWithoutProjects AS qwp

EXEC SCore.DataObjectBulkUpsert @GuidList = @GuidList,				-- GuidUniqueList
								@SchemeName = N'SSop',				-- nvarchar(255)
								@ObjectName = N'Projects',				-- nvarchar(255)
								@IncludeDefaultSecurity = False, -- bit
								@IsInsert = @IsInsert OUTPUT	-- bit

SELECT @NextProjectNumber = NEXT VALUE FOR SSop.ProjectNumber

INSERT	SSop.Projects
	 (RowStatus,
	  Guid,
	  Number,
	  ExternalReference,
	  ProjectDescription,
	  IsSubjectToNDA)
SELECT
		 1,	-- RowStatus - tinyint
		 qwp.NewProjectGuid,	-- Guid - uniqueidentifier
		 @NextProjectNumber + qwp.id,	-- Number - int
		 qwp.ExternalReference,	-- ExternalReference - nvarchar(50)
		 N'',	-- ProjectDescription - nvarchar(max)
		 qwp.NDA	-- IsSubjectToNDA - bit
FROM	@EnquiriesWithoutProjects AS qwp

SELECT @NextProjectNumber = MAX(Number) + 1 FROM SSop.Projects AS p

SET	@stmt = N'ALTER SEQUENCE SSop.ProjectNumber RESTART WITH ' + CONVERT(NVARCHAR(4000), @NextProjectNumber)

EXEC sp_executesql @stmt

UPDATE	e
SET		e.ProjectId = p.ID
FROM	SSop.Enquiries AS e
JOIN	@EnquiriesWithoutProjects AS ewp ON (ewp.Enquiryid = e.ID)
JOIN	SSop.Projects AS p ON (p.Guid = ewp.NewProjectGuid)


-- Update the project on project directory records to match that of the job. 
UPDATE	pd
SET		pd.ProjectID = j.ProjectId
FROM	SJob.ProjectDirectory AS pd
JOIN	SJob.Jobs AS j ON (j.ID = pd.JobID)
WHERE	(pd.ProjectID < 0)

-- Create the project key data records from the ones on Jobs, Quotes and Enquiries. 
INSERT	SSop.ProjectKeyDates
	 (Guid, RowStatus, ProjectID, Detail, DateTime)
SELECT	jkd.Guid, jkd.RowStatus, j.ProjectId, jkd.Detail, jkd.DateTime
FROM	SJob.JobKeyDates AS jkd
JOIN	SJob.Jobs AS j ON (j.ID = jkd.JobID)
UNION ALL
SELECT	qkd.Guid, qkd.RowStatus, q.ProjectId, qkd.Detail, qkd.DateTime
FROM	SSop.QuoteKeyDates AS qkd
JOIN	SSop.Quotes AS q ON (q.ID = qkd.QuoteID)
UNION ALL
SELECT	ekd.Guid, ekd.RowStatus, e.ProjectId, ekd.Details, ekd.DateTime
FROM	SSop.EnquiryKeyDates AS ekd
JOIN	SSop.Enquiries AS e ON (e.ID = ekd.EnquiryID)

UPDATE	do
SET		do.EntityTypeId = NewEt.ID
FROM	SCore.DataObjects AS do
CROSS APPLY (
	SELECT	et.ID
	FROM	SCore.EntityTypes AS et
	WHERE	(et.Name = N'Project Key Dates')
) AS NewEt
WHERE	(EXISTS
	(
		SELECT	1
		FROM	SCore.EntityTypes AS et2
		WHERE	et2.Name IN (N'Quote Key Dates', N'Job Key Dates', N'Enquiry Key Dates')
			AND	(do.EntityTypeId = et2.ID)
	)		
		)

UPDATE	q
SET		EnquiryServiceID = es.ID
FROM	SSop.Quotes AS q 
JOIN	SSop.EnquiryServices AS es ON (es.QuoteId = q.ID)
WHERE	(q.EnquiryServiceID < 0)

UPDATE	p
SET		p.ProjectDescription = N'Auto Generated Project for Quote ' + CONVERT(NVARCHAR(MAX), q.Number) + N' - ' + q.Overview
FROM	SSop.Projects AS p
JOIN	SSop.Quotes AS q ON (q.ProjectId = p.ID)
WHERE	(p.ProjectDescription = N'')
	AND	(p.ID > 0)


UPDATE	SCore.Groups 
SET		DirectoryId = 'b5b513b6-17e4-4adf-a11b-37ef30d60e8b'
WHERE	id = -1



DECLARE	@MergeDocumentGuid UNIQUEIDENTIFIER = '50A8B80A-2227-4DA4-B1E3-115949D1DFAA'
EXEC SCore.MergeDocumentsUpsert @Name = N'Discipline Proposal',					-- nvarchar(250)
								@FilenameTemplate = N'Discilpline Proposal',		-- nvarchar(250)
								@EntityTypeGuid = '00000000-0000-0000-0000-000000000000',			-- uniqueidentifier
								@SharepointSiteGuid = '9A136463-0885-4480-B425-6F034A6930AE',		-- uniqueidentifier
								@DocumentId = N'01OGW3DZXCT5VGVOMVAVHILRKAO3HCJAIE',				-- nvarchar(500)
								@LinkedEntityTypeGuid = '203E2253-409B-4758-A06C-D6A0571E7AC0',	-- uniqueidentifier
								@AllowPDFOutputOnly = 0,		-- bit
								@ProduceOneOutputPerRow = 0, -- bit,
								@AllowExcelOutputOnly = 0,
								@Guid = @MergeDocumentGuid OUTPUT			-- uniqueidentifier

DECLARE @MergeDocumentItemGuid UNIQUEIDENTIFIER = 'D0A72DA1-94E7-49E9-B872-93734F7D7942';
EXEC SCore.MergeDocumentItemsUpsert @MergeDocumentGuid = @MergeDocumentGuid,			-- uniqueidentifier
									@MergeDocumentItemTypeGuid = '9F69CA42-52C1-44BD-A0DE-E9601664B5DC',	-- uniqueidentifier
									@BookmarkName = N'ItemTable',				-- nvarchar(50)
									@EntityTypeGuid = '9222CCFB-0DF9-4E55-A82F-58D9D5E24A88',				-- uniqueidentifier
									@SubFolderPath = N'',				-- nvarchar(200)
									@ImageColumns = 0,					-- int
									@Guid = @MergeDocumentItemGuid OUTPUT				-- uniqueidentifier

DECLARE	@TermsDocumentGuid UNIQUEIDENTIFIER = '576F2D2A-C04E-47FD-A9C4-624F8A56F634'
EXEC SCore.MergeDocumentsUpsert @Name = N'Socotec Terms',					-- nvarchar(250)
								@FilenameTemplate = N'Socotec Terms',		-- nvarchar(250)
								@EntityTypeGuid = '00000000-0000-0000-0000-000000000000',			-- uniqueidentifier
								@SharepointSiteGuid = '93B83DAC-1F4A-4898-8B9F-15F2EBFACD95',		-- uniqueidentifier
								@DocumentId = N'01FFK5BCX2ZMEUJQGGURFJ22JX4BHWYNRO',				-- nvarchar(500)
								@LinkedEntityTypeGuid = '00000000-0000-0000-0000-000000000000',	-- uniqueidentifier
								@AllowPDFOutputOnly = 1,		-- bit
								@ProduceOneOutputPerRow = 0, -- bit
								@AllowExcelOutputOnly = 0,
								@Guid = @TermsDocumentGuid OUTPUT			-- uniqueidentifier


DECLARE	@FeeProposalDocumentGuid UNIQUEIDENTIFIER = '93573DA3-7EC0-4823-AD49-58518AC5D4B5'
EXEC SCore.MergeDocumentsUpsert @Name = N'Fee Proposal',					-- nvarchar(250)
								@FilenameTemplate = N'Fee Proposal',		-- nvarchar(250)
								@EntityTypeGuid = '3B4F2DF9-B6CF-4A49-9EED-2206473867A1',			-- uniqueidentifier
								@SharepointSiteGuid = 'D42EAC7E-705C-4D17-BF6B-28D7FDE1FE4F',		-- uniqueidentifier
								@DocumentId = N'01BBLX4WVCQIZLZYU24JFKNL5GC6VEFCGC',				-- nvarchar(500)
								@LinkedEntityTypeGuid = '03BFC484-77A4-4CD9-B0A0-5C809214C092',	-- uniqueidentifier
								@AllowPDFOutputOnly = 1,		-- bit
								@ProduceOneOutputPerRow = 1, -- bit
								@AllowExcelOutputOnly = 0,
								@Guid = @FeeProposalDocumentGuid OUTPUT			-- uniqueidentifier

DECLARE @MergeDocumentItem1Guid UNIQUEIDENTIFIER = '670A0E14-CC3B-4C02-8DE3-5F836771C6C8';
EXEC SCore.MergeDocumentItemsUpsert @MergeDocumentGuid = @FeeProposalDocumentGuid,			-- uniqueidentifier
									@MergeDocumentItemTypeGuid = '16AC0BAB-D41C-4EDC-AC09-7BD871DB57B6',	-- uniqueidentifier
									@BookmarkName = N'EnquiryServices',				-- nvarchar(50)
									@EntityTypeGuid = 'D6D44230-F3CC-4464-9D00-BBAB4F416F89',				-- uniqueidentifier
									@SubFolderPath = N'',				-- nvarchar(200)
									@ImageColumns = 0,					-- int
									@Guid = @MergeDocumentItem1Guid OUTPUT				-- uniqueidentifier

DECLARE	@Include1Guid UNIQUEIDENTIFIER = '1BE45D6D-E0F7-43A1-A59D-44DCCE31BBEE';
EXEC SCore.MergeDocumentItemIncludesUpsert @MergeDocumentItemGuid = @MergeDocumentItem1Guid,					-- uniqueidentifier
										   @SortOrder = 0,									-- int
										   @SourceDocumentEntityPropertyGuid = '00000000-0000-0000-0000-000000000000',		-- uniqueidentifier
										   @SourceSharePointItemEntityPropertyGuid = '00000000-0000-0000-0000-000000000000',	-- uniqueidentifier
										   @IncludedMergeDocumentGuid = '50A8B80A-2227-4DA4-B1E3-115949D1DFAA',				-- uniqueidentifier
										   @Guid = @Include1Guid OUTPUT								-- uniqueidentifier


DECLARE @MergeDocumentItem2Guid UNIQUEIDENTIFIER = '1E269AFF-0BEE-4993-83FF-0EA69746ACE5';
EXEC SCore.MergeDocumentItemsUpsert @MergeDocumentGuid = @FeeProposalDocumentGuid,			-- uniqueidentifier
									@MergeDocumentItemTypeGuid = '16AC0BAB-D41C-4EDC-AC09-7BD871DB57B6',	-- uniqueidentifier
									@BookmarkName = N'SocotecTerms',				-- nvarchar(50)
									@EntityTypeGuid = '00000000-0000-0000-0000-000000000000',				-- uniqueidentifier
									@SubFolderPath = N'',				-- nvarchar(200)
									@ImageColumns = 0,					-- int
									@Guid = @MergeDocumentItem2Guid OUTPUT				-- uniqueidentifier

DECLARE	@Include2Guid UNIQUEIDENTIFIER = 'E203702C-E10C-433D-B8C0-B9A7330E1B3D';
EXEC SCore.MergeDocumentItemIncludesUpsert @MergeDocumentItemGuid = @MergeDocumentItem2Guid,					-- uniqueidentifier
										   @SortOrder = 0,									-- int
										   @SourceDocumentEntityPropertyGuid = '00000000-0000-0000-0000-000000000000',		-- uniqueidentifier
										   @SourceSharePointItemEntityPropertyGuid = '00000000-0000-0000-0000-000000000000',	-- uniqueidentifier
										   @IncludedMergeDocumentGuid = '576F2D2A-C04E-47FD-A9C4-624F8A56F634',				-- uniqueidentifier
										   @Guid = @Include2Guid OUTPUT								-- uniqueidentifier

DECLARE @MergeDocumentItem3Guid UNIQUEIDENTIFIER = 'A168DD38-2B78-4687-84B9-6FE1497133EB';
EXEC SCore.MergeDocumentItemsUpsert @MergeDocumentGuid = @FeeProposalDocumentGuid,			-- uniqueidentifier
									@MergeDocumentItemTypeGuid = '9F69CA42-52C1-44BD-A0DE-E9601664B5DC',	-- uniqueidentifier
									@BookmarkName = N'ScheduleOfClientInfo',				-- nvarchar(50)
									@EntityTypeGuid = '433B83C1-3009-4B8A-A81D-1109789F3C27',				-- uniqueidentifier
									@SubFolderPath = N'',				-- nvarchar(200)
									@ImageColumns = 0,					-- int
									@Guid = @MergeDocumentItem3Guid OUTPUT				-- uniqueidentifier

DECLARE @MergeDocumentItem4Guid UNIQUEIDENTIFIER = 'D2F31E27-B29D-487E-BAF4-640775DD5D58';
EXEC SCore.MergeDocumentItemsUpsert @MergeDocumentGuid = @FeeProposalDocumentGuid,			-- uniqueidentifier
									@MergeDocumentItemTypeGuid = '9F69CA42-52C1-44BD-A0DE-E9601664B5DC',	-- uniqueidentifier
									@BookmarkName = N'AcceptanceEnquiryServices',				-- nvarchar(50)
									@EntityTypeGuid = 'E1FFEDFD-9585-40C9-A21B-92CF51B4CEE7',				-- uniqueidentifier
									@SubFolderPath = N'',				-- nvarchar(200)
									@ImageColumns = 0,					-- int
									@Guid = @MergeDocumentItem4Guid OUTPUT				-- uniqueidentifier

UPDATE	e
SET		e.SignatoryIdentityId = ISNULL(sig.ID, -1)
FROM	SSop.Enquiries AS e
OUTER APPLY
(
	SELECT	ou.ID	
	FROM	SCore.OrganisationalUnits AS ou 
	WHERE	(ou.ID = e.OrganisationalUnitID)
		AND	(ou.IsBusinessUnit = 1)
) AS Bu
OUTER APPLY
(
	SELECT	ou2.ID	
	FROM	SCore.OrganisationalUnits AS ou 
	JOIN	SCore.OrganisationalUnits AS ou2 ON (ou2.ID = ou.ParentID)
	WHERE	(ou.ID = e.OrganisationalUnitID)
		AND	(ou.IsDepartment = 1)
) AS Dpt
OUTER APPLY 
(
	SELECT	i.ID	
	FROM	SCore.Identities AS i 
	WHERE	(i.FullName IN (N'Neil Fenn', N'Ryan Fitzgerald', N'Mick Cahill'))
	AND		(i.OriganisationalUnitId = ISNULL(bu.ID, dpt.ID))
) AS Sig
WHERE	(e.SignatoryIdentityId < 0)



UPDATE	qi
SET		qi.QuoteId = qs.QuoteId,
		qi.NumberOfSiteVisits = qs.NumberOfSiteVisits,
		qi.NumberOfMeetings = qs.NumberOfMeetings,
		qi.ProvideAtStageID = qs.RibaStageId
FROM	SSop.QuoteItems AS qi
JOIN	SSop.QuoteSections AS qs ON (qs.ID = qi.QuoteSectionId)
WHERE	(qi.QuoteId < 0)
	AND	(qi.ID > 0)

-- commit tran 

-- rollback tran 



--EXEC SCore.PostDeploymentScript
--GO 

