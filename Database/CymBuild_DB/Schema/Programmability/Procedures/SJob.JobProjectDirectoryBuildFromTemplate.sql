SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[JobProjectDirectoryBuildFromTemplate]
  (
    @JobID INT
  )
AS
  BEGIN
    DECLARE @ProjectDirectoryRolesEntityTypeId INT;

    SELECT
            @ProjectDirectoryRolesEntityTypeId = ID
    FROM
            SCore.EntityTypes et
    WHERE
            (Guid = '180c3f9b-31ef-481d-8c65-a69a02765116')

    DECLARE @ProjectDirectory TABLE
        (
          Guid                   UNIQUEIDENTIFIER,
          ProjectDirectoryRoleId INT
        )

    INSERT @ProjectDirectory
          (
            Guid,
            ProjectDirectoryRoleId
          )
        SELECT
                NEWID(),
                jtpdr.ProjectDirectoryRoleId
        FROM
                SJob.JobTypeProjectDirectoryRoles AS jtpdr
        JOIN
                SJob.JobTypes AS jt ON (jt.ID = jtpdr.JobTypeID)
        JOIN
                SJob.Jobs AS j ON (j.JobTypeID = jt.ID)
        WHERE
                (j.ID = @JobID)
                AND (NOT EXISTS
                (
                    SELECT
                            1
                    FROM
                            SJob.ProjectDirectory pd
                    WHERE
                            (pd.JobID = @JobID)
                            AND (pd.ProjectDirectoryRoleID = jtpdr.ProjectDirectoryRoleID)
                )
                )


    INSERT SCore.DataObjects
          (
            Guid,
            RowStatus,
            EntityTypeId
          )
        SELECT
                Guid,
                1,
                @ProjectDirectoryRolesEntityTypeId
        FROM
                @ProjectDirectory

    INSERT SJob.ProjectDirectory
          (
            RowStatus,
            Guid,
            JobID,
            ProjectDirectoryRoleID,
            AccountID,
            ContactID
          )
        SELECT
                1,
                Guid,
                @JobID,
                ProjectDirectoryRoleId,
                -1,
                -1
        FROM
                @ProjectDirectory

  END;
GO