SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SOffice].[OutlookEmailsUpsert]
    (
        @TargetObjectGuid UNIQUEIDENTIFIER,
        @Mailbox NVARCHAR(250),
        @MessageID NVARCHAR(250),
        @ConversationID NVARCHAR(250),
        @FromAddress NVARCHAR(500),
        @ToAddresses NVARCHAR(4000),
        @Subject NVARCHAR(2000),
        @SentDateTime DATETIME2,
        @DeliveryReceiptRequested BIT,
        @DeliveryReceiptReceived BIT,
        @ReadReceiptRequested BIT,
        @ReadReceiptReceived BIT,
        @DoNotFile BIT,
        @IsReadyToFile BIT,
        @FiledDateTime DATETIME2,
        @FilingLocationUrl NVARCHAR(500),
        @Description NVARCHAR(4000) = '',
        @Guid UNIQUEIDENTIFIER
    )
AS
BEGIN
    DECLARE @TargetObjectId                 INT,
            @OEMailboxID                   INT,
            @OEConversationID              BIGINT,
            @OEFromAddressID               INT;

    SELECT  @TargetObjectId = ID
    FROM    SOffice.TargetObjects
    WHERE   (Guid = @TargetObjectGuid);

    SELECT  @OEMailboxID = ID
    FROM    SOffice.OutlookEmailMailboxes
    WHERE   (Name = @Mailbox);

    IF (@@ROWCOUNT = 0)
    BEGIN
        INSERT  SOffice.OutlookEmailMailboxes
                (Guid, RowStatus, Name)
        VALUES
                (
                    NEWID (),    -- Guid - uniqueidentifier
                    1,           -- RowStatus - tinyint
                    @Mailbox     -- Name - nvarchar(250)
                );

        SELECT  @OEMailboxID = SCOPE_IDENTITY ();
    END;

    SELECT  @OEConversationID = ID
    FROM    SOffice.OutlookEmailConversations
    WHERE   (ConversationID = @ConversationID);

    IF (@@ROWCOUNT = 0)
    BEGIN
        INSERT  SOffice.OutlookEmailConversations
                (Guid, RowStatus, ConversationID)
        VALUES
                (
                    NEWID (),             -- Guid - uniqueidentifier
                    1,                    -- RowStatus - tinyint
                    @ConversationID       -- ConversationID - nvarchar(250)
                );

        SELECT  @OEConversationID = SCOPE_IDENTITY ();
    END;

    SELECT  @OEFromAddressID = ID
    FROM    SOffice.OutlookEmailFromAddresses
    WHERE   (Address = @FromAddress);

    IF (@@ROWCOUNT = 0)
    BEGIN
        INSERT  SOffice.OutlookEmailFromAddresses
                (Guid, RowStatus, Address)
        VALUES
                (
                    NEWID (),         -- Guid - uniqueidentifier
                    1,                -- RowStatus - tinyint
                    @FromAddress      -- Address - nvarchar(500)
                );

        SELECT  @OEFromAddressID = SCOPE_IDENTITY ();
    END;

    IF (NOT EXISTS
     (
         SELECT 1
         FROM    SOffice.OutlookEmails
         WHERE   (Guid = @Guid)
     ))
    BEGIN
        INSERT  SOffice.OutlookEmails
                (Guid,
                 RowStatus,
                 TargetObjectID,
                 OutlookEmailMailboxID,
                 MessageID,
                 OutlookEmailConversationId,
                 OutlookEmailFromAddressID,
                 ToAddresses,
                 Subject,
                 SentDateTime,
                 DeliveryReceiptRequested,
                 DeliveryReceiptReceived,
                 ReadReceiptRequested,
                 ReadReceiptReceived,
                 DoNotFile,
                 IsReadyToFile,
                 FiledDateTime,                 
                 FilingLocationUrl,
                 Description)
        VALUES
                (
                    @Guid,                           -- Guid - uniqueidentifier
                    1,                               -- RowStatus - tinyint
                    @TargetObjectId,                 -- TargetObjectID - int
                    @OEMailboxID,                    -- OutlookEmailMailboxID - int
                    @MessageID,                      -- MessageID - nvarchar(250)
                    @OEConversationID,               -- OutlookEmailConversationId - bigint
                    @OEFromAddressID,                -- OutlookEmailFromAddressID - int
                    @ToAddresses,                    -- ToAddresses - nvarchar(4000)
                    @Subject,                        -- Subject - nvarchar(2000)
                    @SentDateTime,                   -- SentDateTime - datetime2
                    @DeliveryReceiptRequested,       -- DeliveryReceiptRequested - bit
                    @DeliveryReceiptReceived,        -- DeliveryReceiptReceived - bit
                    @ReadReceiptRequested,           -- ReadReceiptRequested - bit
                    @ReadReceiptReceived,            -- ReadReceiptReceived - bit
                    @DoNotFile,                      -- DoNotFile - bit
                    @IsReadyToFile,                  -- IsReadyToFile - bit
                    @FiledDateTime,                  -- FiledDateTime - datetime2                    
                    @FilingLocationUrl,              -- FilingLocationUrl - nvarchar(500)
                    @Description                     -- Description - nvarchar(4000)
                );
    END;
    ELSE
    BEGIN
        UPDATE  SOffice.OutlookEmails
        SET     TargetObjectID = @TargetObjectId,
                OutlookEmailMailboxID = @OEMailboxID,
                MessageID = @MessageID,
                OutlookEmailConversationId = @OEConversationID,
                OutlookEmailFromAddressID = @OEFromAddressID,
                ToAddresses = @ToAddresses,
                Subject = @Subject,
                SentDateTime = @SentDateTime,
                DeliveryReceiptRequested = @DeliveryReceiptRequested,
                DeliveryReceiptReceived = @DeliveryReceiptReceived,
                ReadReceiptRequested = @ReadReceiptRequested,
                ReadReceiptReceived = @ReadReceiptReceived,
                DoNotFile = @DoNotFile,
                IsReadyToFile = @IsReadyToFile,
                FiledDateTime = @FiledDateTime,
                FilingLocationUrl = @FilingLocationUrl,
                Description = @Description
        WHERE   (Guid = @Guid);
    END;
END;
GO