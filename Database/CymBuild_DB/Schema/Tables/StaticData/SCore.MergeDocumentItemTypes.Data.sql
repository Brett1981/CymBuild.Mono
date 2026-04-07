SET IDENTITY_INSERT SCore.MergeDocumentItemTypes ON
GO
INSERT SCore.MergeDocumentItemTypes(ID, Guid, RowStatus, Name, IsImageType) VALUES (-1, '00000000-0000-0000-0000-000000000000', 0, N'', 0);
INSERT SCore.MergeDocumentItemTypes(ID, Guid, RowStatus, Name, IsImageType) VALUES (1, '94abfb52-cba2-4748-8f60-9a67a3f292d1', 1, N'Image Table', 1);
INSERT SCore.MergeDocumentItemTypes(ID, Guid, RowStatus, Name, IsImageType) VALUES (2, '9f69ca42-52c1-44bd-a0de-e9601664b5dc', 1, N'Data Table', 0);
INSERT SCore.MergeDocumentItemTypes(ID, Guid, RowStatus, Name, IsImageType) VALUES (3, '16ac0bab-d41c-4edc-ac09-7bd871db57b6', 1, N'Includes', 0);
INSERT SCore.MergeDocumentItemTypes(ID, Guid, RowStatus, Name, IsImageType) VALUES (4, '169566f4-9da7-4b2a-a06b-3cd6af6bee5f', 1, N'Signature', 1);
GO
SET IDENTITY_INSERT SCore.MergeDocumentItemTypes OFF
GO