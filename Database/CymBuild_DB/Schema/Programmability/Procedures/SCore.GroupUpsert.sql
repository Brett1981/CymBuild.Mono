SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[GroupUpsert]
(
    @Name        NVARCHAR(250),
    @Code        NVARCHAR(50),
    @DirectoryId NVARCHAR(100),
    @Source      NVARCHAR(250),      -- NEW
    @Guid        UNIQUEIDENTIFIER OUT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsInsert BIT = 0;

    EXEC SCore.UpsertDataObject
        @Guid       = @Guid,
        @SchemeName = N'SCore',
        @ObjectName = N'Groups',
        @IsInsert   = @IsInsert OUTPUT;

    IF (@IsInsert = 1)
    BEGIN
        INSERT INTO SCore.Groups
        (
            RowStatus,
            Guid,
            DirectoryId,
            Code,
            Name,
            Source
        )
        VALUES
        (
            1,
            @Guid,
            @DirectoryId,
            @Code,
            @Name,
            ISNULL(@Source, '')
        );
    END;
    ELSE
    BEGIN
        UPDATE SCore.Groups
        SET
            Name        = @Name,
            DirectoryId = @DirectoryId,
            Code        = @Code,
            Source      = ISNULL(@Source, '')
        WHERE Guid = @Guid;
    END;
END;
GO