using Concursus.Common.Shared.Kafka.Core;
using Concursus.Common.Shared.Kafka.Core.Publisher;
using Concursus.Common.Shared.Notifications.Contracts;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Concursus.API.Services.Outbox;

public sealed class WorkflowOutboxKafkaPublisherWorker : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<WorkflowOutboxKafkaPublisherWorker> _logger;
    private readonly IConfiguration _configuration;
    private static readonly Guid JobClosureRequestStatusGuid = new("5ED9C55A-4E14-44F6-A106-AE0F5C5EC38D");
    private const int JobsEntityTypeId = 9;

    public WorkflowOutboxKafkaPublisherWorker(
        IServiceScopeFactory scopeFactory,
        ILogger<WorkflowOutboxKafkaPublisherWorker> logger,
        IConfiguration configuration)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
        _configuration = configuration;
    }

    private bool NotificationsEnabled =>
        _configuration.GetValue<bool>("Notifications:Enabled", true);

    // Preserve existing behaviour if no group source can be resolved yet.
    // This avoids breaking downstream consumers that currently rely on a non-empty Source.
    private const string DefaultSourceFallback = "cymbuild-fireengineering-authorisation";

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!NotificationsEnabled)
        {
            _logger.LogWarning("WorkflowOutboxKafkaPublisherWorker NOT started: Notifications:Enabled=false.");
            return;
        }

        _logger.LogInformation("WorkflowOutboxKafkaPublisherWorker started.");

        const int batchSize = 25;
        const int maxAttempts = 10;

        while (!stoppingToken.IsCancellationRequested)
        {
            if (!NotificationsEnabled)
            {
                _logger.LogWarning("WorkflowOutboxKafkaPublisherWorker stopping: Notifications:Enabled=false.");
                return;
            }

            try
            {
                await using var scope = _scopeFactory.CreateAsyncScope();

                var repo = scope.ServiceProvider.GetRequiredService<WorkflowOutboxRepository>();
                var kafka = scope.ServiceProvider.GetRequiredService<IKafkaPublisherService>();
                var kafkaOpts = scope.ServiceProvider.GetRequiredService<IOptions<KafkaOptions>>().Value;

                // 1) Drain transition queue into outbox (existing workflow pipeline only)
                var queued = await repo.DequeueNotificationQueueAsync(take: 50, maxAttempts: 10, stoppingToken);
                if (queued.Count > 0)
                {
                    _logger.LogInformation("Dequeued {Count} transition(s) for outbox enqueue.", queued.Count);

                    foreach (var tg in queued)
                    {
                        try
                        {
                            await repo.EnqueueOutboxForTransitionAsync(tg, stoppingToken);
                            await repo.MarkQueueProcessedAsync(tg, stoppingToken);
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(ex, "Failed to enqueue outbox for TransitionGuid={TransitionGuid}", tg);
                            await repo.MarkQueueFailedAsync(tg, ex.Message, stoppingToken);
                        }
                    }
                }

                // 2) Claim publishable outbox rows
                var batch = await repo.ClaimBatchAsync(batchSize, maxAttempts, stoppingToken);
                _logger.LogInformation("Claimed {Count} outbox items for publishing.", batch.Count);

                if (batch.Count == 0)
                {
                    await Task.Delay(TimeSpan.FromSeconds(3), stoppingToken);
                    continue;
                }

                foreach (var item in batch)
                {
                    try
                    {
                        if (!NotificationsEnabled)
                        {
                            _logger.LogWarning("Worker stopping mid-batch: Notifications:Enabled=false.");
                            return;
                        }

                        var recipients = await repo.GetRecipientsAsync(item.OutboxId, stoppingToken);

                        if (recipients.Count == 0)
                        {
                            await repo.MarkFailedAsync(
                                item.OutboxId,
                                item.PublishingToken,
                                "No recipients resolved for outbox item.",
                                stoppingToken);
                            continue;
                        }

                        var topic = kafkaOpts.Topic;
                        var eventType = (item.EventType ?? string.Empty).Trim();

                        switch (eventType)
                        {
                            case "WorkflowStatusNotification":
                                {
                                    var payload = repo.ParsePayload(item.PayloadJson);

                                    var workflowMessage = await BuildWorkflowStatusNotificationMessageAsync(
                                        repo,
                                        item,
                                        payload,
                                        recipients,
                                        stoppingToken);

                                    // Use TransitionGuid as the message identity for workflow notifications.
                                    var key = payload.TransitionGuid != Guid.Empty
                                        ? payload.TransitionGuid.ToString()
                                        : payload.DataObjectGuid.ToString();

                                    await kafka.PublishAsync(topic, key, workflowMessage, stoppingToken);
                                    break;
                                }

                            case "JobCreatedFromProposal":
                                {
                                    var payload = repo.ParseJobCreatedFromProposalPayload(item.PayloadJson);

                                    var jobCreatedMessage = await BuildJobCreatedFromProposalMessageAsync(
                                        repo,
                                        payload,
                                        recipients,
                                        stoppingToken);

                                    var key = (payload.JobGuid ?? payload.QuoteGuid ?? item.OutboxGuid).ToString();
                                    await kafka.PublishAsync(topic, key, jobCreatedMessage, stoppingToken);
                                    break;
                                }

                            case "JobClosureDecision":
                                {
                                    var payload = repo.ParseJobClosureDecisionPayload(item.PayloadJson);

                                    var jobClosureMessage = await BuildJobClosureDecisionMessageAsync(
                                        repo,
                                        payload,
                                        recipients,
                                        stoppingToken);

                                    var key = (payload.JobGuid ?? payload.DataObjectGuid ?? item.OutboxGuid).ToString();
                                    await kafka.PublishAsync(topic, key, jobClosureMessage, stoppingToken);
                                    break;
                                }

                            default:
                                {
                                    await repo.MarkFailedAsync(
                                        item.OutboxId,
                                        item.PublishingToken,
                                        $"Unsupported outbox EventType '{item.EventType}'.",
                                        stoppingToken);
                                    continue;
                                }
                        }

                        await repo.MarkPublishedAsync(item.OutboxId, item.PublishingToken, stoppingToken);
                    }
                    catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                    {
                        return;
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Failed publishing outbox item. OutboxId={OutboxId}", item.OutboxId);
                        await SafeMarkFailed(_scopeFactory, item.OutboxId, item.PublishingToken, ex, stoppingToken);
                    }
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (ObjectDisposedException ex)
            {
                _logger.LogWarning(ex, "Service provider disposed. Worker stopping.");
                return;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Worker loop error.");
                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
            }
        }
    }

    private async Task<string> ResolveWorkflowStatusSourceAsync(
    WorkflowOutboxRepository repo,
    WorkflowOutboxRepository.OutboxItem item,
    WorkflowOutboxRepository.WorkflowOutboxPayload payload,
    CancellationToken stoppingToken)
    {
        // Dedicated source override for Job Closure Request.
        // Everything else remains identical to the generic authorisation flow.
        if (payload.EntityTypeId == JobsEntityTypeId &&
            payload.CanonicalStatusGuid == JobClosureRequestStatusGuid)
        {
            var configured = _configuration["Notifications:JobClosureRequest:Source"];
            var source = string.IsNullOrWhiteSpace(configured)
                ? "cymbuild-job-closure-request"
                : configured.Trim();

            _logger.LogInformation(
                "Using dedicated Job Closure Request source '{Source}' for OutboxId={OutboxId}, RecordGuid={RecordGuid}.",
                source,
                item.OutboxId,
                payload.DataObjectGuid);

            return source;
        }

        var resolvedSources = await repo.GetDistinctGroupSourcesAsync(payload.TargetGroupIdsCsv, stoppingToken);

        if (resolvedSources.Count == 0)
        {
            _logger.LogWarning(
                "No group source resolved for OutboxId={OutboxId}, TargetGroupIdsCsv='{TargetGroupIdsCsv}'. Using fallback Source='{Fallback}'.",
                item.OutboxId,
                payload.TargetGroupIdsCsv ?? string.Empty,
                DefaultSourceFallback);

            return DefaultSourceFallback;
        }

        if (resolvedSources.Count > 1)
        {
            _logger.LogWarning(
                "Multiple distinct group sources resolved for OutboxId={OutboxId}, TargetGroupIdsCsv='{TargetGroupIdsCsv}'. Using Source='{Source}'. Sources={Sources}.",
                item.OutboxId,
                payload.TargetGroupIdsCsv ?? string.Empty,
                resolvedSources[0],
                string.Join(", ", resolvedSources));
        }

        return resolvedSources[0];
    }

    /// <summary>
    /// Existing workflow notification publish path.
    /// Kept aligned to the original behaviour.
    /// </summary>
    private async Task<WorkflowStatusNotificationMessage> BuildWorkflowStatusNotificationMessageAsync(
    WorkflowOutboxRepository repo,
    WorkflowOutboxRepository.OutboxItem item,
    WorkflowOutboxRepository.WorkflowOutboxPayload payload,
    List<string> recipients,
    CancellationToken stoppingToken)
    {
        var sourceToUse = await ResolveWorkflowStatusSourceAsync(repo, item, payload, stoppingToken);

        WorkflowOutboxRepository.NotificationEnrichment enrich;

        try
        {
            enrich = await repo.GetNotificationEnrichmentAsync(
                payload.DataObjectGuid,
                payload.EntityTypeId,
                payload.OrganisationalUnitId,
                stoppingToken);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "Notification enrichment failed; continuing without enrichment. OutboxId={OutboxId}, RecordGuid={RecordGuid}",
                item.OutboxId, payload.DataObjectGuid);

            enrich = new WorkflowOutboxRepository.NotificationEnrichment(
                EntityTypeName: null,
                DetailPageUrl: null,
                RecordUrl: null,
                DisplayRef: null,
                DisplayTitle: null,
                DisplayOrganisationName: null,
                DisplayProjectName: null,
                DisplayClientName: null,
                DisplayAgentName: null,
                DisplayAddress: null,
                Description: null);
        }

        var statusGuid = payload.CanonicalStatusGuid;
        var statusName = payload.CanonicalStatusName;
        var statusId = payload.CanonicalStatusId;

        var oldStatusGuid = payload.OldStatusGuid ?? payload.OldWorkflowStatusGuid;
        var oldStatusName = payload.OldStatusName ?? payload.OldWorkflowStatusName;
        var oldStatusId = payload.OldStatusId ?? payload.OldWorkflowStatusId;

        var entityTypeName = enrich.EntityTypeName ?? ResolveEntityTypeName(payload.EntityTypeId);

        var dataLinks = new List<Links>();

        if (!string.IsNullOrWhiteSpace(enrich.RecordUrl))
        {
            dataLinks.Add(new Links { Key = "recordUrl", Value = enrich.RecordUrl });

            var recordStatusUrl = BuildRecordStatusUrl(enrich.RecordUrl);
            if (!string.IsNullOrWhiteSpace(recordStatusUrl))
            {
                dataLinks.Add(new Links { Key = "recordStatusUrl", Value = recordStatusUrl });
            }
        }

        var singularRecordUrl = dataLinks.FirstOrDefault(x => x.Key == "recordUrl")?.Value;
        var singularRecordStatusUrl = dataLinks.FirstOrDefault(x => x.Key == "recordStatusUrl")?.Value;

        var linkSet = new WorkflowStatusNotificationLinkSet
        {
            RecordUrl = singularRecordUrl,
            RecordStatusUrl = singularRecordStatusUrl
        };

        var actor = BuildActor(payload.ActorIdentityId, payload.ActorName, payload.ActorEmail);
        var surveyor = BuildActor(payload.SurveyorIdentityId, payload.SurveyorName, payload.SurveyorEmail);

        var targetGroups = (payload.TargetGroups ?? new List<WorkflowOutboxRepository.OutboxTargetGroupPayload>())
            .Select(g => new WorkflowStatusNotificationTargetGroup
            {
                GroupId = g.GroupId,
                GroupCode = g.GroupCode,
                GroupName = g.GroupName,
                CanAction = g.CanAction
            })
            .ToList();
        _logger.LogInformation(
            "Workflow notification debug | RecordGuid={RecordGuid} | Description='{Description}' | ContractsAssembly={Assembly}",
            payload.DataObjectGuid,
            enrich.Description ?? "<null>",
            typeof(WorkflowStatusNotificationData).Assembly.FullName);

        _logger.LogInformation(
            "Workflow notification debug | HasDescriptionProperty={HasDescriptionProperty}",
            typeof(WorkflowStatusNotificationData).GetProperty("Description") is not null);
        return new WorkflowStatusNotificationMessage
        {
            Source = sourceToUse,
            Recipients = recipients,
            TimestampUtc = DateTime.UtcNow,
            Data = new WorkflowStatusNotificationData
            {
                RecordGuid = payload.DataObjectGuid,
                EntityTypeId = payload.EntityTypeId,
                EntityTypeName = entityTypeName,

                WorkflowId = payload.WorkflowId,
                WorkflowName = payload.WorkflowName,

                WorkflowStatusGuid = statusGuid,
                WorkflowStatusName = statusName,
                WorkflowStatusId = statusId,

                OldWorkflowStatusId = oldStatusId,
                OldWorkflowStatusGuid = oldStatusGuid,
                OldWorkflowStatusName = oldStatusName,

                TransitionGuid = payload.TransitionGuid,
                TransitionId = payload.TransitionId,
                TransitionUtc = payload.OccurredOnUtc,

                Comment = payload.Comment,

                ActorUserId = payload.ActorIdentityId ?? 0,
                Actor = actor,

                SurveyorUserId = payload.SurveyorIdentityId > 0 ? payload.SurveyorIdentityId : null,
                Surveyor = surveyor,

                TargetGroupIdsCsv = payload.TargetGroupIdsCsv,
                TargetGroups = targetGroups,

                OrganisationalUnitId = payload.OrganisationalUnitId,
                OrganisationalUnitName = payload.OrganisationalUnitName,

                DisplayRef = enrich.DisplayRef,
                DisplayTitle = enrich.DisplayTitle,
                DisplayOrganisationName = enrich.DisplayOrganisationName,
                DisplayProjectName = enrich.DisplayProjectName,
                DisplayClientName = enrich.DisplayClientName,
                DisplayAgentName = enrich.DisplayAgentName,
                // Prefer payload value first because CYB-4 now enriches these directly into the outbox JSON.
                // Fall back to generic notification enrichment so existing behaviour is preserved.
                DisplayAddress = payload.DisplayAddress ?? enrich.DisplayAddress,
                DueDateUtc = payload.DueDateUtc,
                DueDateDisplay = payload.DueDateDisplay,

                Description = enrich.Description,

                Links = linkSet,
                LinksKv = dataLinks
            },
            Links = dataLinks
        };
    }

    /// <summary>
    /// CYB-36 publish path.
    /// Uses the same URL enrichment pattern as workflow notifications,
    /// but remains fully separate from WorkflowStatusNotification behaviour.
    /// </summary>
    private async Task<JobCreatedFromProposalNotificationMessage> BuildJobCreatedFromProposalMessageAsync(
        WorkflowOutboxRepository repo,
        WorkflowOutboxRepository.JobCreatedFromProposalOutboxPayload payload,
        List<string> recipients,
        CancellationToken stoppingToken)
    {
        var sourceToUse = ResolveJobCreatedSource();

        string? jobUrl = null;
        string? jobRecordStatusUrl = null;
        string? quoteUrl = null;

        if (payload.JobGuid.HasValue && payload.JobGuid.Value != Guid.Empty)
        {
            var jobEnrichment = await repo.GetNotificationEnrichmentAsync(
                payload.JobGuid.Value,
                entityTypeId: 9,
                organisationalUnitId: null,
                ct: stoppingToken);

            jobUrl = jobEnrichment.RecordUrl;
            jobRecordStatusUrl = BuildRecordStatusUrl(jobUrl);
        }

        if (payload.QuoteGuid.HasValue && payload.QuoteGuid.Value != Guid.Empty)
        {
            var quoteEnrichment = await repo.GetNotificationEnrichmentAsync(
                payload.QuoteGuid.Value,
                entityTypeId: 55,
                organisationalUnitId: null,
                ct: stoppingToken);

            quoteUrl = quoteEnrichment.RecordUrl;
        }

        var links = new List<Links>();

        if (!string.IsNullOrWhiteSpace(jobUrl))
            links.Add(new Links { Key = "jobUrl", Value = jobUrl });

        if (!string.IsNullOrWhiteSpace(jobRecordStatusUrl))
            links.Add(new Links { Key = "jobRecordStatusUrl", Value = jobRecordStatusUrl });

        if (!string.IsNullOrWhiteSpace(quoteUrl))
            links.Add(new Links { Key = "quoteUrl", Value = quoteUrl });

        return new JobCreatedFromProposalNotificationMessage
        {
            Source = sourceToUse,
            Recipients = recipients,
            TimestampUtc = DateTime.UtcNow,
            Data = new JobCreatedFromProposalNotificationData
            {
                EventGuid = payload.EventGuid,
                EventType = string.IsNullOrWhiteSpace(payload.EventType)
                    ? "JobCreatedFromProposal"
                    : payload.EventType,
                OccurredOnUtc = payload.OccurredOnUtc,

                JobGuid = payload.JobGuid ?? Guid.Empty,
                JobNumber = payload.JobNumber,
                JobCreatedOnUtc = payload.JobCreatedOnUtc,

                QuoteGuid = payload.QuoteGuid,
                QuoteReference = payload.QuoteReference,

                ClientName = payload.ClientName,
                ProjectDescription = payload.ProjectDescription,

                Description = payload.Description ?? payload.ProjectDescription,

                Actor = BuildJobCreatedPerson(payload.Actor),
                Drafter = BuildJobCreatedPerson(payload.Drafter),

                Links = new JobCreatedFromProposalLinkSet
                {
                    JobUrl = jobUrl,
                    JobRecordStatusUrl = jobRecordStatusUrl,
                    QuoteUrl = quoteUrl
                },
                LinksKv = links
            },
            Links = links
        };
    }

    /// <summary>
    /// Dedicated job closure notification path.
    /// Deliberately separate from WorkflowStatusNotification.
    /// </summary>
    private async Task<JobClosureDecisionNotificationMessage> BuildJobClosureDecisionMessageAsync(
        WorkflowOutboxRepository repo,
        WorkflowOutboxRepository.JobClosureDecisionOutboxPayload payload,
        List<string> recipients,
        CancellationToken stoppingToken)
    {
        var sourceToUse = ResolveJobClosureSource();

        string? jobUrl = null;
        string? jobRecordStatusUrl = null;

        Guid? jobGuid = payload.JobGuid ?? payload.DataObjectGuid;
        if (jobGuid.HasValue && jobGuid.Value != Guid.Empty)
        {
            var jobEnrichment = await repo.GetNotificationEnrichmentAsync(
                jobGuid.Value,
                entityTypeId: 9,
                organisationalUnitId: payload.OrganisationalUnitId,
                ct: stoppingToken);

            jobUrl = jobEnrichment.RecordUrl;
            jobRecordStatusUrl = BuildRecordStatusUrl(jobUrl);
        }

        var links = new List<Links>();

        if (!string.IsNullOrWhiteSpace(jobUrl))
            links.Add(new Links { Key = "jobUrl", Value = jobUrl });

        if (!string.IsNullOrWhiteSpace(jobRecordStatusUrl))
            links.Add(new Links { Key = "jobRecordStatusUrl", Value = jobRecordStatusUrl });

        return new JobClosureDecisionNotificationMessage
        {
            Source = sourceToUse,
            Recipients = recipients,
            TimestampUtc = DateTime.UtcNow,
            Data = new JobClosureDecisionNotificationData
            {
                EventGuid = payload.EventGuid,
                EventType = string.IsNullOrWhiteSpace(payload.EventType)
                    ? "JobClosureDecision"
                    : payload.EventType,
                OccurredOnUtc = payload.OccurredOnUtc,

                JobGuid = jobGuid,
                JobNumber = payload.JobNumber,
                JobTitle = payload.JobTitle,

                OrganisationalUnitId = payload.OrganisationalUnitId,
                OrganisationalUnitName = payload.OrganisationalUnitName,

                WorkflowId = payload.WorkflowId,
                WorkflowName = payload.WorkflowName,

                StatusId = payload.StatusId,
                StatusGuid = payload.StatusGuid,
                StatusName = payload.StatusName,

                OldStatusId = payload.OldStatusId,
                OldStatusGuid = payload.OldStatusGuid,
                OldStatusName = payload.OldStatusName,

                Description = payload.Description ?? payload.JobTitle, //For Job Description is Billing Instructions, so fallback to Job Title if Description is not provided

                Comment = payload.Comment,

                Actor = BuildJobClosurePerson(payload.Actor),

                Links = new JobClosureDecisionLinkSet
                {
                    JobUrl = jobUrl,
                    JobRecordStatusUrl = jobRecordStatusUrl
                },
                LinksKv = links
            },
            Links = links
        };
    }

    private string ResolveJobCreatedSource()
    {
        var configured = _configuration["Notifications:JobCreatedFromProposal:Source"];
        return string.IsNullOrWhiteSpace(configured)
            ? "cymbuild-job-created-from-proposal"
            : configured.Trim();
    }

    private string ResolveJobClosureSource()
    {
        var configured = _configuration["Notifications:JobClosure:Source"];
        return string.IsNullOrWhiteSpace(configured)
            ? "cymbuild-job-closure"
            : configured.Trim();
    }

    private static JobCreatedFromProposalPerson? BuildJobCreatedPerson(WorkflowOutboxRepository.OutboxPersonPayload? payload)
    {
        if (payload is null)
            return null;

        if (payload.IdentityId is null &&
            string.IsNullOrWhiteSpace(payload.FullName) &&
            string.IsNullOrWhiteSpace(payload.EmailAddress))
        {
            return null;
        }

        return new JobCreatedFromProposalPerson
        {
            IdentityId = payload.IdentityId,
            FullName = string.IsNullOrWhiteSpace(payload.FullName) ? null : payload.FullName,
            EmailAddress = string.IsNullOrWhiteSpace(payload.EmailAddress) ? null : payload.EmailAddress
        };
    }

    private static JobClosureDecisionPerson? BuildJobClosurePerson(WorkflowOutboxRepository.OutboxPersonPayload? payload)
    {
        if (payload is null)
            return null;

        if (payload.IdentityId is null &&
            string.IsNullOrWhiteSpace(payload.FullName) &&
            string.IsNullOrWhiteSpace(payload.EmailAddress))
        {
            return null;
        }

        return new JobClosureDecisionPerson
        {
            IdentityId = payload.IdentityId,
            FullName = string.IsNullOrWhiteSpace(payload.FullName) ? null : payload.FullName,
            EmailAddress = string.IsNullOrWhiteSpace(payload.EmailAddress) ? null : payload.EmailAddress
        };
    }

    private static WorkflowStatusNotificationActor? BuildActor(int? identityId, string? fullName, string? email)
    {
        if (identityId is null && string.IsNullOrWhiteSpace(fullName) && string.IsNullOrWhiteSpace(email))
            return null;

        return new WorkflowStatusNotificationActor
        {
            IdentityId = identityId,
            IdentityGuid = null,
            FullName = string.IsNullOrWhiteSpace(fullName) ? null : fullName,
            EmailAddress = string.IsNullOrWhiteSpace(email) ? null : email
        };
    }

    private static async Task SafeMarkFailed(
        IServiceScopeFactory scopeFactory,
        long outboxId,
        Guid publishingToken,
        Exception ex,
        CancellationToken ct)
    {
        try
        {
            await using var scope = scopeFactory.CreateAsyncScope();
            var repo = scope.ServiceProvider.GetRequiredService<WorkflowOutboxRepository>();

            var msg = ex.ToString();
            if (msg.Length > 2000)
                msg = msg[..2000];

            await repo.MarkFailedAsync(outboxId, publishingToken, msg, ct);
        }
        catch
        {
            // last resort
        }
    }

    private string? BuildRecordStatusUrl(string? recordUrl)
    {
        if (string.IsNullOrWhiteSpace(recordUrl))
            return null;

        if (!Uri.TryCreate(recordUrl, UriKind.Absolute, out var uri))
        {
            var frag = GetRecordStatusFragment();
            return recordUrl.Contains('#')
                ? recordUrl.Split('#')[0] + "#" + frag
                : recordUrl + "#" + frag;
        }

        var builder = new UriBuilder(uri)
        {
            Fragment = GetRecordStatusFragment()
        };

        return builder.Uri.ToString();
    }

    private string GetRecordStatusFragment()
    {
        var frag = _configuration["Notifications:RecordStatusFragment"];
        return string.IsNullOrWhiteSpace(frag) ? "recordstatus" : frag.Trim().TrimStart('#');
    }

    private static string ResolveEntityTypeName(int entityTypeId) => entityTypeId switch
    {
        83 => "Enquiries",
        9 => "Jobs",
        55 => "Quotes",
        _ => $"EntityTypeId:{entityTypeId}"
    };
}