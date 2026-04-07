SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[Json_GetDataProperties]
(	
	@Json NVARCHAR(MAX)
)
RETURNS TABLE
AS
RETURN 
(

SELECT	EntityPropertyGuid,
			IsInvalid,
			IsEnabled,
			IsRestricted,
			IsHidden,
			StringValue,
			DoubleValue,
			SmallIntValue,
			IntValue,
			BigIntValue,
			BitValue,
			DateTimeValue,
			BytesValue
FROM
			OPENJSON(@Json, '$.DataProperties')
			WITH (EntityPropertyGuid UNIQUEIDENTIFIER,
			StringValue NVARCHAR(MAX),
			DoubleValue DECIMAL,
			SmallIntValue SMALLINT,
			IntValue INT,
			BigIntValue BIGINT,
			BitValue BIT,
			DateTimeValue DATETIME2,
			BytesValue VARBINARY(MAX),
			IsInvalid BIT,
			IsEnabled BIT,
			IsRestricted BIT,
			IsHidden BIT)
)
GO