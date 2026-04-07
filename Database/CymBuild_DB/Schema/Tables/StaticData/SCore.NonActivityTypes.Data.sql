SET IDENTITY_INSERT SCore.NonActivityTypes ON
GO
INSERT SCore.NonActivityTypes(ID, Guid, Name, RowStatus) VALUES (-1, '00000000-0000-0000-0000-000000000000', N'', 1);
INSERT SCore.NonActivityTypes(ID, Guid, Name, RowStatus) VALUES (1, 'ffe21b20-a679-43bf-bf3b-e6edf4cb3aa7', N'Maternity Leave', 1);
INSERT SCore.NonActivityTypes(ID, Guid, Name, RowStatus) VALUES (2, '159b09ab-39eb-470b-beac-cdee4f113a24', N'Holiday', 1);
INSERT SCore.NonActivityTypes(ID, Guid, Name, RowStatus) VALUES (3, '8f7cec01-1bb4-4ddd-b16b-89eaace0f56a', N'Meeting', 1);
GO
SET IDENTITY_INSERT SCore.NonActivityTypes OFF
GO