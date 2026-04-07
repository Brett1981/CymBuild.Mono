SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[SystemLogCreate]
	(	@DateTime DATETIME2,
		@Severity NVARCHAR(50),
		@Message NVARCHAR(MAX),
		@InnerMessage NVARCHAR(MAX),
		@StackTrace NVARCHAR(MAX),
		@ProcessGuid UNIQUEIDENTIFIER,
		@UserId INT,
		@ThreadId bigint
	)
AS
BEGIN
	INSERT	SCore.SystemLog
		 (Datetime, UserID, Severity, Message, InnerMessage, StackTrace, ProcessGuid, ThreadId)
	VALUES
		 (
			 ISNULL(@DateTime, GETUTCDATE()),		-- Datetime - datetime2(7)
			 ISNULL(@UserId, -1),		-- UserID - int
			 ISNULL(@Severity, N''),		-- Severity - nvarchar(50)
			 ISNULL(@Message, N''),		-- Message - nvarchar(max)
			 ISNULL(@InnerMessage, N''), -- InnerMessage - nvarchar(max)
			 ISNULL(@StackTrace, N''),	-- StackTrace - nvarchar(max)
			 ISNULL(@ProcessGuid, '00000000-0000-0000-0000-000000000000'),	-- ProcessGuid - uniqueidentifier
			 ISNULL(@ThreadId, 0)		-- ThreadId - bigint
		 );

END;
GO