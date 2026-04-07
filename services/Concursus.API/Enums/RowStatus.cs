namespace Concursus.API.Enums;

public enum RowStatus : byte
{
    Active = 1,
    LimitedWrite = 50,
    LimitedReadWrite = 100,
    ReadOnly = 150,
    Archived = 200,
    Deleted = 254,
    System = 255
}