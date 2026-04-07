PRINT (N'Create table [dbo].[script_history]')
GO
CREATE TABLE [dbo].[script_history] (
  [script_name] [nvarchar](255) NOT NULL,
  [executed_at] [datetime] NOT NULL DEFAULT (getdate())
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_script_history] on table [dbo].[script_history]')
GO
ALTER TABLE [dbo].[script_history] WITH NOCHECK
  ADD CONSTRAINT [PK_script_history] PRIMARY KEY CLUSTERED ([script_name]) WITH (FILLFACTOR = 80)
GO