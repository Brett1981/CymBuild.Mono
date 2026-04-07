SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SCore].[SystemUsageStatistics]
AS
SELECT		i.FullName		   AS Username,
			i.Guid			   AS UserGuid,
			ISNULL (   et.Name,
					   sul.FeatureName
				   )		   AS FeatureName,
			COUNT (1)		   AS UsageCount,
			COUNT (1) / (DATEDIFF(WEEK, FirstUsage.Accessed, LastUsage.Accessed) + 1) AS WeeklyAverage,
			LastUsage.Accessed AS LastAccessed,
			FirstUsage.Accessed AS FirstAccessed
FROM		SCore.SystemUsageLog AS sul
JOIN		SCore.Identities	 AS i ON (i.Guid = sul.UserGuid)
LEFT JOIN	SCore.EntityTypes	 AS et ON (CONVERT (   NVARCHAR(40),
													   et.Guid
												   ) = sul.FeatureName
										  )
OUTER APPLY
			(
				SELECT	sul2.Accessed
				FROM	SCore.SystemUsageLog AS sul2
				WHERE	(sul2.UserGuid	  = sul.UserGuid)
					AND (sul2.FeatureName = sul.FeatureName)
					AND (NOT EXISTS
					(
						SELECT	1
						FROM	SCore.SystemUsageLog AS sul3
						WHERE	(sul2.UserGuid	  = sul3.UserGuid)
							AND (sul2.FeatureName = sul3.FeatureName)
							AND (sul2.Accessed	  < sul3.Accessed)
					)
						)
			)					 AS LastUsage
OUTER APPLY
			(
				SELECT	sul2.Accessed
				FROM	SCore.SystemUsageLog AS sul2
				WHERE	(sul2.UserGuid	  = sul.UserGuid)
					AND (sul2.FeatureName = sul.FeatureName)
					AND (NOT EXISTS
					(
						SELECT	1
						FROM	SCore.SystemUsageLog AS sul3
						WHERE	(sul2.UserGuid	  = sul3.UserGuid)
							AND (sul2.FeatureName = sul3.FeatureName)
							AND (sul2.Accessed	  > sul3.Accessed)
					)
						)
			)					 AS FirstUsage
GROUP BY	i.FullName,
			i.Guid,
			sul.FeatureName,
			LastUsage.Accessed,
			FirstUsage.Accessed,
			et.Name;
GO