BEGIN TRANSACTION

/*
	Hides the following fields for the monthly invoicing schedule record type: Test, Period.

*/

DECLARE @TestEntityPropGuid UNIQUEIDENTIFIER = '52CC6EB2-4302-4068-B73B-085A2BDF39B8';
DECLARE @PeriodEntityPropGuid UNIQUEIDENTIFIER = '19D958D0-33E2-4653-88F0-7DB15BB307DB';

UPDATE SCore.EntityProperties
SET IsHidden = 1
WHERE Guid IN (@TestEntityPropGuid, @PeriodEntityPropGuid);


COMMIT;