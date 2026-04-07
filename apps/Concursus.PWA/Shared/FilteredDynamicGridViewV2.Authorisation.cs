using Concursus.API.Core;
using Concursus.PWA.Classes;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Telerik.DataSource;

namespace Concursus.PWA.Shared
{
    public partial class FilteredDynamicGridViewV2 : ComponentBase, IDisposable
    {
        // -----------------------------
        // Authorisation (AUTHOREVIEW)
        // -----------------------------
        private enum AuthorisationEntityFilter
        {
            All = 0,
            Enquiries = 1,
            Quotes = 2,
            Jobs = 3
        }

        private bool _authorisationIsUpdating;
        private AuthorisationEntityFilter _authorisationFilter = AuthorisationEntityFilter.All;

        // UI state
        private bool AuthorisationMyItemsOnly { get; set; } = false;

        // KPI counts
        private int AuthorisationTotalPending { get; set; } = 0;
        private int AuthorisationJobsPending { get; set; } = 0;
        private int AuthorisationQuotesPending { get; set; } = 0;
        private int AuthorisationEnquiriesPending { get; set; } = 0;

        // Filters applied to the grid ReadItems pipeline (AUTHOREVIEW only)
        private DataCompositeFilter? AuthorisationFilters { get; set; } = null;

        // CSS helpers
        private string AuthorisationAllCss => _authorisationFilter == AuthorisationEntityFilter.All ? "k-button k-primary" : "k-button";
        private string AuthorisationEnquiriesCss => _authorisationFilter == AuthorisationEntityFilter.Enquiries ? "k-button k-primary" : "k-button";
        private string AuthorisationQuotesCss => _authorisationFilter == AuthorisationEntityFilter.Quotes ? "k-button k-primary" : "k-button";
        private string AuthorisationJobsCss => _authorisationFilter == AuthorisationEntityFilter.Jobs ? "k-button k-primary" : "k-button";

        // Switch callback
        private EventCallback<bool> AuthorisationMyItemsChanged =>
            EventCallback.Factory.Create<bool>(this, ToggleAuthorisationMyItemsAsync);

        // Concurrency / cancellation (prevents stacking / looping / races)
        private readonly SemaphoreSlim _authRefreshLock = new(1, 1);
        private CancellationTokenSource? _authCts;
        private bool _authInitialised = false;

        // -----------------------------
        // Column detection (IMPORTANT)
        // -----------------------------
        private string DetermineEntityTypeColumnName()
        {
            // Your grid screenshot shows a "Type" column. Some views use EntityTypeName.
            var cols = ViewDefinition?.Columns;
            if (cols == null) return "Type";

            if (cols.Any(c => string.Equals(c.Name, "EntityTypeName", StringComparison.OrdinalIgnoreCase)))
                return "EntityTypeName";

            if (cols.Any(c => string.Equals(c.Name, "Type", StringComparison.OrdinalIgnoreCase)))
                return "Type";

            return "Type";
        }

        private string DetermineCanActionForUserColumnName()
        {
            var cols = ViewDefinition?.Columns;
            if (cols == null) return "CanActionForUser";

            var match = cols.FirstOrDefault(c =>
                string.Equals(c.Name, "CanActionForUser", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(c.Name, "CanAction", StringComparison.OrdinalIgnoreCase));

            return match?.Name ?? "CanActionForUser";
        }

        // -----------------------------
        // Init (called once after first render)
        // -----------------------------
        private async Task EnsureAuthorisationInitialisedAsync()
        {
            if (!IsClosureReviewQueueGrid) return;
            if (_authInitialised) return;

            _authInitialised = true;

            BuildAuthorisationFilters();

            await RefreshAuthorisationKpisAsync(force: true);
            StateHasChanged();
        }

        // -----------------------------
        // UI Actions
        // -----------------------------
        private async Task SetAuthorisationTypeAsync(string? type)
        {
            if (!IsClosureReviewQueueGrid) return;

            _authorisationFilter = type switch
            {
                "Enquiries" => AuthorisationEntityFilter.Enquiries,
                "Quotes" => AuthorisationEntityFilter.Quotes,
                "Jobs" => AuthorisationEntityFilter.Jobs,
                _ => AuthorisationEntityFilter.All
            };

            await ApplyAuthorisationFiltersAndRefreshAsync();
        }

        private async Task ToggleAuthorisationMyItemsAsync(bool value)
        {
            if (!IsClosureReviewQueueGrid) return;

            AuthorisationMyItemsOnly = value;
            await ApplyAuthorisationFiltersAndRefreshAsync();
        }

        private async Task ApplyAuthorisationFiltersAndRefreshAsync()
        {
            _authorisationIsUpdating = true;
            StateHasChanged();

            // Cancel any in-flight refresh caused by previous click
            _authCts?.Cancel();
            _authCts?.Dispose();
            _authCts = new CancellationTokenSource();

            var ct = _authCts.Token;

            try
            {
                await _authRefreshLock.WaitAsync(ct);

                BuildAuthorisationFilters();

                // Rebind ONCE (reloads grid data)
                GridRef?.Rebind();

                // Refresh KPIs (no grid rebind here)
                await RefreshAuthorisationKpisAsync(force: true, ct: ct);

                StateHasChanged();
            }
            catch (OperationCanceledException)
            {
                // Expected when user clicks quickly
            }
            catch (Grpc.Core.RpcException ex) when (ex.StatusCode == Grpc.Core.StatusCode.Cancelled)
            {
                // Expected cancellation
            }
            finally
            {
                if (_authRefreshLock.CurrentCount == 0)
                    _authRefreshLock.Release();

                _authorisationIsUpdating = false;
                StateHasChanged();
            }
        }

        private void BuildAuthorisationFilters()
        {
            var root = new DataCompositeFilter { LogicalOperator = "AND" };

            // Entity filter
            if (_authorisationFilter != AuthorisationEntityFilter.All)
            {
                var entityTypeName = _authorisationFilter.ToString(); // Jobs / Quotes / Enquiries
                var typeOr = BuildOrEqualsFilterForExistingColumns(GetEntityTypeColumnCandidates(), entityTypeName);

                if (typeOr.Filters.Count > 0)
                    root.CompositeFilters.Add(typeOr);
            }

            // My Items
            if (AuthorisationMyItemsOnly)
            {
                var myItemsOr = BuildOrEqualsFilterForExistingColumns(GetCanActionColumnCandidates(), "1");

                if (myItemsOr.Filters.Count > 0)
                    root.CompositeFilters.Add(myItemsOr);
            }

            AuthorisationFilters = (root.Filters.Count == 0 && root.CompositeFilters.Count == 0) ? null : root;
        }

        // -----------------------------
        // KPI Refresh (atomic + cancel-safe)
        // -----------------------------
        private async Task RefreshAuthorisationKpisAsync(bool force, CancellationToken ct = default)
        {
            if (!IsClosureReviewQueueGrid) return;
            if (ViewDefinition is null) return;

            ct.ThrowIfCancellationRequested();

            // Compute into locals first so we don't partially update UI
            var all = await GetAuthorisationRowCountAsync(null, ct);
            ct.ThrowIfCancellationRequested();

            var jobs = await GetAuthorisationRowCountAsync("Jobs", ct);
            ct.ThrowIfCancellationRequested();

            var quotes = await GetAuthorisationRowCountAsync("Quotes", ct);
            ct.ThrowIfCancellationRequested();

            var enquiries = await GetAuthorisationRowCountAsync("Enquiries", ct);
            ct.ThrowIfCancellationRequested();

            // Atomic assignment (prevents "random" mixes)
            AuthorisationTotalPending = all;
            AuthorisationJobsPending = jobs;
            AuthorisationQuotesPending = quotes;
            AuthorisationEnquiriesPending = enquiries;

            DebugAuthorisationColumnsOnce();
        }

        private async Task<int> GetAuthorisationRowCountAsync(string? entityTypeName, CancellationToken ct)
        {
            var viewCode = ViewDefinition!.Code; // snapshot to avoid races during rapid clicking

            var req = new GridDataListRequest
            {
                GridCode = GridCode,
                GridViewCode = viewCode,
                Page = 1,
                PageSize = 1,
                ParentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid).ToString()
            };

            var root = new DataCompositeFilter { LogicalOperator = "and" };

            // IMPORTANT: add filters into an AND group with lowercase operator
            var andGroup = new DataCompositeFilter { LogicalOperator = "and" };

            // My Items
            if (AuthorisationMyItemsOnly)
            {
                var myItemsOr = BuildOrEqualsFilterForExistingColumns(GetCanActionColumnCandidates(), "1");
                if (myItemsOr != null)
                    andGroup.CompositeFilters.Add(myItemsOr); // compositeFilters keeps it robust
            }

            // Entity type
            if (!string.IsNullOrWhiteSpace(entityTypeName))
            {
                var typeOr = BuildOrEqualsFilterForExistingColumns(GetEntityTypeColumnCandidates(), entityTypeName);
                if (typeOr != null)
                    andGroup.CompositeFilters.Add(typeOr);
            }

            // Only add the AND group if it actually has content
            if (HasAnyFilterContent(andGroup))
                root.CompositeFilters.Add(andGroup);

            // Only add root if it actually has content
            if (HasAnyFilterContent(root))
                req.Filters.Add(root);

            var reply = await coreClient.GridDataListAsync(req, cancellationToken: ct);
            return (int)reply.TotalRows;
        }




        public void Dispose()
        {
            try
            {
                _authCts?.Cancel();
                _authCts?.Dispose();
            }
            catch
            {
                // swallow dispose exceptions
            }
        }

        private string[] GetEntityTypeColumnCandidates()
        {
            // Order matters: try server-projected names first, then UI aliases.
            return new[]
            {
        "EntityTypeName",
        "EntityType",
        "Type",
        "RecordType",
        "DataObjectType",
        "Entity"
    };
        }

        private string[] GetCanActionColumnCandidates()
        {
            return new[]
            {
        "CanActionForUser",
        "CanAction",
        "CanActionForUserInt",
        "CanActionForUserBit"
    };
        }

        private void DebugAuthorisationColumnsOnce()
        {
            if (!IsClosureReviewQueueGrid) return;
            if (ViewDefinition?.Columns == null) return;

            var cols = string.Join(", ", ViewDefinition.Columns.Select(c => c.Name));
            Console.WriteLine($"[AUTHOREVIEW] View '{ViewDefinition.Code}' columns: {cols}");
        }

        private static bool ViewHasColumn(string columnName, GridViewDefinition? viewDef)
        {
            return viewDef?.Columns?.Any(c => string.Equals(c.Name, columnName, StringComparison.OrdinalIgnoreCase)) == true;
        }

        private DataCompositeFilter? BuildOrEqualsFilterForExistingColumns(string[] candidates, string value)
        {
            var or = new DataCompositeFilter { LogicalOperator = "or" };

            foreach (var col in candidates)
            {
                if (!ViewHasColumn(col, ViewDefinition))
                    continue;

                or.Filters.Add(new DataFilter
                {
                    ColumnName = col,
                    Operator = "eq",
                    Guid = Guid.NewGuid().ToString(),
                    Value = Value.ForString(value)
                });
            }

            return HasAnyFilterContent(or) ? or : null;
        }


    }
}
