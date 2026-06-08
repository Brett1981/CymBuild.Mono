BEGIN TRANSACTION;

--Create InvoicePaymentStatus first.
DECLARE @HobtList [SCore].[TwoStringBitIndexedList]
INSERT	@HobtList (StringValue1, StringValue2, BitValue1)  /* Schema, Table, IsMainHobt */ 
VALUES	(N'SFin', N'InvoicePaymentStatus', 1)

exec score.UpsertEntityTypeFromSchema @HobtList = @HobtList

COMMIT TRANSACTION;


SET NOCOUNT ON;
 
BEGIN TRY
    BEGIN TRAN;
 
DECLARE @EntityTypeId INT;
 
/* Attempt auto-detect */
SELECT TOP (1)
    @EntityTypeId = et.ID
FROM SCore.EntityTypes AS et
WHERE et.Name LIKE '%Invoice Payment Status%'
  AND et.RowStatus NOT IN (0,254);
 
IF @EntityTypeId IS NULL
BEGIN
    RAISERROR('EntityTypeId for InvoicePaymentStatus not found. Please confirm SCore.EntityTypes.',16,1);
    ROLLBACK TRAN;
    RETURN;
END;
 
/* ============================================================
   Seed table variable
   ============================================================ */
 
DECLARE @Rows TABLE
(
    Guid UNIQUEIDENTIFIER,
    Name NVARCHAR(100)
);
 
INSERT INTO @Rows (Guid, Name)
VALUES
('C711A66C-677A-4D3A-866B-5B1B86C81639', N'Overdue'),
('C7F8233A-D729-4B11-95BE-970609CA0334', N'Paid'),
('1EE794BD-5BBA-477F-BA11-7BEBEF908B99', N'Pending');
 
/* ============================================================
   Ensure SCore.DataObjects
   ============================================================ */
 
INSERT INTO SCore.DataObjects
(
    Guid,
    EntityTypeId,
    RowStatus
)
SELECT
    r.Guid,
    @EntityTypeId,
    1
FROM @Rows r
WHERE NOT EXISTS
(
    SELECT 1
    FROM SCore.DataObjects d
    WHERE d.Guid = r.Guid
);
 
/* ============================================================
   Insert missing statuses
   ============================================================ */
 
INSERT INTO SFin.InvoicePaymentStatus
(
    Guid,
    Name,
    RowStatus
)
SELECT
    r.Guid,
    r.Name,
    1
FROM @Rows r
WHERE NOT EXISTS
(
    SELECT 1
    FROM SFin.InvoicePaymentStatus s
    WHERE s.Guid = r.Guid
);
 
/* ============================================================
   Revive soft deleted rows if required
   ============================================================ */
 
UPDATE s
SET
    s.Name = r.Name,
    s.RowStatus = 1
FROM SFin.InvoicePaymentStatus s
JOIN @Rows r
    ON r.Guid = s.Guid
WHERE s.RowStatus IN (0,254);
 
/* ============================================================
   Results
   ============================================================ */
 
SELECT
    ID,
    Guid,
    Name,
    RowStatus
FROM SFin.InvoicePaymentStatus
WHERE RowStatus NOT IN (0,254)
ORDER BY Name;
 
COMMIT TRAN;
PRINT 'InvoicePaymentStatus rows seeded successfully.';
 
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;
 
    THROW;
END CATCH;

