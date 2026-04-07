SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SFin].[tvf_TransactionAllocations] 
(
    @UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
              --WITH SCHEMABINDING
AS
RETURN 
SELECT  ta.ID,
		ta.RowStatus,
		ta.RowVersion,
		ta.Guid,
		st.Number AS SourceTransationNumber,
		st.Date AS SourceTransactionDate,
		tt.Number AS TargetTransactionNumber,
		tt.Date AS TargetTransactionDate,
		ta.AllocatedAmount
FROM    SFin.TransactionAllocations ta 
JOIN	SFin.Transactions st ON (st.ID = ta.SourceTransactionID)
JOIN	SFin.Transactions tt ON (tt.ID = ta.TargetTransactionID)
WHERE   (ta.RowStatus  NOT IN (0, 254))
	AND	(ta.Id > 0)
	AND	((st.Guid = @ParentGuid) OR (tt.Guid = @ParentGuid))
GO