using System.ComponentModel.DataAnnotations.Schema;

namespace PostCodeLookup.Data.Entities
{
    public class AddressCache
    {
        public int Id { get; set; }
        public int PostcodeCacheId { get; set; }
        public PostcodeCache PostcodeCache { get; set; } = default!;

        public string FormattedAddress { get; set; } = default!;
        public string? Line1 { get; set; }
        public string? Line2 { get; set; }
        public string? Town { get; set; }
        public string? County { get; set; }
        public string Country { get; set; } = "United Kingdom";

        public string? Uprn { get; set; }

        [Column(TypeName = "nvarchar(max)")]
        public string? LocalAuthority { get; set; }

        [Column(TypeName = "nvarchar(max)")]
        public string? AuthorityCode { get; set; }

        public double? Latitude { get; set; }
        public double? Longitude { get; set; }

        public DateTime CreatedUtc { get; set; }

        public string? Context { get; set; }
    }
}