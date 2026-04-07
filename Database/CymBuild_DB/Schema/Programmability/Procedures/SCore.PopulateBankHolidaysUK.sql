SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[PopulateBankHolidaysUK]
    @StartYear INT,
    @EndYear INT
AS
BEGIN
    SET NOCOUNT ON;
   
    DECLARE @CurrentYear INT = @StartYear;
    
    WHILE @CurrentYear <= @EndYear
    BEGIN
        DECLARE @EasterSunday DATE = SCore.tvf_GetEasterSunday(@CurrentYear);
        
        -- UK-wide holidays
        INSERT INTO SCore.BankHolidaysUK
        SELECT
            Date = DATEADD(HOUR, 12, CAST(d AS DATETIME)),
            DayName = DATENAME(WEEKDAY, d),
            MonthName = DATENAME(MONTH, d),
			YearInWords = DATEPART(YYYY, d)            ,
            FormattedDate = (CONVERT(VARCHAR(10), d, 103) + ' 12:00:00'),
            HolidayName = hn,
            IsBankHoliday = 1,
            Region = 'UK',
            FiscalQuarter = DATEPART(QUARTER, d),
            FiscalYear = @CurrentYear,
            DayOfYear = DATEPART(DAYOFYEAR, d),
            WeekOfYear = DATEPART(WEEK, d)
        FROM (
            -- New Year's Day
            SELECT d = CASE WHEN DATEPART(WEEKDAY, DATEFROMPARTS(@CurrentYear, 1, 1)) IN (1,7)
                        THEN DATEADD(DAY, CASE DATEPART(WEEKDAY, DATEFROMPARTS(@CurrentYear, 1, 1)) WHEN 7 THEN 2 ELSE 1 END, DATEFROMPARTS(@CurrentYear, 1, 1))
                        ELSE DATEFROMPARTS(@CurrentYear, 1, 1) END,
                   hn = 'New Year''s Day'
            
            UNION ALL
            
            -- Good Friday
            SELECT DATEADD(DAY, -2, @EasterSunday), 'Good Friday'
            
            UNION ALL
            
            -- Easter Monday
            SELECT DATEADD(DAY, 1, @EasterSunday), 'Easter Monday'
            
            UNION ALL
            
            ---- Early May Bank Holiday (first Monday in May)
            --SELECT DATEADD(DAY, (1 - DATEPART(WEEKDAY, DATEFROMPARTS(@CurrentYear, 5, 1)) + 1) % 7, DATEFROMPARTS(@CurrentYear, 5, 1)), 'Early May Bank Holiday'

			-- Early May Bank Holiday (first Monday in May)
			SELECT DATEADD(DAY, (9 - DATEPART(WEEKDAY, DATEFROMPARTS(@CurrentYear, 5, 1))) % 7, DATEFROMPARTS(@CurrentYear, 5, 1)), 'Early May Bank Holiday'

            
            UNION ALL
            
            -- Spring Bank Holiday (last Monday in May)
            SELECT DATEADD(DAY, -((DATEPART(WEEKDAY, DATEFROMPARTS(@CurrentYear, 5, 31)) + 5) % 7), DATEFROMPARTS(@CurrentYear, 5, 31)), 'Spring Bank Holiday'

            
            UNION ALL
            
         

			-- Summer Bank Holiday (last Monday in August)
			SELECT DATEADD(DAY, -((DATEPART(WEEKDAY, DATEFROMPARTS(@CurrentYear, 8, 31)) + 5) % 7),  DATEFROMPARTS(@CurrentYear, 8, 31)),'Summer Bank Holiday'

            
            UNION ALL
            
           -- Christmas Day
			SELECT CASE 
					 WHEN DATEPART(WEEKDAY, DATEFROMPARTS(@CurrentYear, 12, 25)) = 7 -- Saturday
					   THEN DATEFROMPARTS(@CurrentYear, 12, 27) -- Monday after
					 WHEN DATEPART(WEEKDAY, DATEFROMPARTS(@CurrentYear, 12, 25)) = 1 -- Sunday
					   THEN DATEFROMPARTS(@CurrentYear, 12, 27) -- Monday after
					 ELSE DATEFROMPARTS(@CurrentYear, 12, 25) -- Actual day (25th)
				   END,
				   'Christmas Day'

            
            UNION ALL
            

			-- Boxing Day
			SELECT 
				CASE 
					WHEN DATEPART(WEEKDAY, DATEFROMPARTS(@CurrentYear, 12, 26)) = 7 -- Saturday
						THEN DATEFROMPARTS(@CurrentYear, 12, 28)  -- Monday
					WHEN DATEPART(WEEKDAY, DATEFROMPARTS(@CurrentYear, 12, 26)) = 1 -- Sunday
						THEN DATEFROMPARTS(@CurrentYear, 12, 28)  -- Monday (not Tuesday)
					ELSE DATEFROMPARTS(@CurrentYear, 12, 26)       -- Actual day
				END,
				'Boxing Day'


        ) uk_holidays
        WHERE NOT EXISTS (SELECT 1 FROM SCore.BankHolidaysUK WHERE Date = d)

        -- Regional holidays
		INSERT INTO SCore.BankHolidaysUK
		SELECT
			DATEADD(HOUR, 12, CAST(d AS DATETIME)),
			DATENAME(WEEKDAY, d),
			DATENAME(MONTH, d),
			DATENAME(YEAR, d),
			CONVERT(VARCHAR(10), d, 103) + ' 12:00:00',
			hn,
			1,
			Region,
			DATEPART(QUARTER, d),
			@CurrentYear,
			DATEPART(DAYOFYEAR, d),
			DATEPART(WEEK, d)
		FROM (
			-- Scotland: St Andrew's Day
			SELECT d = CASE 
						WHEN DATEPART(WEEKDAY, DATEFROMPARTS(@CurrentYear, 11, 30)) = 7  -- Saturday
							THEN DATEFROMPARTS(@CurrentYear, 12, 1)
						WHEN DATEPART(WEEKDAY, DATEFROMPARTS(@CurrentYear, 11, 30)) = 6  -- Friday
							THEN DATEADD(DAY, 2, DATEFROMPARTS(@CurrentYear, 11, 30))
						ELSE DATEFROMPARTS(@CurrentYear, 11, 30) 
					  END,
				   hn = 'St Andrew''s Day',
				   'Scotland' AS Region
    
			UNION ALL
    
			-- Northern Ireland: Battle of the Boyne
			SELECT DATEADD(DAY, 
						  (1 - DATEPART(WEEKDAY, DATEFROMPARTS(@CurrentYear, 7, 12)) + 1) % 7, 
						  DATEFROMPARTS(@CurrentYear, 7, 12)),
				   'Battle of the Boyne',
				   'Northern Ireland'
		) regional_holidays
		WHERE NOT EXISTS (SELECT 1 FROM SCore.BankHolidaysUK WHERE Date = d)

        SET @CurrentYear += 1
    END
END;

GO