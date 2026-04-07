namespace Concursus.EF.Enums
{
    public enum RowStatus : byte
    {
        New = 0,
        Active = 1,
        LimitedWrite = 50,
        LimitedReadWrite = 100,
        ReadOnly = 150,
        Archived = 200,
        Deleted = 254,
        System = 255
    }
}