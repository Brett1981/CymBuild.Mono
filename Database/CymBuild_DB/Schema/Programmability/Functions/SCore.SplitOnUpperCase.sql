SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
Create Function [SCore].[SplitOnUpperCase](@Temp VarChar(1000))
Returns VarChar(1000)
AS
Begin

    Declare @KeepValues as varchar(50)
    Set @KeepValues = '%[^ ][A-Z]%'
    While PatIndex(@KeepValues collate Latin1_General_Bin, @Temp) > 0
        Set @Temp = Stuff(@Temp, PatIndex(@KeepValues collate Latin1_General_Bin, @Temp) + 1, 0, ' ')

    Return @Temp
End
GO