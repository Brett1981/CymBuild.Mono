namespace PostCodeLookup.DTOs
{
    /*
     *  Class definition for the data we receive when we try to search for an answer.
     * **/

    public class AddressResponse
    {
        public string Id { get; set; }
        public string Suggestion { get; set; }
        public string Udprn { get; set; }
        public string Urls { get; set; }
    }
}