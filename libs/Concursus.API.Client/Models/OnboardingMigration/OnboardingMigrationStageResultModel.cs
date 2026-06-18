namespace Concursus.API.Client.Models.OnboardingMigration;

public sealed class OnboardingMigrationStageResultModel
{
    public Guid RunGuid { get; set; }
    public int GroupCount { get; set; }
    public int IdentityCount { get; set; }
    public int UserGroupCount { get; set; }
    public int WorkflowNotificationGroupCount { get; set; }
    public int JobTypeCount { get; set; }
    public int ActivityTypeCount { get; set; }
    public int MilestoneTypeCount { get; set; }
    public int ProductCount { get; set; }
    public int JobTypeActivityTypeCount { get; set; }
    public int JobTypeMilestoneTemplateCount { get; set; }
    public int ProductJobActivityCount { get; set; }
}