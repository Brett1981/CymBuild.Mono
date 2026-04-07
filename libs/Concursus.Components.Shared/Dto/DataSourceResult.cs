namespace Concursus.Components.Shared.Dto
{
    public class DataSourceResult<T>
    {
        public IEnumerable<T>? Data { get; set; }
        public int Total { get; set; }
    }
}