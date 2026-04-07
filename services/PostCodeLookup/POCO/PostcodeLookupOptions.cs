namespace PostCodeLookup.POCO
{
    public class PostcodeLookupOptions
    {
        public string Provider { get; set; } = "Ideal";
        public OSOptions OSPlaces { get; set; } = new();
        public IdealOptions IdealPostcodes { get; set; } = new();

        public class OSOptions
        {
            public string ApiKey { get; set; } = default!;
        }

        public class IdealOptions
        {
            public string ApiKey { get; set; } = default!;
        }
    }
}