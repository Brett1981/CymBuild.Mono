SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create view [SAi].[vw_AssistantAdminDashboard]')
GO

CREATE VIEW [SAi].[vw_AssistantAdminDashboard]
AS
SELECT (
		SELECT COUNT(1)
		FROM SAi.AssistantConversations AS c
		WHERE c.RowStatus NOT IN (
				0
				,254
				)
		) AS TotalConversations
	,(
		SELECT COUNT(1)
		FROM SAi.AssistantMessages AS m
		WHERE m.RowStatus NOT IN (
				0
				,254
				)
		) AS TotalMessages
	,(
		SELECT COUNT(1)
		FROM SAi.AssistantKnowledgeItems AS ki
		WHERE ki.RowStatus NOT IN (
				0
				,254
				)
			AND ki.IsPublished = 1
		) AS PublishedKnowledgeItems
	,(
		SELECT COUNT(1)
		FROM SAi.AssistantWorkflowTemplates AS wt
		WHERE wt.RowStatus NOT IN (
				0
				,254
				)
			AND wt.IsPublished = 1
		) AS PublishedWorkflowTemplates
	,(
		SELECT COUNT(1)
		FROM SAi.AssistantFeedback AS f
		WHERE f.RowStatus NOT IN (
				0
				,254
				)
			AND f.FeedbackCode = N'unhelpful'
		) AS UnhelpfulFeedbackCount
	,(
		SELECT COUNT(1)
		FROM SAi.AssistantContentGaps AS g
		WHERE g.RowStatus NOT IN (
				0
				,254
				)
			AND g.StatusCode IN (
				N'new'
				,N'reviewing'
				,N'assigned'
				)
		) AS OpenContentGapCount;
GO