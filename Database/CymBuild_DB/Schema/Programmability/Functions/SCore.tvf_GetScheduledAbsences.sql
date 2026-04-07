SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_GetScheduledAbsences]
(
    @UserId INT,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        NA.ID,
        NAT.Name AS Name,
        NA.StartTime,
        NA.EndTime,
        NA.Guid,
        NA.RowStatus,
        NA.RowVersion,
		NA.TeamGroupId,
		NA.MemberIdentityId,
		NA.AbsenceTypeID
    FROM 
        SCore.NonActivityEvents AS NA
	LEFT JOIN SCore.NonActivityTypes AS NAT ON (NA.AbsenceTypeID = NAT.ID)
    WHERE 
        NA.MemberIdentityId = @UserId AND
		NA.RowStatus NOT IN (0, 254) AND
        (@StartDate IS NULL OR NA.StartTime >= @StartDate) AND
        (@EndDate IS NULL OR NA.StartTime < @EndDate)
);
GO