using System.Text.Json;
using Concursus.API.Services.Outbox;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace Concursus.API.Tests.Outbox;

public sealed class WorkflowOutboxRepositoryPayloadTests
{
    private readonly WorkflowOutboxRepository _repository = new(
        new ConfigurationBuilder().Build(),
        Mock.Of<ILogger<WorkflowOutboxRepository>>());

    [Fact]
    public void ParsePayload_UsesCurrentStatusAsCanonicalValue()
    {
        var statusGuid = Guid.Parse("88888888-8888-8888-8888-888888888888");
        var workflowStatusGuid = Guid.Parse("99999999-9999-9999-9999-999999999999");
        var payload = _repository.ParsePayload($$"""
        {
          "dataObjectGuid": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
          "entityTypeId": 7,
          "statusId": 12,
          "statusGuid": "{{statusGuid}}",
          "statusName": "Approved",
          "workflowStatusId": 11,
          "workflowStatusGuid": "{{workflowStatusGuid}}",
          "workflowStatusName": "Pending",
          "transitionGuid": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
          "targetGroups": [
            { "groupId": 5, "groupCode": "FIN", "groupName": "Finance", "canAction": true }
          ]
        }
        """);

        Assert.Equal(statusGuid, payload.CanonicalStatusGuid);
        Assert.Equal(12, payload.CanonicalStatusId);
        Assert.Equal("Approved", payload.CanonicalStatusName);
        var group = Assert.Single(payload.TargetGroups);
        Assert.Equal(5, group.GroupId);
        Assert.True(group.CanAction);
    }

    [Fact]
    public void ParsePayload_FallsBackToWorkflowStatus()
    {
        var workflowStatusGuid = Guid.Parse("99999999-9999-9999-9999-999999999999");
        var payload = _repository.ParsePayload($$"""
        {
          "dataObjectGuid": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
          "entityTypeId": 7,
          "workflowStatusId": 11,
          "workflowStatusGuid": "{{workflowStatusGuid}}",
          "workflowStatusName": "Pending",
          "transitionGuid": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        }
        """);

        Assert.Equal(workflowStatusGuid, payload.CanonicalStatusGuid);
        Assert.Equal(11, payload.CanonicalStatusId);
        Assert.Equal("Pending", payload.CanonicalStatusName);
    }

    [Fact]
    public void ParseJobCreatedFromProposalPayload_IsCaseInsensitiveAndPreservesRecipients()
    {
        var payload = _repository.ParseJobCreatedFromProposalPayload("""
        {
          "EVENTGUID": "cccccccc-cccc-cccc-cccc-cccccccccccc",
          "EVENTTYPE": "JobCreatedFromProposal",
          "JOBGUID": "dddddddd-dddd-dddd-dddd-dddddddddddd",
          "JOBNUMBER": "JOB-100",
          "ACTOR": {
            "identityId": 42,
            "fullName": "A User",
            "emailAddress": "a.user@example.test"
          },
          "RECIPIENTS": ["one@example.test", "two@example.test"]
        }
        """);

        Assert.Equal("JobCreatedFromProposal", payload.EventType);
        Assert.Equal("JOB-100", payload.JobNumber);
        Assert.Equal(42, payload.Actor?.IdentityId);
        Assert.Equal(2, payload.Recipients.Count);
    }

    [Fact]
    public void ParseJobClosureDecisionPayload_MapsDecisionContract()
    {
        var statusGuid = Guid.Parse("eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee");
        var payload = _repository.ParseJobClosureDecisionPayload($$"""
        {
          "eventGuid": "ffffffff-ffff-ffff-ffff-ffffffffffff",
          "eventType": "JobClosureDecision",
          "jobGuid": "10101010-1010-1010-1010-101010101010",
          "jobNumber": "JOB-200",
          "statusGuid": "{{statusGuid}}",
          "statusName": "Closure Approved",
          "comment": "Approved after review.",
          "recipients": ["manager@example.test"]
        }
        """);

        Assert.Equal("JobClosureDecision", payload.EventType);
        Assert.Equal("JOB-200", payload.JobNumber);
        Assert.Equal(statusGuid, payload.StatusGuid);
        Assert.Equal("Approved after review.", payload.Comment);
        Assert.Equal("manager@example.test", Assert.Single(payload.Recipients));
    }

    [Theory]
    [InlineData("workflow")]
    [InlineData("job-created")]
    [InlineData("job-closure")]
    public void ParsePayload_NullJsonValueThrowsInvalidOperationException(string payloadType)
    {
        Action action = payloadType switch
        {
            "workflow" => () => { _repository.ParsePayload("null"); },
            "job-created" => () => { _repository.ParseJobCreatedFromProposalPayload("null"); },
            "job-closure" => () => { _repository.ParseJobClosureDecisionPayload("null"); },
            _ => throw new InvalidOperationException("Unknown payload type.")
        };

        Assert.Throws<InvalidOperationException>(action);
    }

    [Fact]
    public void ParsePayload_MalformedJsonPreservesJsonException()
    {
        Assert.Throws<JsonException>(() => _repository.ParsePayload("{not-json}"));
    }
}
