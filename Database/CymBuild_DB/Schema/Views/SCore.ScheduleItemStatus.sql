SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SCore].[ScheduleItemStatus]
                --WITH SCHEMABINDING
AS
SELECT  [ID],
        [Name],
        [Colour]
FROM    SJob.ActivityStatus 
WHERE   (RowStatus NOT IN (0, 254))
GO