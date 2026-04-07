SET LANGUAGE 'British English'
SET DATEFORMAT ymd
SET ARITHABORT, ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER, ANSI_NULLS, NOCOUNT, XACT_ABORT ON
SET NUMERIC_ROUNDABORT, IMPLICIT_TRANSACTIONS OFF
GO


BEGIN TRAN 


EXEC sys.sp_set_session_context @key = 'S_disable_triggers',
								@value = 1;
								
DECLARE @BCGuid UNIQUEIDENTIFIER,
		@BCAGuid UNIQUEIDENTIFIER,
		@BCCSGuid UNIQUEIDENTIFIER,
		@HRBGuid UNIQUEIDENTIFIER,
		@CDMGuid UNIQUEIDENTIFIER,
		@ParentOrganisationalUnitGuid UNIQUEIDENTIFIER,
		@Name NVARCHAR(250),
		@AddressGuid UNIQUEIDENTIFIER,
		@ContactGuid UNIQUEIDENTIFIER,
		@OfficialAddressGuid UNIQUEIDENTIFIER,
		@OfficialContactGuid UNIQUEIDENTIFIER,
		@DepartmentPrefix NVARCHAR(10),
		@CostCentreCode NVARCHAR(50),
		@DefaultSecurityGroupGuid UNIQUEIDENTIFIER

/*
	Add the Building Control Node.
*/
PRINT (N'Adding the Building Control Node')
IF (NOT EXISTS (SELECT 1 FROM SCore.OrganisationalUnits WHERE Name = N'Building Control'))
BEGIN 
	SELECT	@BCGuid = NEWID(),
			@ParentOrganisationalUnitGuid = ou.Guid,
			@Name = N'Building Control', 
			@AddressGuid = '00000000-0000-0000-0000-000000000000',
			@ContactGuid = '00000000-0000-0000-0000-000000000000',
			@OfficialAddressGuid = '00000000-0000-0000-0000-000000000000',
			@OfficialContactGuid = '00000000-0000-0000-0000-000000000000',
			@DepartmentPrefix = N'',
			@CostCentreCode = N'',
			@DefaultSecurityGroupGuid = '00000000-0000-0000-0000-000000000000'
	FROM	SCore.OrganisationalUnits AS ou
	WHERE	([Name] = N'Building and Real Estate')

	EXEC SCore.OrganisationalUnitsUpsert @ParentOrganisationalUnitGuid = @ParentOrganisationalUnitGuid,	-- uniqueidentifier
										 @Name = @Name,							-- nvarchar(250)
										 @AddressGuid = @AddressGuid,					-- uniqueidentifier
										 @ContactGuid = @ContactGuid,					-- uniqueidentifier
										 @OfficialAddressGuid = @OfficialAddressGuid,			-- uniqueidentifier
										 @OfficialContactGuid = @OfficialContactGuid,			-- uniqueidentifier
										 @DepartmentPrefix = @DepartmentPrefix,				-- nvarchar(10)
										 @CostCentreCode = @CostCentreCode,					-- nvarchar(50)
										 @DefaultSecurityGroupGuid = @DefaultSecurityGroupGuid,		-- uniqueidentifier
										 @Guid = @BCGuid OUTPUT					-- uniqueidentifier

	/*
		Update Building Control Admin
	*/
	PRINT (N'Update the Building Control Admin Node')
	SELECT	@BCAGuid = ou.Guid,
			@ParentOrganisationalUnitGuid = @ParentOrganisationalUnitGuid,
			@Name = N'Building & Real Estate Admin',
			@AddressGuid = a.Guid,
			@ContactGuid = c.Guid,
			@OfficialAddressGuid = a2.Guid,
			@OfficialContactGuid = c2.Guid,
			@DepartmentPrefix = ou.DepartmentPrefix,
			@CostCentreCode = N'BCG',
			@DefaultSecurityGroupGuid = g.Guid
	FROM	SCore.OrganisationalUnits AS ou
	JOIN	SCore.OrganisationalUnits AS pou ON (pou.ID = ou.ParentID)
	JOIN	SCrm.Addresses AS a ON (a.ID = ou.AddressId)
	JOIN	SCrm.Addresses AS a2 ON (a2.ID = ou.OfficialAddressId)
	JOIN	SCrm.Contacts AS c ON (c.ID = ou.ContactId)
	JOIN	SCrm.Contacts AS c2 ON (c2.ID = ou.OfficialContactId)
	JOIN	SCore.Groups AS g ON (g.Id = ou.DefaultSecurityGroupId)
	WHERE	(ou.Guid = 'F233BB03-3181-49AE-B331-39C58F328457')

	EXEC SCore.OrganisationalUnitsUpsert @ParentOrganisationalUnitGuid = @ParentOrganisationalUnitGuid,	-- uniqueidentifier
										 @Name = @Name,							-- nvarchar(250)
										 @AddressGuid = @AddressGuid,					-- uniqueidentifier
										 @ContactGuid = @ContactGuid,					-- uniqueidentifier
										 @OfficialAddressGuid = @OfficialAddressGuid,			-- uniqueidentifier
										 @OfficialContactGuid = @OfficialContactGuid,			-- uniqueidentifier
										 @DepartmentPrefix = @DepartmentPrefix,				-- nvarchar(10)
										 @CostCentreCode = @CostCentreCode,					-- nvarchar(50)
										 @DefaultSecurityGroupGuid = @DefaultSecurityGroupGuid,		-- uniqueidentifier
										 @Guid = @BCAGuid OUTPUT					-- uniqueidentifier

	/*
		Update Building Control Consultancy
	*/
	PRINT (N'Update the Building Control Consultancy')
	SELECT	@BCCSGuid = ou.Guid,
			@ParentOrganisationalUnitGuid = @BCAGuid,
			@Name = N'Building Control Consultancy',
			@AddressGuid = a.Guid,
			@ContactGuid = c.Guid,
			@OfficialAddressGuid = a2.Guid,
			@OfficialContactGuid = c2.Guid,
			@DepartmentPrefix = ou.DepartmentPrefix,
			@CostCentreCode = N'BCG-BCO',
			@DefaultSecurityGroupGuid = g.Guid
	FROM	SCore.OrganisationalUnits AS ou
	JOIN	SCore.OrganisationalUnits AS pou ON (pou.ID = ou.ParentID)
	JOIN	SCrm.Addresses AS a ON (a.ID = ou.AddressId)
	JOIN	SCrm.Addresses AS a2 ON (a2.ID = ou.OfficialAddressId)
	JOIN	SCrm.Contacts AS c ON (c.ID = ou.ContactId)
	JOIN	SCrm.Contacts AS c2 ON (c2.ID = ou.OfficialContactId)
	JOIN	SCore.Groups AS g ON (g.Id = ou.DefaultSecurityGroupId)
	WHERE	(ou.Guid = '0125329F-003B-4CE4-A2C9-8C6DCC1A4DFF')

	EXEC SCore.OrganisationalUnitsUpsert @ParentOrganisationalUnitGuid = @ParentOrganisationalUnitGuid,	-- uniqueidentifier
										 @Name = @Name,							-- nvarchar(250)
										 @AddressGuid = @AddressGuid,					-- uniqueidentifier
										 @ContactGuid = @ContactGuid,					-- uniqueidentifier
										 @OfficialAddressGuid = @OfficialAddressGuid,			-- uniqueidentifier
										 @OfficialContactGuid = @OfficialContactGuid,			-- uniqueidentifier
										 @DepartmentPrefix = @DepartmentPrefix,				-- nvarchar(10)
										 @CostCentreCode = @CostCentreCode,					-- nvarchar(50)
										 @DefaultSecurityGroupGuid = @DefaultSecurityGroupGuid,		-- uniqueidentifier
										 @Guid = @BCCSGuid OUTPUT					-- uniqueidentifier


	/*
		Update HRB Consultancy
	*/
	PRINT (N'Update the HRB Consultancy Node')
	SELECT	@HRBGuid = ou.Guid,
			@ParentOrganisationalUnitGuid = @BCAGuid,
			@Name = N'HRB Consultancy',
			@AddressGuid = a.Guid,
			@ContactGuid = c.Guid,
			@OfficialAddressGuid = a2.Guid,
			@OfficialContactGuid = c2.Guid,
			@DepartmentPrefix = ou.DepartmentPrefix,
			@CostCentreCode = N'BCG-HRB',
			@DefaultSecurityGroupGuid = g.Guid
	FROM	SCore.OrganisationalUnits AS ou
	JOIN	SCore.OrganisationalUnits AS pou ON (pou.ID = ou.ParentID)
	JOIN	SCrm.Addresses AS a ON (a.ID = ou.AddressId)
	JOIN	SCrm.Addresses AS a2 ON (a2.ID = ou.OfficialAddressId)
	JOIN	SCrm.Contacts AS c ON (c.ID = ou.ContactId)
	JOIN	SCrm.Contacts AS c2 ON (c2.ID = ou.OfficialContactId)
	JOIN	SCore.Groups AS g ON (g.Id = ou.DefaultSecurityGroupId)
	WHERE	(ou.Guid = '105F65B1-DC0C-4E25-8853-9DF80177D3DF')

	EXEC SCore.OrganisationalUnitsUpsert @ParentOrganisationalUnitGuid = @ParentOrganisationalUnitGuid,	-- uniqueidentifier
										 @Name = @Name,							-- nvarchar(250)
										 @AddressGuid = @AddressGuid,					-- uniqueidentifier
										 @ContactGuid = @ContactGuid,					-- uniqueidentifier
										 @OfficialAddressGuid = @OfficialAddressGuid,			-- uniqueidentifier
										 @OfficialContactGuid = @OfficialContactGuid,			-- uniqueidentifier
										 @DepartmentPrefix = @DepartmentPrefix,				-- nvarchar(10)
										 @CostCentreCode = @CostCentreCode,					-- nvarchar(50)
										 @DefaultSecurityGroupGuid = @DefaultSecurityGroupGuid,		-- uniqueidentifier
										 @Guid = @HRBGuid OUTPUT					-- uniqueidentifier

	/*
		Update CDM Consultancy
	*/
	PRINT (N'Update the CDM Consultancy Node')
	SELECT	@CDMGuid = ou.Guid,
			@ParentOrganisationalUnitGuid = @BCGuid,
			@Name = N'CDM Consulting',
			@AddressGuid = a.Guid,
			@ContactGuid = c.Guid,
			@OfficialAddressGuid = a2.Guid,
			@OfficialContactGuid = c2.Guid,
			@DepartmentPrefix = ou.DepartmentPrefix,
			@CostCentreCode = N'BBS-CDM',
			@DefaultSecurityGroupGuid = g.Guid
	FROM	SCore.OrganisationalUnits AS ou
	JOIN	SCore.OrganisationalUnits AS pou ON (pou.ID = ou.ParentID)
	JOIN	SCrm.Addresses AS a ON (a.ID = ou.AddressId)
	JOIN	SCrm.Addresses AS a2 ON (a2.ID = ou.OfficialAddressId)
	JOIN	SCrm.Contacts AS c ON (c.ID = ou.ContactId)
	JOIN	SCrm.Contacts AS c2 ON (c2.ID = ou.OfficialContactId)
	JOIN	SCore.Groups AS g ON (g.Id = ou.DefaultSecurityGroupId)
	WHERE	(ou.Guid = '2C9489BD-EAE8-4703-90D7-56C94E802EDA')

	EXEC SCore.OrganisationalUnitsUpsert @ParentOrganisationalUnitGuid = @ParentOrganisationalUnitGuid,	-- uniqueidentifier
										 @Name = @Name,							-- nvarchar(250)
										 @AddressGuid = @AddressGuid,					-- uniqueidentifier
										 @ContactGuid = @ContactGuid,					-- uniqueidentifier
										 @OfficialAddressGuid = @OfficialAddressGuid,			-- uniqueidentifier
										 @OfficialContactGuid = @OfficialContactGuid,			-- uniqueidentifier
										 @DepartmentPrefix = @DepartmentPrefix,				-- nvarchar(10)
										 @CostCentreCode = @CostCentreCode,					-- nvarchar(50)
										 @DefaultSecurityGroupGuid = @DefaultSecurityGroupGuid,		-- uniqueidentifier
										 @Guid = @CDMGuid OUTPUT					-- uniqueidentifier

END									 									 

/* Re-allocate HRB Work */

DECLARE @HRBOrgUnit INT,
		@HRBGroupID INT

SELECT	@HRBOrgUnit = ou.ID,
		@HRBGroupID = ou.DefaultSecurityGroupId
FROM	SCore.OrganisationalUnits AS ou
WHERE	(ou.CostCentreCode = N'BCG-HRB');

DECLARE @HRBJobs TABLE
	(
		JobID INT NOT NULL,
		JobGuid UNIQUEIDENTIFIER NOT NULL 
	);

DECLARE @HRBQuotes TABLE
	(
		QuoteID INT NOT NULL,
		QuoteGuid UNIQUEIDENTIFIER NOT NULL
	);

DECLARE @HRBEnquiries TABLE
	(
		EnquiryID INT NOT NULL,
		EnquiryGuid UNIQUEIDENTIFIER NOT NULL
	);

-- find all the jobs 
INSERT	@HRBJobs
	 (JobID, JobGuid)
SELECT	j.ID,
		j.Guid
FROM	SJob.Jobs AS j
WHERE	(NOT EXISTS
	(
		SELECT	1
		FROM	SCore.Identities AS i
		WHERE	(i.ID = j.SurveyorID)
			AND (i.FullName IN (N'Rob Handley', N'Jason Warnes', N'Matthew Hardwick', N'Ryan Fitzgerald',
								N'Neil Goodall', N'Dafydd Griffiths', N'Nicola Charalambides', N'Bethany Craig',
								N'Lynn Overton', N'Lucie Plumley'
							   )
				)
	)
		)
	AND (EXISTS
	(
		SELECT	1
		FROM	SCore.OrganisationalUnits AS ou
		WHERE	(ou.CostCentreCode IN (N'BCG', N'BCG-BCO'))
			AND	(ou.ID = j.OrganisationalUnitID)
	)
		)
	AND (j.Number NOT LIKE N'SHORE-%')
	AND (j.SurveyorID > 0)
	AND	(j.ID > 0)

-- find all the quotes 
INSERT	@HRBQuotes
	 (QuoteID, QuoteGuid)
SELECT	q.ID, q.Guid
FROM	SSop.Quotes AS q
WHERE	(EXISTS
	(
		SELECT	1
		FROM	SSop.QuoteItems AS qi
		JOIN	@HRBJobs		AS j ON (j.JobID = qi.CreatedJobId)
		WHERE	(qi.QuoteId = q.ID)
	)
		)
	AND	(q.ID > 0)

-- find all the enquirires. 
INSERT	@HRBEnquiries
	 (EnquiryID, EnquiryGuid)
SELECT	e.ID, e.Guid
FROM	SSop.Enquiries AS e
WHERE	(EXISTS
	(
		SELECT	1
		FROM	SSop.EnquiryServices AS es
		JOIN	SSop.Quotes			 AS q ON (q.EnquiryServiceID = es.ID)
		JOIN	@HRBQuotes			 AS hq ON (hq.QuoteID		 = q.ID)
		WHERE	(es.EnquiryId = e.ID)
	)
		)
	AND	(e.ID > 0);

-- Move the Jobs 
UPDATE	j
SET		j.OrganisationalUnitID = @HRBOrgUnit
FROM	SJob.Jobs AS j
JOIN	@HRBJobs  AS hj ON (hj.JobID = j.ID)
WHERE	(j.ID > 0);

-- Move the Quotes
UPDATE	q
SET		q.OrganisationalUnitID = @HRBOrgUnit
FROM	SSop.Quotes AS q
JOIN	@HRBQuotes	AS hq ON (hq.QuoteID = q.ID)
WHERE	(q.ID > 0);

-- Move the Enquiries.
UPDATE	e
SET		e.OrganisationalUnitID = @HRBOrgUnit
FROM	SSop.Enquiries AS e
JOIN	@HRBEnquiries  AS he ON (he.EnquiryID = e.ID)
WHERE	(e.ID > 0);

-- Get all of the object Guids together. 
DECLARE	@FullObjectList SCore.GuidUniqueList

INSERT	@FullObjectList
	 (GuidValue)
SELECT	JobGuid
FROM	@HRBJobs AS hj
UNION ALL 
SELECT	QuoteGuid 
FROM	@HRBQuotes AS hq
UNION ALL 
SELECT	EnquiryGuid 
FROM	@HRBEnquiries AS he

-- Update the Object Security 
UPDATE	os
SET		os.GroupId = @HRBGroupID
FROM	SCore.ObjectSecurity AS os
JOIN	@FullObjectList AS fol ON (fol.GuidValue = os.ObjectGuid)


IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

/* Re-allocate non-hrb work */

DECLARE @NonHRBOrgUnit INT,
		@NonHRBGroupID INT

SELECT	@NonHRBOrgUnit = ou.ID,
		@NonHRBGroupID = ou.DefaultSecurityGroupId
FROM	SCore.OrganisationalUnits AS ou
WHERE	(ou.CostCentreCode = N'BCG-BCO');

DECLARE @NonHRBJobs TABLE
	(
		JobID INT NOT NULL,
		JobGuid UNIQUEIDENTIFIER NOT NULL 
	);

DECLARE @NonHRBQuotes TABLE
	(
		QuoteID INT NOT NULL,
		QuoteGuid UNIQUEIDENTIFIER NOT NULL
	);

DECLARE @NonHRBEnquiries TABLE
	(
		EnquiryID INT NOT NULL,
		EnquiryGuid UNIQUEIDENTIFIER NOT NULL
	);

-- find all the jobs 
INSERT	@NonHRBJobs
	 (JobID, JobGuid)
SELECT	j.ID,
		j.Guid
FROM	SJob.Jobs AS j
WHERE	(EXISTS
	(
		SELECT	1
		FROM	SCore.Identities AS i
		WHERE	(i.ID = j.SurveyorID)
			AND (i.FullName IN (N'Rob Handley', N'Jason Warnes', N'Matthew Hardwick', N'Ryan Fitzgerald',
								N'Neil Goodall', N'Dafydd Griffiths', N'Nicola Charalambides', N'Bethany Craig',
								N'Lynn Overton', N'Lucie Plumley'
							   )
				)
	)
		)
	AND (EXISTS
	(
		SELECT	1
		FROM	SCore.OrganisationalUnits AS ou
		WHERE	(ou.CostCentreCode IN (N'BCG', N'BCG-BCO'))
			AND	(j.OrganisationalUnitID = ou.ID)
	)
		)
	AND (j.Number NOT LIKE N'SHORE-%')
	AND (j.SurveyorID > 0)
	AND	(j.ID > 0)

-- find all the quotes 
INSERT	@NonHRBQuotes
	 (QuoteID, QuoteGuid)
SELECT	q.ID, q.Guid
FROM	SSop.Quotes AS q
WHERE	(EXISTS
	(
		SELECT	1
		FROM	SSop.QuoteItems AS qi
		JOIN	@NonHRBJobs		AS j ON (j.JobID = qi.CreatedJobId)
		WHERE	(qi.QuoteId = q.ID)
	)
		)
	AND	(q.ID > 0)

-- find all the enquirires. 
INSERT	@NonHRBEnquiries
	 (EnquiryID, EnquiryGuid)
SELECT	e.ID, e.Guid
FROM	SSop.Enquiries AS e
WHERE	(EXISTS
	(
		SELECT	1
		FROM	SSop.EnquiryServices AS es
		JOIN	SSop.Quotes			 AS q ON (q.EnquiryServiceID = es.ID)
		JOIN	@NonHRBQuotes			 AS hq ON (hq.QuoteID		 = q.ID)
		WHERE	(es.EnquiryId = e.ID)
	)
		)
	AND	(e.ID > 0);

-- Move the Jobs 
UPDATE	j
SET		j.OrganisationalUnitID = @NonHRBOrgUnit
FROM	SJob.Jobs AS j
JOIN	@NonHRBJobs  AS hj ON (hj.JobID = j.ID)
WHERE	(j.ID > 0);

-- Move the Quotes
UPDATE	q
SET		q.OrganisationalUnitID = @NonHRBOrgUnit
FROM	SSop.Quotes AS q
JOIN	@NonHRBQuotes	AS hq ON (hq.QuoteID = q.ID)
WHERE	(q.ID > 0);

-- Move the Enquiries.
UPDATE	e
SET		e.OrganisationalUnitID = @NonHRBOrgUnit
FROM	SSop.Enquiries AS e
JOIN	@NonHRBEnquiries  AS he ON (he.EnquiryID = e.ID)
WHERE	(e.ID > 0);

-- Get all of the object Guids together. 
DELETE	@FullObjectList

INSERT	@FullObjectList
	 (GuidValue)
SELECT	JobGuid
FROM	@NonHRBJobs AS hj
UNION ALL 
SELECT	QuoteGuid 
FROM	@NonHRBQuotes AS hq
UNION ALL 
SELECT	EnquiryGuid 
FROM	@NonHRBEnquiries AS he

-- Update the Object Security 
UPDATE	os
SET		os.GroupId = @NonHRBGroupID
FROM	SCore.ObjectSecurity AS os
JOIN	@FullObjectList AS fol ON (fol.GuidValue = os.ObjectGuid)

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END


/* Re-allocate the users */

UPDATE i
SET i.OriganisationalUnitId = @NonHRBOrgUnit
FROM	SCore.Identities AS i
WHERE	(i.FullName IN (N'Rob Handley', N'Jason Warnes', N'Matthew Hardwick', N'Ryan Fitzgerald',
								N'Neil Goodall', N'Dafydd Griffiths', N'Nicola Charalambides', N'Bethany Craig',
								N'Lynn Overton', N'Lucie Plumley'
							   )
		)

UPDATE i
SET i.OriganisationalUnitId = @HRBOrgUnit
FROM	SCore.Identities AS i
JOIN	SCore.OrganisationalUnits AS ou ON (ou.ID = i.OriganisationalUnitId)
WHERE	(i.FullName NOT IN (N'Rob Handley', N'Jason Warnes', N'Matthew Hardwick', N'Ryan Fitzgerald',
								N'Neil Goodall', N'Dafydd Griffiths', N'Nicola Charalambides', N'Bethany Craig',
								N'Lynn Overton', N'Lucie Plumley'
							   )
		)
	AND	(ou.CostCentreCode IN (N'BCG', N'BCG-BCO'))


IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

/* Tidy up anything that's now linked to a BU instead of a Department */
DECLARE @BCAOrgUnit INT

SELECT	@BCAOrgUnit = ou.ID
FROM	SCore.OrganisationalUnits AS ou
WHERE	(ou.CostCentreCode = N'BCG');

DECLARE @BCGQuotes TABLE
	(
		QuoteID INT NOT NULL,
		QuoteGuid UNIQUEIDENTIFIER NOT NULL
	);

DECLARE @BCGEnquiries TABLE
	(
		EnquiryID INT NOT NULL,
		EnquiryGuid UNIQUEIDENTIFIER NOT NULL
	);

-- find all the quotes 
INSERT	@BCGQuotes
	 (QuoteID, QuoteGuid)
SELECT	q.ID, q.Guid
FROM	SSop.Quotes AS q
WHERE	(q.OrganisationalUnitID = @BCAOrgUnit)
	AND	(q.ID > 0)

-- find all the enquirires. 
INSERT	@BCGEnquiries
	 (EnquiryID, EnquiryGuid)
SELECT	e.ID, e.Guid
FROM	SSop.Enquiries AS e
WHERE	(e.OrganisationalUnitID = @BCAOrgUnit)
	AND	(e.ID > 0);

-- Move the Quotes
UPDATE	q
SET		q.OrganisationalUnitID = i.OriganisationalUnitId
FROM	SSop.Quotes AS q
JOIN	@BCGQuotes	AS hq ON (hq.QuoteID = q.ID)
JOIN	SCore.Identities AS i ON i.ID = q.QuotingUserId
WHERE	(q.ID > 0);

-- Move the Enquiries.
UPDATE	e
SET		e.OrganisationalUnitID = i.OriganisationalUnitId
FROM	SSop.Enquiries AS e
JOIN	@BCGEnquiries  AS he ON (he.EnquiryID = e.ID)
JOIN	SCore.Identities AS i ON (i.ID = e.CreatedByUserId)
WHERE	(e.ID > 0);

-- Get all of the object Guids together. 
DELETE	@FullObjectList

INSERT	@FullObjectList
	 (GuidValue)
SELECT	QuoteGuid 
FROM	@BCGQuotes AS hq


-- Update the Object Security 
UPDATE	os
SET		os.GroupId = ou.DefaultSecurityGroupId
FROM	SCore.ObjectSecurity AS os
JOIN	@FullObjectList AS fol ON (fol.GuidValue = os.ObjectGuid)
JOIN	SSop.Quotes AS q ON (q.guid = os.ObjectGuid)
JOIN	SCore.OrganisationalUnits AS ou ON (ou.ID = q.OrganisationalUnitID)

-- Get all of the object Guids together. 
DELETE	@FullObjectList

INSERT	@FullObjectList
	 (GuidValue)
SELECT	EnquiryGuid 
FROM	@BCGEnquiries AS he

-- Update the Object Security 
UPDATE	os
SET		os.GroupId = ou.DefaultSecurityGroupId
FROM	SCore.ObjectSecurity AS os
JOIN	@FullObjectList AS fol ON (fol.GuidValue = os.ObjectGuid)
JOIN	SSop.Enquiries AS e ON (e.guid = os.ObjectGuid)
JOIN	SCore.OrganisationalUnits AS ou ON (ou.ID = e.OrganisationalUnitID)


IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Commit Transaction
--
IF @@TRANCOUNT>0 COMMIT TRANSACTION
SET NOEXEC OFF
GO
