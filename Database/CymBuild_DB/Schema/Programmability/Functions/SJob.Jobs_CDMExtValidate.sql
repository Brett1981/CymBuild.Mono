SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[Jobs_CDMExtValidate] 
(
    @Guid UNIQUEIDENTIFIER,
    @JobTypeGuid UNIQUEIDENTIFIER
)
RETURNS @ValidationResult TABLE 
(
    [ID] [int] IDENTITY(1,1) NOT NULL,
	[TargetGuid] [uniqueidentifier] NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
	[TargetType] [char](1) NOT NULL DEFAULT (''),
	[IsReadOnly] [bit] NOT NULL DEFAULT ((0)),
	[IsHidden] [bit] NOT NULL DEFAULT ((0)),
	[IsInvalid] [bit] NOT NULL DEFAULT ((0)),
	[IsInformationOnly] [BIT] NOT NULL DEFAULT((0)),
	[Message] [nvarchar](2000) NOT NULL DEFAULT ('')
)
AS
BEGIN
   DECLARE  @OrganisationUnitID INT,
            @JobTypeID INT,
            @EntityHoBTGuid UNIQUEIDENTIFIER

    SELECT  @JobTypeID = ID
    FROM    SJob.Jobs 
    WHERE   ([Guid] = @JobTypeGuid)


    IF (NOT EXISTS
        (
            SELECT  1
            FROM    SJob.Jobs j
            JOIN    SJob.JobTypes jt on (jt.ID = j.JobTypeID)
            WHERE   (jt.Guid = @JobTypeGuid)
                AND (jt.Name LIKE N'CDM -%')
                AND (j.Guid = @Guid)
        )
    )
    BEGIN 
        SELECT @EntityHoBTGuid = eh.Guid
        FROM    [SCore].[EntityHobtsV] eh
        WHERE   (eh.SchemaName = N'SJob')
            AND (eh.ObjectName = N'Jobs_CDMExt')

        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, [Message])
        VALUES (@EntityHoBTGuid, N'H', 0, 1, 0, N'')
    END

    RETURN
END

GO