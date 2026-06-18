# API and gRPC Contract Map

Generated from the uploaded project snapshot. Review before treating as authoritative.

## Mandatory call flow

```text
PWA component → FormHelper/API client → gRPC/API service → EF/repository → SQL
```

## FormHelper

File: `libs/Concursus.API.Client/FormHelper.cs`

Detected public methods include:

- `TransactionInvoicePrintModelGetAsync`
- `TransactionInvoicePreviewGenerateAsync`
- `TransactionInvoicePreviewPostingGuardGetAsync`
- `TransactionSageSubmissionRequeueAsync`
- `SageInboundDiagnosticsGetAsync`
- `DocumentsCreateEmailDraftAsync`
- `GetWaitStatsDashboardAsync`
- `GetCymBuildSchemaDashboardAsync`
- `GetInvoiceRequestItems`
- `DeleteInvoiceRequestByGuid`
- `JobInvoiceScheduleGuidGetAsync`
- `JobInvoiceProcessingModeGetAsync`
- `JobInvoicePendingTriggerCountGetAsync`
- `JobInvoiceGenerateFromPendingTriggersAsync`
- `AuthorisationDecisionAsync`
- `DocumentsResolveAsync`
- `DocumentsListAsync`
- `BuildDocumentsDownloadUrl`
- `DocumentsCreateFolderAsync`
- `DocumentsUploadAsync`
- `DocumentsDeleteAsync`
- `GetHolidaysAsync`
- `GetNonActivityEvents`
- `GetScheduledActivities`
- `GetOrganisationalUnitForUser`
- `GetTeamMembersAsync`
- `LogUsageAsync`
- `GetUsageReportAsync`
- `JobClosureDecisionAsync`
- `DataObjectDeleteAsync`
- `GetSharePointUrl`
- `ConvertTiffToPngAsync`
- `GetSharePointDocumentsAsync`
- `GetSharePointSitesAsync`
- `LoadMetaDataAsync`
- `GetEntityType`
- `MenuItemPostAsync`
- `GridMenuItemPostAsync`
- `ReadDataObjectAsync`
- `SharePointCreate`
- `PrepareDecodedDataObject`
- `GetWidgetLayout`
- `UpdateUserSignature`
- `SaveWidgetLayoutToDb`
- `AddressLookupSearchAsync`
- `AddressLookupResolveAsync`
- `DocumentsNavigationGetAsync`
- `DocumentsResolveAsync`
- `SageHealthGetAsync`
- `SageFetchSalesOrdersAsync`
- `SageFetchCustomerTransactionsAsync`
- `SageCreateSalesOrderAsync`
- `SageFetchSalesOrdersItemsAsync`
- `SageFetchCustomerTransactionItemsAsync`
- `SageInboundPaymentSyncEnqueueAsync`
- `SageInboundPaymentSyncAsync`

## gRPC proto RPCs

### `services/Concursus.API/Protos/core.proto`

- `AddressLookupResolve`
- `AddressLookupSearch`
- `AuthorisationDecision`
- `CheckPhotoFilesAtUrl`
- `ConvertTiffToPng`
- `DashboardMetricsGet`
- `DataObjectDelete`
- `DataObjectGet`
- `DataObjectListGet`
- `DataObjectListGetSingle`
- `DataObjectUpsert`
- `DeleteInvoiceRequest`
- `DocumentsCreateEmailDraft`
- `DocumentsCreateFolder`
- `DocumentsDelete`
- `DocumentsDownload`
- `DocumentsDownloadFile`
- `DocumentsDownloadFileStream`
- `DocumentsList`
- `DocumentsNavigationGet`
- `DocumentsResolve`
- `DocumentsUpload`
- `DownloadFile`
- `DropDownDataList`
- `DropDownListDefinitionGet`
- `EntityPropertyDefaultGet`
- `EntityTypeGet`
- `ExecuteGridMenuAction`
- `ExecuteMenuItemPost`
- `GetAutomatedInvoicingKPI`
- `GetCymBuildSchemaDashboard`
- `GetHolidays`
- `GetInvoiceRequestItemsByGuid`
- `GetMergeDocumentItemIncludes`
- `GetMergeDocumentItems`
- `GetMergeDocumentItemTypes`
- `GetNonActivityEvents`
- `GetOrganisationalUnitForUser`
- `GetQuoteDashboardData`
- `GetScheduledActivities`
- `GetScheduledWork`
- `GetSharePointURL`
- `GetSignatoryInfo`
- `GetTeamMembers`
- `GetThresholdsForOrgUnit`
- `GetUsageReport`
- `GetWaitStatsDashboard`
- `GridDataList`
- `GridDefinitionList`
- `GridDefinitionUpsert`
- `GridViewColumnDefinitionDelete`
- `GridViewColumnDefinitions`
- `GridViewColumnDefinitionUpsert`
- `GridViewDefinitions`
- `GridViewDefinitionUpsert`
- `ImportLegacyStatuses`
- `JobClosureDecision`
- `JobInvoiceGenerateFromPendingTriggers`
- `JobInvoicePendingTriggerCountGet`
- `JobInvoiceProcessingModeGet`
- `JobInvoiceProcessingModeSet`
- `JobInvoiceSchedulesGet`
- `LogUsage`
- `MetadataMigrationApply`
- `MetadataMigrationBuildIdentityMap`
- `MetadataMigrationDashboard`
- `MetadataMigrationDiff`
- `MetadataMigrationRunCreate`
- `MetadataMigrationRunGet`
- `MetadataMigrationRuns`
- `MetadataMigrationStage`
- `MetadataMigrationStagedRows`
- `MetadataMigrationValidate`
- `NotificationsForUserGet`
- `ObjectSecurityList`
- `ObjectSharePointPathCollectionGet`
- `OnboardingMigrationApply`
- `OnboardingMigrationAuditDashboard`
- `OnboardingMigrationBusinessUnitGroups`
- `OnboardingMigrationDiff`
- `OnboardingMigrationReport`
- `OnboardingMigrationRuns`
- `OnboardingMigrationStage`
- `OnboardingMigrationStagedData`
- `OnboardingMigrationValidate`
- `OrganisationalUnitsGet`
- `RecentItemsCreate`
- `RecentItemsGet`
- `RecordHistoryGet`
- `RecordUrlGet`
- `ReportingParametersGet`
- `ReportingTemplatesGet`
- `ReportUpsert`
- `SageCreateSalesOrder`
- `SageFetchCustomerTransactions`
- `SageFetchSalesOrders`
- `SageHealthGet`
- `SageInboundDiagnosticsGet`
- `SageInboundPaymentSync`
- `SageInboundPaymentSyncEnqueue`
- `SageInboundReceiptMaterialisationAutoCorrect`
- `SaveWidgetLayout`
- `ScheduleItemsGet`
- `ScheduleItemStatusGet`
- `ScheduleItemTypesGet`
- `SharePointCreate`
- `SharePointDocumentDetailsGet`
- `SharepointDocumentsGet`
- `SystemDataGet`
- `TransactionInvoicePreviewGenerate`
- `TransactionInvoicePreviewGetCurrent`
- `TransactionInvoicePreviewPostingGuardGet`
- `TransactionInvoicePrintModelGet`
- `TransactionSageSubmissionRequeue`
- `UpdateUserSignature`
- `UploadFile`
- `UploadFileChunk`
- `UserGetByGuid`
- `UserGroupDelete`
- `UserGroupList`
- `UserInfoGet`
- `UserPreferencesGet`
- `UsersGet`
- `WidgetLayoutGet`

### `services/Concursus.API/Protos/assistant_v1.proto`

- `CreateConversation`
- `GetConversation`
- `ListConversationsForUser`
- `RenameConversation`
- `ArchiveConversation`
- `DeleteConversation`
- `GetConversationMessages`
- `SendMessage`
- `RegenerateAnswer`
- `ConvertAnswerToChecklist`
- `SaveAnswerAsPlaybook`
- `SearchKnowledge`
- `GetKnowledgeItem`
- `GetKnowledgeCategories`
- `GetFeaturedKnowledge`
- `GetRelatedKnowledge`
- `CreateKnowledgeItem`
- `UpdateKnowledgeItem`
- `PublishKnowledgeItem`
- `ReplaceKnowledgeItemVersion`
- `ListKnowledgeVersions`
- `ListWorkflowTemplates`
- `GetWorkflowTemplate`
- `StartWorkflowRun`
- `AdvanceWorkflowRun`
- `CompleteWorkflowRun`
- `ListPlaybooks`
- `GetPlaybook`
- `CreateWorkflowTemplate`
- `UpdateWorkflowTemplate`
- `PublishWorkflowTemplate`
- `FeatureWorkflowTemplate`
- `CreateBookmark`
- `ListBookmarks`
- `DeleteBookmark`
- `UpdateBookmark`
- `CreateUploadSession`
- `CompleteUpload`
- `ListUserUploads`
- `AnalyzeScreenshot`
- `AttachUploadToConversation`
- `GetAdminDashboardSummary`
- `ListFeedback`
- `ListFailedAnswers`
- `ListContentGaps`
- `AssignContentGap`
- `ResolveContentGap`
- `GetTopQuestions`
- `GetTopicTrends`
- `GetFailedAnswerSummary`
- `GetSourceUsageSummary`
- `GetWorkflowUsageSummary`

### `services/Concursus.API/Protos/dms.proto`

- `CheckMailerQueueForMessageId`
- `CopyDmsEntry`
- `CreateDirectory`
- `DeleteDmsEntry`
- `FileDownload`
- `FileUpload`
- `FilingDestinationSearch`
- `GetFlattenedFilingStructure`
- `GetImmutableExchangeRestId`
- `GetMailerQueueItem`
- `GetPathContent`
- `MailerQueueUpsert`
- `ProcessAllMailerQueues`
- `ProcessMailerQueue`
- `RenameDmsEntry`

### `services/Concursus.API/Protos/translation.proto`

- `TranslateText`

## API service overrides

### `services/Concursus.API/Services/CoreService.cs`

- `GetWaitStatsDashboard`
- `GetCymBuildSchemaDashboard`
- `JobInvoiceProcessingModeGet`
- `JobInvoiceProcessingModeSet`
- `JobInvoiceSchedulesGet`
- `JobInvoicePendingTriggerCountGet`
- `JobInvoiceGenerateFromPendingTriggers`
- `ImportLegacyStatuses`
- `CheckPhotoFilesAtUrl`
- `ConvertTiffToPng`
- `DataObjectDelete`
- `GetSignatoryInfo`
- `DataObjectGet`
- `DataObjectListGetSingle`
- `DataObjectUpsert`
- `EntityPropertyDefaultGet`
- `EntityTypeGet`
- `GetMergeDocumentItemIncludes`
- `GetMergeDocumentItems`
- `GetMergeDocumentItemTypes`
- `GetSharePointURL`
- `NotificationsForUserGet`
- `ObjectSecurityList`
- `ObjectSharePointPathCollectionGet`
- `OrganisationalUnitsGet`
- `RecentItemsCreate`
- `RecordHistoryGet`
- `RecordUrlGet`
- `SaveWidgetLayout`
- `ScheduleItemsGet`
- `ScheduleItemStatusGet`
- `ScheduleItemTypesGet`
- `SharePointCreate`
- `SharePointDocumentDetailsGet`
- `SharepointDocumentsGet`
- `UpdateUserSignature`
- `UploadFileChunk`
- `UserGetByGuid`
- `UserGroupList`
- `UserInfoGet`
- `UserPreferencesGet`
- `UsersGet`
- `LogUsage`
- `GetUsageReport`
- `GetQuoteDashboardData`
- `GetThresholdsForOrgUnit`
- `GetInvoiceRequestItemsByGuid`
- `DeleteInvoiceRequest`
- `JobClosureDecision`
- `AuthorisationDecision`
- `GetHolidays`
- `GetNonActivityEvents`
- `GetTeamMembers`
- `GetScheduledActivities`
- `GetOrganisationalUnitForUser`
- `UploadFile`

### `services/Concursus.API/Services/UiService.cs`

- `DashboardMetricsGet`
- `GetAutomatedInvoicingKPI`
- `WidgetLayoutGet`
- `DropDownDataList`
- `DropDownListDefinitionGet`
- `ExecuteMenuItemPost`
- `ExecuteGridMenuAction`
- `GridDataList`
- `GridDefinitionList`
- `GridViewColumnDefinitions`
- `GridViewDefinitions`
- `RecentItemsGet`

### `services/Concursus.API/Services/CoreService.Finance.cs`

- `TransactionInvoicePrintModelGet`
- `TransactionInvoicePreviewGenerate`
- `TransactionInvoicePreviewGetCurrent`
- `TransactionInvoicePreviewPostingGuardGet`

### `services/Concursus.API/Services/CoreService.Sage.cs`

- `SageInboundReceiptMaterialisationAutoCorrect`
- `SageInboundPaymentSync`
- `SageInboundPaymentSyncEnqueue`
- `SageInboundDiagnosticsGet`
- `SageHealthGet`
- `TransactionSageSubmissionRequeue`
- `SageFetchSalesOrders`
- `SageFetchCustomerTransactions`
- `SageCreateSalesOrder`

### `services/Concursus.API/Services/CoreService.MetadataMigration.cs`

- `MetadataMigrationRunCreate`
- `MetadataMigrationRuns`
- `MetadataMigrationRunGet`
- `MetadataMigrationStage`
- `MetadataMigrationValidate`
- `MetadataMigrationBuildIdentityMap`
- `MetadataMigrationApply`
- `MetadataMigrationDashboard`
- `MetadataMigrationStagedRows`
- `MetadataMigrationDiff`

## BlueGen usage

When asked to implement or debug a UI action, BlueGen should map the action to FormHelper, then to proto/API service, then EF/SQL. If no FormHelper method exists, propose adding or extending one rather than calling API directly from Razor.
