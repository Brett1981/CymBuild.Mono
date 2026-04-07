namespace Concursus.API.Sage.Models
{
    public class Card
    {
        public int Id { get; set; }
        public int CustomerId { get; set; }
        public string Description { get; set; }
        public DateTime LastUsedDate { get; set; }
        public bool IsToDelete { get; set; }
    }
}