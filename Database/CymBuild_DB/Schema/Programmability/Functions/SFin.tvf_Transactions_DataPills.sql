SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE FUNCTION [SFin].[tvf_Transactions_DataPills]
(
    @Guid           UNIQUEIDENTIFIER,
    @Batched		BIT			
)
RETURNS @DataPills TABLE
(
    [ID]        [INT]        IDENTITY (1, 1) NOT NULL,
    [Label]     NVARCHAR(MAX) NOT NULL,
    [Class]     NVARCHAR(50) NOT NULL,
    [SortOrder] INT          NOT NULL
)
       --WITH SCHEMABINDING
AS
BEGIN

	IF(@Batched = 1)
		BEGIN
			INSERT @DataPills (Label, Class, SortOrder)
				VALUES (N'Batched', N'bg-orange', 1);
		END;
    RETURN;
END;
GO