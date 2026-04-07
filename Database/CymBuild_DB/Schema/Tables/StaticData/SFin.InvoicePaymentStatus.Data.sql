SET IDENTITY_INSERT SFin.InvoicePaymentStatus ON
GO
INSERT SFin.InvoicePaymentStatus(ID, RowStatus, Guid, Name) VALUES (-1, 1, '00000000-0000-0000-0000-000000000000', N'');
INSERT SFin.InvoicePaymentStatus(ID, RowStatus, Guid, Name) VALUES (1, 1, 'c7f8233a-d729-4b11-95be-970609ca0334', N'Paid');
INSERT SFin.InvoicePaymentStatus(ID, RowStatus, Guid, Name) VALUES (2, 1, 'c711a66c-677a-4d3a-866b-5b1b86c81639', N'Overdue');
INSERT SFin.InvoicePaymentStatus(ID, RowStatus, Guid, Name) VALUES (3, 1, '1ee794bd-5bba-477f-ba11-7bebef908b99', N'Pending');
GO
SET IDENTITY_INSERT SFin.InvoicePaymentStatus OFF
GO