using Newtonsoft.Json;

namespace Concursus.API.Client.GeoData;

//The set of assigned codes for this postcode.
public class PostcodeCodes
{
    #region Public Fields

    [JsonProperty("admin_county")] public string AdminCounty = "";

    [JsonProperty("admin_district")] public string AdminDistrict = "";

    [JsonProperty("admin_ward")] public string AdminWard = "";

    [JsonProperty("ccg")] public string CCG = "";

    [JsonProperty("ced")] public string CED = "";

    [JsonProperty("nuts")] public string NUTS = "";

    [JsonProperty("parish")] public string Parish = "";

    [JsonProperty("parliamentary_constituency")]
    public string ParliamentaryConstituency = "";

    #endregion Public Fields
}

//The full postcode info for a requested postcode.
public class PostcodeInfo
{
    #region Public Constructors

    public PostcodeInfo(List<PostcodeResult> result)
    {
        Result = result;
    }

    public PostcodeInfo()
    {
        Result = new List<PostcodeResult>();
    }

    #endregion Public Constructors

    #region Private Constructors

    //If an error is returned, it is held here.
    [JsonConstructor]
    private PostcodeInfo(PostcodeResult result)
    {
        Result = new List<PostcodeResult> { result };
    }

    #endregion Private Constructors

    #region Public Properties

    [JsonProperty("error")]
    public string Error { get; set; } = "";

    [JsonProperty("result")]
    public List<PostcodeResult> Result { get; set; }

    [JsonProperty("status")]
    public int Status { get; set; }

    #endregion Public Properties
}

public class PostcodeResult
{
    #region Public Fields

    [JsonProperty("admin_county")] public string AdminCounty = "";

    [JsonProperty("admin_district")] public string AdminDistrict = "";

    [JsonProperty("admin_ward")] public string AdminWard = "";

    [JsonProperty("ccg")] public string CCG = "";

    [JsonProperty("ced")] public string CED = "";

    //Country the postcode is in, region.
    [JsonProperty("country")] public string Country = "";

    //Eastings, northings.
    [JsonProperty("eastings")] public int Eastings;

    //The european electoral region of the postcode.
    [JsonProperty("european_electoral_region")]
    public string EuropeanElectoralRegion = "";

    //Postcode incode/outcode (region and subregion).
    [JsonProperty("incode")] public string Incode = "";

    [JsonProperty("latitude")] public double Latitude;

    //Longitude, latitude.
    [JsonProperty("longitude")] public double Longitude;

    //LSOA, MSOA
    public string LSOA = "", MSOA = "";

    //The NHS domain of the postcode, primary care trust.
    [JsonProperty("nhs_ha")] public string NHSDomain = "";

    [JsonProperty("northings")] public int Northings;

    [JsonProperty("nuts")] public string NUTS = "";

    [JsonProperty("outcode")] public string Outcode = "";

    [JsonProperty("parish")] public string Parish = "";

    //Parliamentary/council stuff.
    [JsonProperty("parliamentary_constituency")]
    public string ParliamentaryConstituency = "";

    //The returned postcode.
    [JsonProperty("postcode")] public string Postcode = "";

    [JsonProperty("primary_care_trust")] public string PrimaryCareTrust = "";

    //The quality of the postcode.
    [JsonProperty("quality")] public int Quality;

    [JsonProperty("region")] public string Region = "";

    #endregion Public Fields

    #region Private Fields

    //Codes for this postcode.
    [JsonProperty("codes")] private PostcodeCodes Codes = new();

    #endregion Private Fields
}