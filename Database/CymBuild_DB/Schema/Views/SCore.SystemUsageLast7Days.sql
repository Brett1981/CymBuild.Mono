SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create or alter view [SCore].[SystemUsageLast7Days]')
GO

CREATE OR ALTER VIEW [SCore].[SystemUsageLast7Days]
AS
WITH [ReportingPeriod] AS
(
    SELECT
        DATEADD(DAY, -6, CONVERT(date, GETUTCDATE()))  AS [CurrentPeriodStart],
        DATEADD(DAY,  1, CONVERT(date, GETUTCDATE()))  AS [CurrentPeriodEnd],
        DATEADD(DAY, -13, CONVERT(date, GETUTCDATE())) AS [PreviousPeriodStart]
),
[UsageByUser] AS
(
    SELECT
        sul.[UserGuid],
        COUNT(CASE
                  WHEN sul.[Accessed] >= rp.[CurrentPeriodStart]
                   AND sul.[Accessed] <  rp.[CurrentPeriodEnd]
                  THEN 1
              END) AS [UsageCountLast7Days],
        COUNT(CASE
                  WHEN sul.[Accessed] >= rp.[PreviousPeriodStart]
                   AND sul.[Accessed] <  rp.[CurrentPeriodStart]
                  THEN 1
              END) AS [UsageCountPrevious7Days],
        COUNT(DISTINCT CASE
                           WHEN sul.[Accessed] >= rp.[CurrentPeriodStart]
                            AND sul.[Accessed] <  rp.[CurrentPeriodEnd]
                           THEN CONVERT(date, sul.[Accessed])
                       END) AS [ActiveDaysLast7Days],
        COUNT(DISTINCT CASE
                           WHEN sul.[Accessed] >= rp.[CurrentPeriodStart]
                            AND sul.[Accessed] <  rp.[CurrentPeriodEnd]
                           THEN sul.[FeatureName]
                       END) AS [FeaturesUsedLast7Days],
        MAX(CASE
                WHEN sul.[Accessed] >= rp.[CurrentPeriodStart]
                 AND sul.[Accessed] <  rp.[CurrentPeriodEnd]
                THEN sul.[Accessed]
            END) AS [LastAccessedLast7Days]
    FROM [SCore].[SystemUsageLog] AS sul
    CROSS JOIN [ReportingPeriod] AS rp
    WHERE sul.[Accessed] >= rp.[PreviousPeriodStart]
      AND sul.[Accessed] <  rp.[CurrentPeriodEnd]
    GROUP BY sul.[UserGuid]
)
SELECT
    i.[FullName]                                            AS [Username],
    i.[Guid]                                                AS [UserGuid],
    ISNULL(ubu.[UsageCountLast7Days], 0)                    AS [UsageCountLast7Days],
    ISNULL(ubu.[UsageCountPrevious7Days], 0)                AS [UsageCountPrevious7Days],
    ISNULL(ubu.[ActiveDaysLast7Days], 0)                    AS [ActiveDaysLast7Days],
    ISNULL(ubu.[FeaturesUsedLast7Days], 0)                  AS [FeaturesUsedLast7Days],
    ubu.[LastAccessedLast7Days],
    CASE
        WHEN ISNULL(ubu.[UsageCountPrevious7Days], 0) = 0
         AND ISNULL(ubu.[UsageCountLast7Days], 0) > 0 THEN N'New usage'
        WHEN ISNULL(ubu.[UsageCountLast7Days], 0) > ISNULL(ubu.[UsageCountPrevious7Days], 0) THEN N'Increased'
        WHEN ISNULL(ubu.[UsageCountLast7Days], 0) < ISNULL(ubu.[UsageCountPrevious7Days], 0) THEN N'Decreased'
        ELSE N'No change'
    END                                                     AS [UsageTrend]
FROM [SCore].[Identities] AS i
LEFT JOIN [UsageByUser] AS ubu
    ON ubu.[UserGuid] = i.[Guid]
WHERE i.[IsActive] = 1
  AND i.[RowStatus] <> 0
  AND i.[RowStatus] <> 254;
GO
