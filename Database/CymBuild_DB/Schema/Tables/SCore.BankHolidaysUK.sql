CREATE TABLE [SCore].[BankHolidaysUK] (
  [ID] [int] IDENTITY,
  [Date] [datetime] NULL,
  [DayName] [varchar](20) NULL,
  [MonthName] [varchar](20) NULL,
  [YearInWords] [varchar](9) NULL,
  [FormattedDate] [varchar](25) NULL,
  [HolidayName] [varchar](50) NULL,
  [IsBankHoliday] [bit] NULL,
  [Region] [varchar](20) NULL,
  [FiscalQuarter] [tinyint] NULL,
  [FiscalYear] [smallint] NULL,
  [DayOfYear] [smallint] NULL,
  [WeekOfYear] [tinyint] NULL
)
ON [PRIMARY]
GO