USE [CymBuild_Dev]
GO
SET IDENTITY_INSERT [SFin].[VatCodes] ON 
GO
INSERT [SFin].[VatCodes] ([ID], [RowStatus], [Guid], [SageVatNo], [Description], [VatPercentage], [EffectiveFromDate], [Active]) VALUES (3, 1, N'c2d9d80f-2f8a-4e65-83b6-1a10d267a203', N'0', N'UK Zero Rated VAT', CAST(0.0000 AS Decimal(9, 4)), CAST(N'2026-04-17' AS Date), 1)
GO
INSERT [SFin].[VatCodes] ([ID], [RowStatus], [Guid], [SageVatNo], [Description], [VatPercentage], [EffectiveFromDate], [Active]) VALUES (4, 1, N'd3e9d80f-2f8a-4e65-83b6-1a10d267a204', N'E', N'UK VAT Exempt', CAST(0.0000 AS Decimal(9, 4)), CAST(N'2026-04-17' AS Date), 1)
GO
INSERT [SFin].[VatCodes] ([ID], [RowStatus], [Guid], [SageVatNo], [Description], [VatPercentage], [EffectiveFromDate], [Active]) VALUES (5, 1, N'e4f9d80f-2f8a-4e65-83b6-1a10d267a205', N'O', N'Out of Scope VAT', CAST(0.0000 AS Decimal(9, 4)), CAST(N'2026-04-17' AS Date), 1)
GO
INSERT [SFin].[VatCodes] ([ID], [RowStatus], [Guid], [SageVatNo], [Description], [VatPercentage], [EffectiveFromDate], [Active]) VALUES (7, 1, N'a6b9d80f-2f8a-4e65-83b6-1a10d267a207', N'RC', N'EU Reverse Charge', CAST(0.0000 AS Decimal(9, 4)), CAST(N'2026-04-17' AS Date), 1)
GO
INSERT [SFin].[VatCodes] ([ID], [RowStatus], [Guid], [SageVatNo], [Description], [VatPercentage], [EffectiveFromDate], [Active]) VALUES (9, 1, N'c8d9d80f-2f8a-4e65-83b6-1a10d267a209', N'X', N'Export (Zero Rated)', CAST(0.0000 AS Decimal(9, 4)), CAST(N'2026-04-17' AS Date), 1)
GO
INSERT [SFin].[VatCodes] ([ID], [RowStatus], [Guid], [SageVatNo], [Description], [VatPercentage], [EffectiveFromDate], [Active]) VALUES (2, 1, N'b1c9d80f-2f8a-4e65-83b6-1a10d267a202', N'5', N'UK Reduced VAT (5%)', CAST(5.0000 AS Decimal(9, 4)), CAST(N'2026-04-17' AS Date), 1)
GO
INSERT [SFin].[VatCodes] ([ID], [RowStatus], [Guid], [SageVatNo], [Description], [VatPercentage], [EffectiveFromDate], [Active]) VALUES (6, 1, N'f5a9d80f-2f8a-4e65-83b6-1a10d267a206', N'15', N'UK Historic VAT (15%)', CAST(15.0000 AS Decimal(9, 4)), CAST(N'2008-12-01' AS Date), 0)
GO
INSERT [SFin].[VatCodes] ([ID], [RowStatus], [Guid], [SageVatNo], [Description], [VatPercentage], [EffectiveFromDate], [Active]) VALUES (1, 1, N'a5d9d80f-2f8a-4e65-83b6-1a10d267a201', N'22', N'Standard UK VAT', CAST(20.0000 AS Decimal(9, 4)), CAST(N'2026-04-17' AS Date), 1)
GO
INSERT [SFin].[VatCodes] ([ID], [RowStatus], [Guid], [SageVatNo], [Description], [VatPercentage], [EffectiveFromDate], [Active]) VALUES (8, 1, N'b7c9d80f-2f8a-4e65-83b6-1a10d267a208', N'EU20', N'EU VAT (Standard Placeholder)', CAST(20.0000 AS Decimal(9, 4)), CAST(N'2026-04-17' AS Date), 1)
GO
SET IDENTITY_INSERT [SFin].[VatCodes] OFF
GO
