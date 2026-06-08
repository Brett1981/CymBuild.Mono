SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SOffice].[tvf_OutlookEmailFilingStats]')
GO
CREATE FUNCTION [SOffice].[tvf_OutlookEmailFilingStats]
(
    @Year int,
    @StartMonth int,
    @EndMonth int
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN
(
    WITH Filtered AS
    (
        SELECT
            oe.ID,
            oe.MessageID,
            oe.OutlookEmailConversationId,
            oe.FilingLocationUrl,
            oe.TargetObjectID,
            oe.Subject,
            oe.SearchSubject,
            oe.SentDateTime,
            oe.FiledDateTime,
            oe.IsFiled,
            oe.RowStatus
        FROM [SOffice].[OutlookEmails] oe
        WHERE
            oe.RowStatus = 1
            AND oe.SentDateTime IS NOT NULL
            AND YEAR(oe.SentDateTime) = @Year
            AND MONTH(oe.SentDateTime) BETWEEN @StartMonth AND @EndMonth
    ),
    Grouped AS
    (
        SELECT
            f.MessageID,
            f.OutlookEmailConversationId,
            f.FilingLocationUrl,
            COUNT(*) AS FiledRowCount,
            COUNT(DISTINCT f.TargetObjectID) AS DistinctTargetObjectCount,
            MIN(f.SentDateTime) AS FirstSentDateTime,
            MAX(f.SentDateTime) AS LastSentDateTime,
            MIN(f.FiledDateTime) AS FirstFiledDateTime,
            MAX(f.FiledDateTime) AS LastFiledDateTime
        FROM Filtered f
        GROUP BY
            f.MessageID,
            f.OutlookEmailConversationId,
            f.FilingLocationUrl
    ),
    MessageLocationStats AS
    (
        SELECT
            f.MessageID,
            COUNT(DISTINCT ISNULL(f.FilingLocationUrl, '')) AS DistinctLocationsPerMessage
        FROM Filtered f
        GROUP BY
            f.MessageID
    ),
    ConversationLocationStats AS
    (
        SELECT
            f.OutlookEmailConversationId,
            COUNT(DISTINCT ISNULL(f.FilingLocationUrl, '')) AS DistinctLocationsPerConversation
        FROM Filtered f
        GROUP BY
            f.OutlookEmailConversationId
    )
    SELECT
        g.MessageID,
        g.OutlookEmailConversationId,
        g.FilingLocationUrl,
        g.FiledRowCount,
        g.DistinctTargetObjectCount,
        g.FirstSentDateTime,
        g.LastSentDateTime,
        g.FirstFiledDateTime,
        g.LastFiledDateTime,
        mls.DistinctLocationsPerMessage,
        CASE
            WHEN mls.DistinctLocationsPerMessage > 1 THEN CAST(1 AS bit)
            ELSE CAST(0 AS bit)
        END AS IsMessageFiledToMultipleLocations,
        cls.DistinctLocationsPerConversation,
        CASE
            WHEN cls.DistinctLocationsPerConversation > 1 THEN CAST(1 AS bit)
            ELSE CAST(0 AS bit)
        END AS IsConversationFiledToMultipleLocations
    FROM Grouped g
    LEFT JOIN MessageLocationStats mls
        ON g.MessageID = mls.MessageID
    LEFT JOIN ConversationLocationStats cls
        ON g.OutlookEmailConversationId = cls.OutlookEmailConversationId
);
GO