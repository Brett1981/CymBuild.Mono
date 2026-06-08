/* CYB-317 Stage 1 - corrected
   Quote-level JobTypeId.
   Legacy/imported quotes without an EnquiryService are allowed to remain NULL.
*/

SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    EXEC sys.sp_set_session_context
        @key = N'S_disable_triggers',
        @value = 1;

    IF COL_LENGTH(N'SSop.Quotes', N'JobTypeId') IS NULL
    BEGIN
        ALTER TABLE SSop.Quotes
        ADD JobTypeId INT NULL;
    END;

    UPDATE q
    SET q.JobTypeId = es.JobTypeId
    FROM SSop.Quotes AS q
    JOIN SSop.EnquiryServices AS es
        ON es.ID = q.EnquiryServiceID
    JOIN SJob.JobTypes AS jt
        ON jt.ID = es.JobTypeId
    WHERE q.JobTypeId IS NULL
      AND q.ID <> -1
      AND q.RowStatus NOT IN (0, 254)
      AND es.RowStatus NOT IN (0, 254)
      AND jt.RowStatus NOT IN (0, 254);

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys AS fk
        WHERE fk.name = N'FK_Quotes_JobTypes'
          AND fk.parent_object_id = OBJECT_ID(N'SSop.Quotes')
    )
    BEGIN
        ALTER TABLE SSop.Quotes WITH CHECK
        ADD CONSTRAINT FK_Quotes_JobTypes
            FOREIGN KEY (JobTypeId)
            REFERENCES SJob.JobTypes (ID);
    END;

    EXEC sys.sp_set_session_context
        @key = N'S_disable_triggers',
        @value = NULL;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    EXEC sys.sp_set_session_context
        @key = N'S_disable_triggers',
        @value = NULL;

    THROW;
END CATCH;
GO