namespace Concursus.EF.Dto
{
    public class EmployeeKafkaDto
    {
        public string EmployeeId { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string Email { get; set; }
        public string JobTitle { get; set; }
        public string BusinessUnit { get; set; }
        public string Division { get; set; }
        public DateTime Timestamp { get; set; }
    }
}