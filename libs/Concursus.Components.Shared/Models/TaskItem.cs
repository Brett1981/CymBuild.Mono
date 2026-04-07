// Ignore Spelling: Concursus

namespace Concursus.Components.Shared.Models
{
    public class TaskItem
    {
        public string TaskId { get; set; } = "00000000-0000-0000-0000-000000000000";
        public int UserId { get; set; } = -1;
        public string TaskTitle { get; set; } = "";
        public string TaskDescription { get; set; } = "";
        public bool IsComplete { get; set; } = false;
        public DateTime TaskDate { get; set; }
        public int OrderIndex { get; set; } = 0;
        public string Notes { get; set; } = "";
        public bool AssistanceRequested { get; set; } = false;
        public string AssistanceNotes { get; set; } = "";
    }
}