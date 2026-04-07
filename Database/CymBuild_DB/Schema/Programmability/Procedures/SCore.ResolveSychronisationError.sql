SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[ResolveSychronisationError]
(
    @Guid UNIQUEIDENTIFIER,
    @Accept BIT
)
AS 
BEGIN 
    DECLARE @EntityPropertyID INT,
            @EntityPropertyName NVARCHAR(250),
            @EntitySchemaName NVARCHAR(250),
            @EntityTableName NVARCHAR(250),
            @QuoteValue BIT,
            @ProposedValue VARBINARY(max),
            @Stmt NVARCHAR(2000),
            @RecordID BIGINT

    SELECT      @EntityPropertyID = se.EntityPropertyID,
                @EntityPropertyName = ep.Name,
                @EntitySchemaName = eh.SchemaName,
                @EntityTableName = eh.ObjectName,
                @QuoteValue = edt.QuoteValue,
                @RecordID = se.RecordID
    FROM        [SCore].[SynchronisationErrors] se
    JOIN        [SCore].[EntityProperties] ep on (se.EntityPropertyID = ep.ID)
    JOIN        [SCore].[EntityHobts] eh on (ep.EntityHoBTID = eh.ID)
    JOIN        [SCore].[EntityDataTypes] edt on (ep.EntityDataTypeID = edt.ID)

    IF (@Accept = 1)
    BEGIN 
        SET @stmt = N'UPDATE [' + @EntitySchemaName + N'].[' + @EntityTableName + N'] 
        SET [' + @EntityPropertyName + N'] = ' + CASE WHEN @QuoteValue = 1 THEN N'''' ELSE N'' END + CONVERT(NVARCHAR(2000), @ProposedValue) + CASE WHEN @QuoteValue = 1 THEN N'''' ELSE N'' END + N'
        WHERE   [ID] = ' + CONVERT(NVARCHAR(2000), @RecordID)
    END

    UPDATE  [SCore].[SynchronisationErrors] 
    SET     IsResolved = 1
    WHERE   (Guid = @Guid) 
END
GO