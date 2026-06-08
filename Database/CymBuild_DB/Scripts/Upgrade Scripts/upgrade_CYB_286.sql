BEGIN TRANSACTION;

/*
	Hides the "Name" field for invoice schedules.
*/

DECLARE @NameFieldForInvoiceSchedulesGuid UNIQUEIDENTIFIER = 'e770228e-e75a-4a36-bd58-5ebdd365f234'

UPDATE SCore.EntityProperties
SET IsHidden = 1
WHERE Guid = @NameFieldForInvoiceSchedulesGuid;


--SELECT * FROM SCore.EntityProperties WHERE Guid = @NameFieldForInvoiceSchedulesGuid;


COMMIT;