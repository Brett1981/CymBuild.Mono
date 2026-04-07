SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[JSON_UpdateDataProperties]
	(
		@Json			NVARCHAR(MAX),
		@DataProperties SCore.[DataProperties] READONLY
	)
RETURNS NVARCHAR(MAX)
AS
	BEGIN
		DECLARE @RslJson	 NVARCHAR(MAX),
				@RslPropJson NVARCHAR(MAX)

		SELECT
				@RslJson = JSON_MODIFY(@Json, '$.DataProperties', '<<DataProperties>>')

		SELECT
				@RslPropJson =
				(
					SELECT
							*
					FROM
							@DataProperties
					FOR JSON AUTO
				)

		--SELECT
		--		@RslPropJson = LEFT(@RslPropJson, LEN(@RslPropJson) - 1)
		--SELECT
		--		@RslPropJson = RIGHT(@RslPropJson, LEN(@RslPropJson) - 1)



		-- Return the result of the function
		--RETURN REPLACE(@Json, '<<DataProperties>>', @RslPropJson)
		--RETURN REPLACE(@RslJson, '<<DataProperties>>', @RslPropJson)
		RETURN @RslPropJson
	END
GO