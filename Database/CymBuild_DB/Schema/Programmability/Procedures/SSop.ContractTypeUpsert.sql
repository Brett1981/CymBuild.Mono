SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[ContractTypeUpsert]
(
    @Guid UNIQUEIDENTIFIER,
    @Code NVARCHAR(20),
	@Name NVARCHAR(250),
	@IsActive BIT
)
AS
BEGIN
    DECLARE @IsInsert BIT

    EXEC SCore.UpsertDataObject 
         @Guid = @Guid,
         @SchemeName = N'SSop',
         @ObjectName = N'ContractTypes',
         @IsInsert = @IsInsert OUTPUT

    IF (@IsInsert = 1)
    BEGIN
        INSERT SSop.ContractTypes
               (RowStatus, Guid, Code, Name, IsActive)
        VALUES (
					1, 
					@Guid, 
					@Code, 
					@Name,
					@IsActive
				)
    END
    ELSE
    BEGIN
        UPDATE SSop.ContractTypes
        SET    
			Code= @Code,
			Name= @Name,
			IsActive= @IsActive
        WHERE  
			Guid= @Guid
    END
END
GO