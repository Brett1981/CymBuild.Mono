SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create view [SCore].[ScheduleItemTypes]')
GO
CREATE VIEW [SCore].[ScheduleItemTypes]
                    --WITH SCHEMABINDING
AS
SELECT  [ID],
        [Name],
        [Colour]
FROM    SJob.ActivityTypes 
WHERE   (RowStatus NOT IN (0, 254))
GO