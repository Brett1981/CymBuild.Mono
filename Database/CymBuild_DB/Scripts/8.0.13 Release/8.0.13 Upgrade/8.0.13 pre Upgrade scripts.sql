USE Concursus
go

EXEC SCore.PreDeploymentScript
GO

BEGIN TRAN 



EXEC sys.sp_set_session_context @key = 'S_disable_triggers',
								@value = 1;

UPDATE	p 
SET		Number = new.Number
FROM	SSop.Projects AS p 
JOIN  
(
SELECT ROW_NUMBER() OVER (ORDER BY ID) AS Number,
	p2.ID
FROM  SSop.Projects AS p2
WHERE p2.ID > 0
) new ON (new.ID = p.ID)
WHERE p.ID > 0 

DECLARE	@NextProjectNumber INT
SELECT @NextProjectNumber = NEXT VALUE FOR SSop.ProjectNumber

DECLARE	@stmt NVARCHAR(4000) = N'ALTER SEQUENCE SSop.ProjectNumber RESTART WITH ' + CONVERT(NVARCHAR(4000), @NextProjectNumber)

EXEC sp_executesql @stmt


/****** Object:  Index [IX_EntityQueries_EntityTypeID]    Script Date: 07/03/2025 11:04:02 ******/
DROP INDEX [IX_EntityQueries_EntityTypeID] ON [SCore].[EntityQueries]
GO


ALTER TABLE SUserInterface.GridViewWidgetQueries
DROP CONSTRAINT FK_GridViewWidgetQueries_EntityQueries
GO

ALTER TABLE SUserInterface.GridViewActions
DROP CONSTRAINT FK_GridViewActions_EntityQueries
GO

ALTER TABLE SUserInterface.ActionMenuItems
DROP CONSTRAINT FK_ActionMenuItems_EntityQueries
GO 

ALTER TABLE SCore.EntityQueryParameters
DROP CONSTRAINT FK_EntityQueryParameters_EntityQueries
GO 




COMMIT TRAN 


--
-- Create full-text stoplist [Honorifics]
--
CREATE FULLTEXT STOPLIST [Honorifics] AUTHORIZATION [dbo];
GO

ALTER FULLTEXT STOPLIST [Honorifics] ADD 'Dr' LANGUAGE 1033;
GO

ALTER FULLTEXT STOPLIST [Honorifics] ADD 'Lord' LANGUAGE 1033;
GO

ALTER FULLTEXT STOPLIST [Honorifics] ADD 'Mr' LANGUAGE 1033;
GO

ALTER FULLTEXT STOPLIST [Honorifics] ADD 'Mrs' LANGUAGE 1033;
GO

ALTER FULLTEXT STOPLIST [Honorifics] ADD 'Ms' LANGUAGE 1033;
GO

ALTER FULLTEXT STOPLIST [Honorifics] ADD 'Mx' LANGUAGE 1033;
GO

ALTER FULLTEXT STOPLIST [Honorifics] ADD 'Sir' LANGUAGE 1033;
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO

--
-- Create full-text catalog [AccountName]
--
CREATE FULLTEXT CATALOG [AccountName]
  WITH ACCENT_SENSITIVITY = OFF
  AUTHORIZATION [dbo]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO

--
-- Create full-text index on table [SCrm].[Accounts]
--
CREATE FULLTEXT INDEX
  ON [SCrm].[Accounts]([Name] LANGUAGE 1033)
  KEY INDEX [PK_Accounts]
  ON [AccountName]
  WITH CHANGE_TRACKING AUTO, STOPLIST Honorifics
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO