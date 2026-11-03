using Concursus.API.Client;
using Concursus.API.Client.Models;
using Concursus.API.Core;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using Microsoft.JSInterop;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Web;

namespace Concursus.PWA.Shared
{
    /// <summary>
    /// Reusable "Validate" button for the inline "Enter New Agent/Client/Asset Details"
    /// sections on the Enquiry detail page. Checks the fields the user has entered against
    /// existing Account/Asset records so an enquiry doesn't get raised against a duplicate.
    /// Mirrors the Validate/duplicate-check modal used on StructureDetail/AccountDetail/ContactDetail.
    /// </summary>
    public partial class DuplicateCheckButton : ComponentBase
    {
        [Parameter] public DataObject DataObject { get; set; }

        [Parameter] public EventCallback<DataObject> DataObjectChanged { get; set; }

        [Parameter] public EditPage editPageRef { get; set; }

        /// <summary>"Agent", "Client", or "Asset" - determines which fields to read and which duplicate check to run.</summary>
        [Parameter] public string EntityGroupSection { get; set; } = "";

        [Inject] private Concursus.API.Core.Core.CoreClient CoreClient { get; set; } = default!;
        [Inject] private UserService userService { get; set; } = default!;
        [Inject] private IJSRuntime JS { get; set; } = default!;
        [Inject] private ModalService modalService { get; set; } = default!;

        private bool ShowModal;
        private bool HasDuplicates;
        private bool IsBusy;
        private bool SecondaryModalIsVisible;
        private List<ComboDataItem> _duplicateItems = new();
        private Guid DuplicateSelection { get; set; }
        private IDictionary<string, object> _detailPageParameters = new Dictionary<string, object>();

        private string ButtonText = "Validate";
        private string ButtonCss = "btn btn-primary";

        /// <summary>The detail page used to preview a selected duplicate for this section.</summary>
        private string TargetPageUri => EntityGroupSection == "Asset" ? "StructureDetail" : "AccountDetail";

        /// <summary>The entity type of the record duplicates found for this section belong to.</summary>
        private string TargetEntityTypeGuid => EntityGroupSection == "Asset"
            ? "2cfbff39-93cd-436b-b8ca-b2fcf7609707"
            : "40476ecc-d19a-4de9-90df-e1f45cd72fb2";

        private string DuplicateNounSingular => EntityGroupSection == "Asset" ? "asset" : "account";
        private string DuplicateNounPlural => EntityGroupSection == "Asset" ? "assets" : "accounts";

        private System.Type? InformationPageComponentType => ResolvePageComponentType(TargetPageUri);

        private static readonly Dictionary<string, string> AgentFieldGuids = new()
        {
            { "Name", "0d99dfa1-7a65-49f1-9778-10dedd61b35a" },
            { "Number", "4efe55a4-ea67-4781-acda-dbe689ab18a4" },
            { "AddressLine1", "349ab91f-f339-4590-a770-1ddd14d5ba72" },
            { "AddressLine2", "cd51e11b-92dc-4520-b087-17e23658a79c" },
            { "AddressLine3", "ef5f4ae4-99ed-4b25-8a4c-b6004816690a" },
            { "Town", "d58cfea9-9d98-4b50-b2f7-22d3a78aa70d" },
            { "CountyId", "7ea7cab9-f5bc-4b00-ae06-276e3b772910" },
            { "Postcode", "55364f4d-a927-43e2-a11b-005457a8fd23" },
        };

        private static readonly Dictionary<string, string> ClientFieldGuids = new()
        {
            { "Name", "87b67081-eeff-4d43-b7c9-c9aaaa54c9d8" },
            { "Number", "51e26095-a0df-4932-bc06-8cac9e9d5cf6" },
            { "AddressLine1", "2d99daeb-a2dc-48e9-b761-fd8c42f50cae" },
            { "AddressLine2", "78693eb4-7c2d-4b67-8945-273f035a375d" },
            { "AddressLine3", "09341613-8603-4811-bab2-5ce35a721a58" },
            { "Town", "edf92030-975c-4793-82d1-ef296f45b37f" },
            { "CountyId", "a0db71c1-2e2b-4559-95e4-9cebf2f01ba5" },
            { "Postcode", "0bc7e7a3-1c63-4d8e-8707-a891a8877716" },
        };

        private static readonly Dictionary<string, string> AssetFieldGuids = new()
        {
            { "Number", "baebbe4e-7820-4e79-b9a1-c303c56008b0" },
            { "AddressLine1", "c5c24d56-2d0b-4ecd-bc4e-1072388c7832" },
            { "AddressLine2", "65e43d43-c4b7-4ae6-a5e2-3cb36637876a" },
            { "AddressLine3", "821b0477-26de-4f10-8491-a72284fc22ca" },
            { "Town", "9b0704c8-baf7-49d0-a569-9ac3fdab27e8" },
            { "CountyId", "ef3e7956-4ecb-49b0-b930-8db68d545ffb" },
            { "Postcode", "9d4cc1f8-caa4-447c-902e-cc293d237410" },
        };

        /// <summary>The "Enter New X Details" checkbox EntityPropertyGuid, per section.</summary>
        private static readonly Dictionary<string, string> SectionCheckboxGuids = new()
        {
            { "Agent", "9c333b64-2f44-4833-bd6b-68571178f195" },
            { "Client", "0279fba4-01d2-4c7c-aee9-a29cfe45174c" },
            { "Asset", "83730cf2-ac67-4064-9590-0a94800d03ce" },
        };

        /// <summary>The relationship/lookup field (AgentAccountId/ClientAccountId/PropertyId) EntityPropertyGuid, per section.</summary>
        private static readonly Dictionary<string, string> SectionLookupGuids = new()
        {
            { "Agent", "c6d3628b-9ef6-46e7-a04b-455d7256e180" },
            { "Client", "c1afb8a2-4596-4c64-8267-7f49b9be04d6" },
            { "Asset", "fe002e4d-3b56-499f-93da-5d43259cbc76" },
        };

        private string GetFieldValue(IReadOnlyDictionary<string, string> guids, string key)
        {
            if (!guids.TryGetValue(key, out var guid))
            {
                return "";
            }

            var property = DataObject?.DataProperties?.FirstOrDefault(p => p.EntityPropertyGuid == guid);

            if (property?.Value is null)
            {
                return "";
            }

            return property.Value.Unpack<StringValue>().Value ?? "";
        }

        private async Task OnValidateClickAsync()
        {
            if (DataObject is null || IsBusy)
            {
                return;
            }

            IsBusy = true;
            ButtonText = "Checking...";

            try
            {
                var formHelper = new FormHelper(CoreClient, Guid.Empty.ToString(), userService);

                if (EntityGroupSection is "Agent" or "Client")
                {
                    var guids = EntityGroupSection == "Agent" ? AgentFieldGuids : ClientFieldGuids;
                    var name = GetFieldValue(guids, "Name");

                    if (string.IsNullOrWhiteSpace(name))
                    {
                        await JS.InvokeVoidAsync("alert", $"Please enter a {EntityGroupSection.ToLowerInvariant()} name before validating.");
                        return;
                    }

                    var duplicates = await formHelper.DuplicateAccountsGet(name);

                    _duplicateItems = duplicates?.Duplicates
                        .Select(x => new ComboDataItem(new DropDownDataListItem { Value = x.Guid, Name = x.DisplaName }))
                        .ToList() ?? new List<ComboDataItem>();
                }
                else if (EntityGroupSection == "Asset")
                {
                    var number = GetFieldValue(AssetFieldGuids, "Number");
                    var addressLine1 = GetFieldValue(AssetFieldGuids, "AddressLine1");
                    var addressLine2 = GetFieldValue(AssetFieldGuids, "AddressLine2");
                    var addressLine3 = GetFieldValue(AssetFieldGuids, "AddressLine3");
                    var town = GetFieldValue(AssetFieldGuids, "Town");
                    var countyGuid = GetFieldValue(AssetFieldGuids, "CountyId");
                    var postcode = GetFieldValue(AssetFieldGuids, "Postcode");

                    if (new[] { number, addressLine1, addressLine2, addressLine3, town, postcode }.All(string.IsNullOrEmpty))
                    {
                        await JS.InvokeVoidAsync("alert", "Please enter an address before validating.");
                        return;
                    }

                    var duplicates = await formHelper.DuplicateAssetsGet("", number, addressLine1, addressLine2, addressLine3, town, countyGuid, postcode);

                    _duplicateItems = duplicates?.Duplicates
                        .Select(x => new ComboDataItem(new DropDownDataListItem { Value = x.Guid, Name = x.FormattedAddress }))
                        .ToList() ?? new List<ComboDataItem>();
                }
                else
                {
                    return;
                }

                HasDuplicates = _duplicateItems.Count > 0;
                ShowModal = true;
            }
            finally
            {
                IsBusy = false;

                if (ButtonText != "Validated")
                {
                    ButtonText = "Validate";
                }
            }
        }

        private Task OnNativeLookupValueChangedAsync(Guid value)
        {
            DuplicateSelection = value;
            return Task.CompletedTask;
        }

        private Task<IReadOnlyList<ComboDataItem>> LoadDuplicateValues(string searchText)
        {
            var items = _duplicateItems
                .Where(x => string.IsNullOrWhiteSpace(searchText) ||
                            x.Name.Contains(searchText, StringComparison.OrdinalIgnoreCase))
                .ToList();

            return Task.FromResult<IReadOnlyList<ComboDataItem>>(items);
        }

        /// <summary>
        /// Uses the existing record the user selected instead of creating a duplicate: unchecks the
        /// "Enter New X Details" checkbox and points the section's lookup field (AgentAccountId /
        /// ClientAccountId / PropertyId) at the selected record, in place on the shared Enquiry DataObject.
        /// </summary>
        private async Task DuplicatePresent()
        {
            if (DuplicateSelection == Guid.Empty || DataObject is null)
            {
                await JS.InvokeVoidAsync("alert", "No record has been selected");
                return;
            }

            if (!SectionCheckboxGuids.TryGetValue(EntityGroupSection, out var checkboxGuid) ||
                !SectionLookupGuids.TryGetValue(EntityGroupSection, out var lookupGuid))
            {
                return;
            }

            var checkboxProperty = DataObject.DataProperties?.FirstOrDefault(p => p.EntityPropertyGuid == checkboxGuid);
            var lookupProperty = DataObject.DataProperties?.FirstOrDefault(p => p.EntityPropertyGuid == lookupGuid);

            // Mutate both values in memory BEFORE notifying EditPage of either change. The
            // checkbox update triggers a server round-trip (HandleFormHelper -> UpsertDataObject)
            // that recalculates field visibility (e.g. unhides this lookup field). If the lookup
            // value isn't set yet when that happens, the field gets revealed empty and the
            // follow-up round-trip for the lookup value doesn't reliably resync it. Setting both
            // values first means whichever round-trip fires first already reflects the final state.
            if (checkboxProperty is not null)
            {
                //Set the checkbox to false (deselect)
                checkboxProperty.Value = Any.Pack(new BoolValue { Value = false });
            }

            if (lookupProperty is not null)
            {
                lookupProperty.Value = Any.Pack(new StringValue { Value = DuplicateSelection.ToString() });
            }

            if (editPageRef is not null)
            {
                if (checkboxProperty is not null)
                {
                    await editPageRef.HandleInputUpdated(new Concursus.Components.Shared.Classes.InputUpdatedArgs
                    {
                        NewValue = checkboxProperty.Value,
                        EntityId = new Guid(checkboxGuid)
                    });
                }

                if (lookupProperty is not null)
                {
                    await editPageRef.HandleInputUpdated(new Concursus.Components.Shared.Classes.InputUpdatedArgs
                    {
                        NewValue = lookupProperty.Value,
                        EntityId = new Guid(lookupGuid)
                    });
                }

                StateHasChanged();
            }

            ShowModal = false;
            MarkValidated();

            await DataObjectChanged.InvokeAsync(DataObject);
            StateHasChanged();
        }

        /// <summary>
        /// The selected/found records are not a match - close the modal and let the user continue.
        /// </summary>
        private void DuplicateNotPresent()
        {
            ShowModal = false;
            MarkValidated();
            StateHasChanged();
        }

        private void CloseModal()
        {
            ShowModal = false;

            if (!HasDuplicates)
            {
                MarkValidated();
            }

            StateHasChanged();
        }

        private void MarkValidated()
        {
            ButtonText = "Validated";
            ButtonCss = "btn btn-success";
            editPageRef?.DataHasBeenValidated(EntityGroupSection);
        }

        private void HandleModelOnClick()
        {
            if (SecondaryModalIsVisible || DuplicateSelection == Guid.Empty)
            {
                return;
            }

            try
            {
                var parentDataObjectReference = new DataObjectReference(DuplicateSelection.ToString(), TargetEntityTypeGuid);
                var serializeParentDataObjectReferenced = HttpUtility.UrlEncode(JsonConvert.SerializeObject(parentDataObjectReference));
                var modalId = Guid.NewGuid().ToString();

                _detailPageParameters.Clear();
                _detailPageParameters.Add("EntityTypeGuid", TargetEntityTypeGuid);
                _detailPageParameters.Add("Windowed", true);
                _detailPageParameters.Add("CloseWindow", EventCallback.Factory.Create(this, CloseSecondaryModal));
                _detailPageParameters.Add("RecordGuid", DuplicateSelection.ToString());
                _detailPageParameters.Add("SerializedDataObjectReference", serializeParentDataObjectReferenced);
                _detailPageParameters.Add("ParentDataObjectReference", parentDataObjectReference);
                _detailPageParameters.Add("ReturnUrl", "");
                _detailPageParameters.Add("IsInformationPage", true);
                _detailPageParameters.Add("ModalId", modalId);

                modalService.RegisterModal(modalId, parentDataObjectReference);

                SecondaryModalIsVisible = true;
            }
            catch (Exception)
            {
                // Preview is a convenience only - swallow and just not open it if it fails to build.
            }
        }

        private void CloseSecondaryModal()
        {
            SecondaryModalIsVisible = false;
            StateHasChanged();
        }

        private static System.Type? ResolvePageComponentType(string? pageUri)
        {
            var trimmedPageUri = pageUri?.Trim();

            if (string.IsNullOrWhiteSpace(trimmedPageUri))
            {
                return null;
            }

            var candidates = new[]
            {
                trimmedPageUri,
                $"{trimmedPageUri}, Concursus.PWA",
                $"Concursus.PWA.Pages.{trimmedPageUri}",
                $"Concursus.PWA.Pages.{trimmedPageUri}, Concursus.PWA",
                $"Concursus.PWA.Shared.{trimmedPageUri}",
                $"Concursus.PWA.Shared.{trimmedPageUri}, Concursus.PWA"
            };

            foreach (var candidate in candidates)
            {
                var type = System.Type.GetType(candidate, throwOnError: false, ignoreCase: false);

                if (type is not null)
                {
                    return type;
                }
            }

            return AppDomain.CurrentDomain
                .GetAssemblies()
                .Select(assembly => assembly.GetType($"Concursus.PWA.Pages.{trimmedPageUri}", throwOnError: false, ignoreCase: false)
                                 ?? assembly.GetType($"Concursus.PWA.Shared.{trimmedPageUri}", throwOnError: false, ignoreCase: false)
                                 ?? assembly.GetType(trimmedPageUri, throwOnError: false, ignoreCase: false))
                .FirstOrDefault(type => type is not null);
        }
    }
}
