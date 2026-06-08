SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create procedure [SSop].[ProjectsUpsert]')
GO
CREATE PROCEDURE [SSop].[ProjectsUpsert]
    @ExternalReference NVARCHAR(50),
    @ProjectDescription NVARCHAR(MAX),
    @ProjectProjectedStartDate DATE,
    @ProjectProjectedEndDate DATE,
    @ProjectCompleted DATE,
    @IsSubjectToNDA BIT,
    @DataClassificationGuid UNIQUEIDENTIFIER,
    @SecurityClassificationGuid UNIQUEIDENTIFIER,
    @Guid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsInsert BIT = 0,
            @ProjectID INT = -1,
            @DataClassificationID INT = -1,
            @SecurityClassificationID INT = -1;

    SELECT @DataClassificationID = dc.ID
    FROM SCore.DataClassifications AS dc
    WHERE dc.Guid = @DataClassificationGuid
      AND dc.RowStatus NOT IN (0,254);

    SELECT @SecurityClassificationID = sc.ID
    FROM SCore.SecurityClassifications AS sc
    WHERE sc.Guid = @SecurityClassificationGuid
      AND sc.RowStatus NOT IN (0,254);

    SET @DataClassificationID = ISNULL(@DataClassificationID, -1);
    SET @SecurityClassificationID = ISNULL(@SecurityClassificationID, -1);

    EXEC SCore.UpsertDataObject
        @Guid = @Guid,
        @SchemeName = N'SSop',
        @ObjectName = N'Projects',
        @IncludeDefaultSecurity = 0,
        @IsInsert = @IsInsert OUTPUT;

    IF (@IsInsert = 1)
    BEGIN
        INSERT SSop.Projects
        (
            RowStatus,
            Guid,
            Number,
            ExternalReference,
            ProjectDescription,
            ProjectProjectsStartDate,
            ProjectProjectedEndDate,
            ProjectCompleted,
            IsSubjectToNDA,
            DataClassificationID,
            SecurityClassificationID
        )
        VALUES
        (
            0,
            @Guid,
            0,
            @ExternalReference,
            @ProjectDescription,
            @ProjectProjectedStartDate,
            @ProjectProjectedEndDate,
            @ProjectCompleted,
            @IsSubjectToNDA,
            @DataClassificationID,
            @SecurityClassificationID
        );

        SELECT @ProjectID = CONVERT(INT, SCOPE_IDENTITY());
    END;
    ELSE
    BEGIN
        UPDATE SSop.Projects
        SET ExternalReference = @ExternalReference,
            ProjectDescription = @ProjectDescription,
            ProjectProjectsStartDate = @ProjectProjectedStartDate,
            ProjectProjectedEndDate = @ProjectProjectedEndDate,
            ProjectCompleted = @ProjectCompleted,
            IsSubjectToNDA = @IsSubjectToNDA,
            DataClassificationID = @DataClassificationID,
            SecurityClassificationID = @SecurityClassificationID
        WHERE Guid = @Guid;

        SELECT @ProjectID = p.ID
        FROM SSop.Projects AS p
        WHERE p.Guid = @Guid
          AND p.RowStatus NOT IN (0,254);
    END;

    IF (@IsInsert = 1)
    BEGIN
        DECLARE @ProjectNumber INT;

        SELECT @ProjectNumber = NEXT VALUE FOR SSop.ProjectNumber;

        UPDATE SSop.Projects
        SET Number = @ProjectNumber,
            RowStatus = 1
        WHERE ID = @ProjectID;
    END;

    -------------------------------------------------------------------------
    -- CYB-340
    -- Project is the master classification record once saved.
    -- Push the selected classification to all active linked Quotes and Jobs.
    -------------------------------------------------------------------------

    UPDATE q
    SET q.DataClassificationID = @DataClassificationID,
        q.SecurityClassificationID = @SecurityClassificationID
    FROM SSop.Quotes AS q
    WHERE q.ProjectId = @ProjectID
      AND q.RowStatus NOT IN (0,254);

    UPDATE j
    SET j.DataClassificationID = @DataClassificationID,
        j.SecurityClassificationID = @SecurityClassificationID
    FROM SJob.Jobs AS j
    WHERE j.ProjectId = @ProjectID
      AND j.RowStatus NOT IN (0,254);
END;
GO