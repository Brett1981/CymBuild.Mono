BEGIN TRANSACTION;

/*
	Quotes -> Invoicing Tab -> Sets the "Quote Invoicing Schedule" gvd to be the first one displayed. 
*/


DECLARE @GridDefinitionID INT;

SELECT @GridDefinitionID = gd.ID
FROM SUserInterface.GridViewDefinitions AS root_hobt
JOIN SUserInterface.GridDefinitions AS gd ON (gd.ID = root_hobt.GridDefinitionId )
WHERE gd.Guid = '10207cf4-424a-4b22-a463-68ef6a9e25c0';

 
 UPDATE  SUserInterface.GridViewDefinitions
 SET DisplayOrder = 0
 WHERE 
	Code = N'QUOTEINVOICESCHEDULE'
AND GridDefinitionId = @GridDefinitionID

--SELECT root_hobt.*
--FROM SUserInterface.GridViewDefinitions AS root_hobt
--JOIN SUserInterface.GridDefinitions AS gd ON (gd.ID = root_hobt.GridDefinitionId )
--WHERE gd.Guid = '10207cf4-424a-4b22-a463-68ef6a9e25c0'
--ORDER BY root_hobt.DisplayOrder

COMMIT;