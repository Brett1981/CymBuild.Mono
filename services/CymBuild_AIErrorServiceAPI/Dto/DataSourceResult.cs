namespace CymBuild_AIErrorServiceAPI.Dto
{
    public class DataSourceResult<T>
    {
        public IEnumerable<T>? Data { get; set; }
        public int Total { get; set; }
    }
}