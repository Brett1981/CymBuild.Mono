namespace Concursus.EF.Types
{
    //CBLD-265
    public class ExecuteGridViewActionQueryResponse
    {
        public int RowsAffected { get; set; }
        public string ErrorReturned { get; set; } = "";
    }
}