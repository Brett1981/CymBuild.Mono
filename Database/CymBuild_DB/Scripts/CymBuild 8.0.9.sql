EXEC sys.sp_set_session_context
  @key   = 'S_disable_triggers',
  @Value = 1;

BEGIN TRAN

UPDATE  j
SET     ClientAppointmentReceived = CASE
                                           WHEN CompletedDateTimeUTC IS NOT NULL THEN
                                             1
                                           ELSE
                                           0
                                   END
FROM
        SJob.Jobs j
JOIN
        SJob.Milestones m ON (j.ID = m.JobID)
JOIN
        SJob.MilestoneTypes mt ON (m.MilestoneTypeID = mt.ID)
WHERE
  (mt.Code = N'WAR')

UPDATE  m
SET     RowStatus = 254
FROM
        SJob.Milestones m
JOIN
        SJob.MilestoneTypes mt ON (m.MilestoneTypeID = mt.ID)
WHERE
  (mt.Code = N'WAR')

UPDATE  SJob.MilestoneTypes
SET     IsActive = 0
WHERE
  (Code = N'WAR')

DROP TRIGGER SUserInterface.tg_GridDefinitions_RecordHistory
GO

DROP TRIGGER SUserInterface.tg_GridViewDefinitions_RecordHistory
GO

DROP TRIGGER SUserInterface.tg_GridViewColumnDefinitions_RecordHistory
GO

DROP TRIGGER SCore.tg_EntityTypes_RecordHistory
GO

UPDATE  cd
SET     IsDefault = 1
FROM
        SCrm.ContactDetails cd
WHERE
  (NOT EXISTS
  (
      SELECT
              1
      FROM
              SCrm.ContactDetails cde
      WHERE
              (cde.ContactDetailTypeID = cd.ContactDetailTypeID)
              AND (cde.ContactID = cd.ContactID)
              AND (cde.RowStatus IN (0, 254))
  )
  )

UPDATE	up
SET		Guid = i.Guid
FROM	SCore.UserPreferences up
JOIN	SCore.Identities i ON (i.Id = up.ID)
WHERE	(i.Guid <> up.Guid)


DELETE rh
FROM	SCore.RecordHistory AS rh
WHERE	NOT EXISTS
		(
			SELECT	1
			FROM	SCore.DataObjects AS do 
			WHERE	(do.Guid = rh.RowGuid)
		)

DELETE ri
FROM	SCore.RecentItems AS ri
WHERE	NOT EXISTS
		(
			SELECT	1
			FROM	SCore.DataObjects AS do 
			WHERE	(do.Guid = ri.RecordGuid)
		)

-- COMMIT TRAN 

-- ROLLBACK TRAN 