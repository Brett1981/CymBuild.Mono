namespace Concursus.EF.Helpers
{
    public static class AuditHelper
    {
        //public static void Audit<T>(MyDbContext db, T entity, string column, object oldVal, object newVal)
        //    where T : class, IAuditable
        //{
        //    if (Equals(oldVal, newVal)) return;
        //    db.RecordHistory.Add(new RecordHistory
        //    {
        //        SchemaName = "SCore",
        //        TableName = typeof(T).Name,
        //        ColumnName = column,
        //        RowID = entity.ID,
        //        RowGuid = entity.Guid,
        //        SQLUser = "KafkaWorker",
        //        UserID = -1,
        //        PreviousValue = oldVal?.ToString() ?? "",
        //        NewValue = newVal?.ToString() ?? "",
        //        EntityPropertyID = -1
        //    });
        //}
    }
}