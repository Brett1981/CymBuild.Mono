--
-- Inserting data into table SCore.WorkflowTransition
--
PRINT(N'Inserting data into table SCore.WorkflowTransition')
GO
SET IDENTITY_INSERT SCore.WorkflowTransition ON
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
IF NOT EXISTS (SELECT ID, RowStatus, Guid, WorkflowID, FromStatusID, ToStatusID, IsFinal, Enabled, SortOrder, Description FROM SCore.WorkflowTransition WITH (NOLOCK) WHERE ID = 399)
INSERT SCore.WorkflowTransition(ID, RowStatus, Guid, WorkflowID, FromStatusID, ToStatusID, IsFinal, Enabled, SortOrder, Description) VALUES (399, 1, '9a375745-da2c-4c70-b28f-14c0f1fdeeaa', 5, 50, 52, 0, 1, 0, N'Ready To Send')
IF NOT EXISTS (SELECT ID, RowStatus, Guid, WorkflowID, FromStatusID, ToStatusID, IsFinal, Enabled, SortOrder, Description FROM SCore.WorkflowTransition WITH (NOLOCK) WHERE ID = 400)
INSERT SCore.WorkflowTransition(ID, RowStatus, Guid, WorkflowID, FromStatusID, ToStatusID, IsFinal, Enabled, SortOrder, Description) VALUES (400, 1, 'b7f5c2f8-9919-4a02-b47e-b3dc6cabdfef', 5, 50, 59, 0, 1, 0, N'For Review')
IF NOT EXISTS (SELECT ID, RowStatus, Guid, WorkflowID, FromStatusID, ToStatusID, IsFinal, Enabled, SortOrder, Description FROM SCore.WorkflowTransition WITH (NOLOCK) WHERE ID = 401)
INSERT SCore.WorkflowTransition(ID, RowStatus, Guid, WorkflowID, FromStatusID, ToStatusID, IsFinal, Enabled, SortOrder, Description) VALUES (401, 1, 'ed513498-182d-4a86-a60e-0b09d65d0526', 4, 48, 2, 0, 1, 0, N'Ready For Quote')
IF NOT EXISTS (SELECT ID, RowStatus, Guid, WorkflowID, FromStatusID, ToStatusID, IsFinal, Enabled, SortOrder, Description FROM SCore.WorkflowTransition WITH (NOLOCK) WHERE ID = 402)
INSERT SCore.WorkflowTransition(ID, RowStatus, Guid, WorkflowID, FromStatusID, ToStatusID, IsFinal, Enabled, SortOrder, Description) VALUES (402, 1, 'fdc8c210-9319-48de-8ea4-0deec1ae7076', 4, 48, 66, 0, 0, 0, N'Declined To Quote')
GO
SET IDENTITY_INSERT SCore.WorkflowTransition OFF
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END

--
-- Reseed identity on SCore.WorkflowTransition
--
PRINT(N'Reseed identity on SCore.WorkflowTransition')
GO
DBCC CHECKIDENT('SCore.WorkflowTransition', RESEED, 402)
GO

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
--
-- Commit Transaction
--
PRINT(N'Commit Transaction')
GO
IF @@TRANCOUNT>0 COMMIT TRANSACTION
SET NOEXEC OFF
GO