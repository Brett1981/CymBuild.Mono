SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[FormatAddress]
(
@Name NVARCHAR(100),
@Number NVARCHAR(50),
@Addr1 NVARCHAR(50),
@Addr2 NVARCHAR(50),
@Addr3 NVARCHAR(50),
@Town NVARCHAR(50),
@County NVARCHAR(50),
@PostCode NVARCHAR(10),
@Seperator NVARCHAR(10)
)
RETURNS NVARCHAR(600) 
               --WITH SCHEMABINDING
AS  
BEGIN

	DECLARE @Addr nvarchar(600)
	SET @Addr = ''

	IF  RTRIM(LTRIM(ISNULL(@Name,''))) > '' 
	BEGIN
		SET @Addr = @Addr + @Name + @Seperator 
	END

	IF RTRIM(LTRIM(ISNULL(@Number,''))) > '' 
	BEGIN
		SET @Addr = @Addr + @Number + ' '
	END

	IF RTRIM(LTRIM(ISNULL(@Addr1,''))) > '' 
	BEGIN
		SET @Addr = @Addr + @Addr1 + @Seperator
	END

	IF RTRIM(LTRIM(ISNULL(@Addr2,''))) > '' 
	BEGIN
		SET @Addr = @Addr + @Addr2 + @Seperator
	END

	IF RTRIM(LTRIM(ISNULL(@Addr3,''))) > '' 
	BEGIN
		SET @Addr = @Addr + @Addr3 + @Seperator 
	END

	IF RTRIM(LTRIM(ISNULL(@Town,''))) > '' 
	BEGIN
		SET @Addr = @Addr + @Town + @Seperator 
	END

	IF RTRIM(LTRIM(ISNULL(@County,''))) > '' 
	BEGIN
		SET @Addr = @Addr + @County + @Seperator 
	END

	IF RTRIM(LTRIM(ISNULL(@PostCode,''))) > '' 
	BEGIN
		SET @Addr = @Addr + @PostCode + @Seperator
	END

	IF LEN(@Addr) > LEN(@Seperator)
	BEGIN
	    SET @Addr = LTRIM(@Addr)
		SET @Addr = LEFT(@Addr,LEN(@Addr) - LEN(@Seperator))
	END

	RETURN @Addr

END
GO