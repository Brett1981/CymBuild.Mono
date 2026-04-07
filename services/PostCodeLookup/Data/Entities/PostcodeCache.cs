namespace PostCodeLookup.Data.Entities
{
    public class PostcodeCache
    {
        public int Id { get; set; }
        public string Postcode { get; set; } = default!;
        public DateTime CreatedUtc { get; set; }
        public DateTime UpdatedUtc { get; set; }
        public DateTime LastFetchedUtc { get; set; }
        public int CacheCount { get; set; }
        public ICollection<AddressCache> Addresses { get; set; } = new List<AddressCache>();
    }
}