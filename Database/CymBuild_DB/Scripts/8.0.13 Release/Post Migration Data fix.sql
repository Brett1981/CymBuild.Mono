BEGIN TRAN;

EXEC sys.sp_set_session_context @key = 'S_disable_triggers',
								@value = 1;



DECLARE	@BadProjectID INT = 44,
		@GuidList SCore.GuidUniqueList,
		@IsInsert BIT,
		@NextProjectNumber INT,
		@stmt NVARCHAR(4000)

SELECT @BadProjectID = p.id
FROM SSop.Quotes 
JOIN	 SSop.Projects p ON (p.ID = Quotes.ProjectId)
GROUP BY p.Number, p.id
HAVING COUNT(1) > 100

/* Correct the Jobs -1 record */
UPDATE SJob.Jobs
SET ProjectId = -1
WHERE ID = -1;

/* Correct the Quotes -1 record */
UPDATE SSop.Quotes
SET ProjectId = -1
WHERE ID = -1;

/* Correct the Enquiries -1 record */
UPDATE SSop.Enquiries
SET ProjectId = -1
WHERE ID = -1;

/* Correct the Project Directory -1 record */
UPDATE	SJob.ProjectDirectory 
SET	ProjectID = -1
WHERE	id = -1

/* Reset the project on Quotes with no jobs to -1 */
UPDATE q
SET q.ProjectId = -1
--SELECT	*
FROM SSop.Quotes AS q
WHERE (EXISTS
(
    SELECT 1
    FROM SSop.QuoteSections AS qs
        JOIN SSop.QuoteItems AS qi
            ON (qi.QuoteSectionId = qs.ID)
        JOIN SJob.Jobs AS j
            ON (j.ID = qi.CreatedJobId)
    WHERE (qi.CreatedJobId < 0)
          AND (qs.QuoteId = q.ID)
)
      )
      AND (q.ProjectId = @BadProjectID);

/* Reset the project on Enquires set to project @BadProjectID */
UPDATE SSop.Enquiries
SET ProjectId = -1
WHERE (ProjectId = @BadProjectID);


/* Get a collection of the Quotes without a project. */
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

/* Create the Projects for the Quotes */
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

/* Update the next project number. */
SELECT @NextProjectNumber = MAX(Number) + 1 FROM SSop.Projects AS p

SET	@stmt = N'ALTER SEQUENCE SSop.ProjectNumber RESTART WITH ' + CONVERT(NVARCHAR(4000), @NextProjectNumber)

EXEC sp_executesql @stmt

/* Assign the Projects to the quotes. */
UPDATE	q
SET		q.ProjectId = p.ID
FROM	SSop.Quotes AS q
JOIN	@QuotesWithoutProjects AS qwp ON (qwp.QuoteID = q.ID)
JOIN	SSop.Projects AS p ON (p.Guid = qwp.NewProjectGuid)


/* Update enquiries to match the project on the quote. */
UPDATE	e
SET		e.ProjectId = q.ProjectId
FROM	SSop.Enquiries AS e 
JOIN	SSop.EnquiryServices AS es ON (es.EnquiryId = e.ID)
JOIN	SSop.Quotes q ON (q.ID = es.QuoteId)
WHERE	(e.ProjectId <> q.ProjectId)
	AND	(e.ProjectId < 0)


/* Create Projects for Enquiries that don't have a Quote.  */
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
FROM	@EnquiriesWithoutProjects AS qwp

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



/* Fix the description on Project 43 */
UPDATE	p
SET		p.ProjectDescription = N'Auto Generated Project for Quote ' + CONVERT(NVARCHAR(MAX), q.Number) + N' - ' + q.Overview
FROM	SSop.Projects AS p
JOIN	SSop.Quotes AS q ON (q.ProjectId = p.ID)
WHERE	(p.ID = @BadProjectID)


-- rollback tran

-- commit tran 


SELECT COUNT(1), p.Number, p.id
FROM SSop.Quotes 
JOIN	 SSop.Projects p ON (p.ID = Quotes.ProjectId)
GROUP BY p.Number, p.id
HAVING COUNT(1) > 2

SELECT * FROM SSop.Quotes 
WHERE ProjectId = 23677


SELECT	q.Number QuoteNumber, j.Number JobNumber, j.CreatedOn 
FROM	SSop.Quotes AS q 
JOIN	SSop.QuoteItems AS qi ON (qi.QuoteId = q.ID)
JOIN	SJob.Jobs AS j ON (j.ID = qi.CreatedJobId)
WHERE	(q.ProjectId < 0)
	AND	(q.ProjectId <> j.ProjectId)


SELECT * FROM SSop.Quotes WHERE ProjectId = 23677