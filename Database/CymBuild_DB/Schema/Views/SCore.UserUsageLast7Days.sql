SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create view [SCore].[UserUsageLast7Days]')
GO
CREATE VIEW [SCore].[UserUsageLast7Days]
AS
WITH [ReportingPeriod] AS
(
    SELECT
        DATEADD(DAY, -6, CONVERT(date, GETDATE()))  AS [CurrentPeriodStart],
        DATEADD(DAY,  1, CONVERT(date, GETDATE()))  AS [CurrentPeriodEnd],
        DATEADD(DAY, -13, CONVERT(date, GETDATE())) AS [PreviousPeriodStart]
),
[UserUsage] AS
(
    SELECT
        sul.[UserGuid],

        COUNT
        (
            CASE
                WHEN sul.[Accessed] >= rp.[CurrentPeriodStart]
                 AND sul.[Accessed] <  rp.[CurrentPeriodEnd]
                THEN 1
            END
        ) AS [UsageCountLast7Days],

        COUNT
        (
            CASE
                WHEN sul.[Accessed] >= rp.[PreviousPeriodStart]
                 AND sul.[Accessed] <  rp.[CurrentPeriodStart]
                THEN 1
            END
        ) AS [UsageCountPrevious7Days],

        COUNT
        (
            DISTINCT CASE
                WHEN sul.[Accessed] >= rp.[CurrentPeriodStart]
                 AND sul.[Accessed] <  rp.[CurrentPeriodEnd]
                THEN CONVERT(date, sul.[Accessed])
            END
        ) AS [ActiveDaysLast7Days],

        COUNT
        (
            DISTINCT CASE
                WHEN sul.[Accessed] >= rp.[CurrentPeriodStart]
                 AND sul.[Accessed] <  rp.[CurrentPeriodEnd]
                THEN sul.[FeatureName]
            END
        ) AS [FeaturesUsedLast7Days],

        MIN
        (
            CASE
                WHEN sul.[Accessed] >= rp.[CurrentPeriodStart]
                 AND sul.[Accessed] <  rp.[CurrentPeriodEnd]
                THEN sul.[Accessed]
            END
        ) AS [FirstAccessedLast7Days],

        MAX
        (
            CASE
                WHEN sul.[Accessed] >= rp.[CurrentPeriodStart]
                 AND sul.[Accessed] <  rp.[CurrentPeriodEnd]
                THEN sul.[Accessed]
            END
        ) AS [LastAccessedLast7Days]
    FROM [SCore].[SystemUsageLog] AS sul
    CROSS JOIN [ReportingPeriod] AS rp
    WHERE sul.[Accessed] >= rp.[PreviousPeriodStart]
      AND sul.[Accessed] <  rp.[CurrentPeriodEnd]
    GROUP BY
        sul.[UserGuid]
)
SELECT
    i.[FullName]                                      AS [UserName],
    i.[Guid]                                          AS [UserGuid],
    uu.[UsageCountLast7Days],
    uu.[ActiveDaysLast7Days],
    uu.[FeaturesUsedLast7Days],
    CONVERT
    (
        decimal(18, 2),
        uu.[UsageCountLast7Days] / 7.0
    )                                                 AS [AverageDailyUsage],
    uu.[FirstAccessedLast7Days],
    uu.[LastAccessedLast7Days],
    uu.[UsageCountPrevious7Days],
    CONVERT
    (
        decimal(18, 2),
        CASE
            WHEN uu.[UsageCountPrevious7Days] = 0
                THEN NULL
            ELSE
                (
                    (uu.[UsageCountLast7Days]
                     - uu.[UsageCountPrevious7Days]) * 100.0
                ) / uu.[UsageCountPrevious7Days]
        END
    )                                                 AS [UsageChangePercentage],
    CASE
        WHEN uu.[UsageCountPrevious7Days] = 0
         AND uu.[UsageCountLast7Days] > 0
            THEN N'New usage'
        WHEN uu.[UsageCountLast7Days]
             > uu.[UsageCountPrevious7Days]
            THEN N'Increased'
        WHEN uu.[UsageCountLast7Days]
             < uu.[UsageCountPrevious7Days]
            THEN N'Decreased'
        ELSE N'No change'
    END                                               AS [UsageTrend]
FROM [UserUsage] AS uu
JOIN [SCore].[Identities] AS i
    ON i.[Guid] = uu.[UserGuid]
WHERE uu.[UsageCountLast7Days] > 0;
GO