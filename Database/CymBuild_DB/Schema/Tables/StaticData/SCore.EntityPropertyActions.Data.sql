SET IDENTITY_INSERT SCore.EntityPropertyActions ON
GO
INSERT SCore.EntityPropertyActions(ID, RowStatus, Guid, EntityPropertyID, Statement) VALUES (-1, 0, '00000000-0000-0000-0000-000000000000', -1, N'');
INSERT SCore.EntityPropertyActions(ID, RowStatus, Guid, EntityPropertyID, Statement) VALUES (1, 1, '05499eb3-f1b5-4cdc-bd04-e020c9cf6906', 673, N'SELECT @DataObject = SSop.QuoteItemProduct_InputAction(@DataObject)');
GO
SET IDENTITY_INSERT SCore.EntityPropertyActions OFF
GO