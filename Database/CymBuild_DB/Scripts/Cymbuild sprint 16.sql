BEGIN TRAN 


EXEC sys.sp_set_session_context @key = 'S_disable_triggers',
								@value = 1;

DECLARE @SiteWorkMileStones TABLE 
(
	id INT,
	Guid UNIQUEIDENTIFIER,
	CompletedDate DATETIME2, 
	JobId INT
)

INSERT @SiteWorkMileStones
	 (id, Guid, CompletedDate, JobId)
SELECT
	 m.id, NEWID(), m.CompletedDateTimeUTC, m.JobId
FROM	
	SJob.Milestones AS m 
JOIN	
	SJob.MilestoneTypes AS mt ON (mt.ID = m.MilestoneTypeID)
WHERE	
	(m.CompletedDateTimeUTC IS NOT NULL)
	AND	(mt.Name =N'Site Work Commencement')

DECLARE	@KeyDatesToCreate SCore.GuidUniqueList

INSERT @KeyDatesToCreate
	 (GuidValue)
SELECT	Guid
FROM	@SiteWorkMileStones AS swms


DECLARE @IsInsert BIT;
EXEC SCore.DataObjectBulkUpsert @GuidList = @KeyDatesToCreate,				-- GuidUniqueList
								@SchemeName = N'SJob',				-- nvarchar(255)
								@ObjectName = N'JobKeyDates',				-- nvarchar(255)
								@IncludeDefaultSecurity = 0, -- bit
								@IsInsert = @IsInsert OUTPUT	-- bit

INSERT SJob.JobKeyDates
	 (RowStatus, Guid, JobID, Detail, DateTime)
SELECT	1, Guid, JobId, N'Site Work Commencement', CompletedDate
FROM	@SiteWorkMileStones AS swms

UPDATE m
SET		RowStatus = 254
FROM	SJob.Milestones AS m
JOIN	@SiteWorkMileStones AS swms ON (swms.id = m.ID)


DELETE FROM SJob.JobPaymentStages 
WHERE	id IN (SELECT ID FROM SJob.JobPaymentStages AS jps 
			WHERE (EXISTS
			(SELECT	1
			FROM SJob.JobPaymentStages AS jps2 
			WHERE	(jps2.Guid = jps.Guid)
				AND (jps.id < jps2.ID)
			)
		))

-- rollback tran 

-- commit tran 