using Concursus.API.Client;
using Concursus.API.Core;
using Concursus.PWA.Classes;
using Concursus.PWA.Services;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using System.Collections;
using System.Net.Http.Json;
using Telerik.Blazor.Components;
using Telerik.DataSource;
using static Concursus.PWA.Shared.MessageDisplay;
using static Concursus.PWA.Shared.PostcodeLookupTab;

namespace Concursus.PWA.Shared
{
    public partial class PostcodeLookupButton : ComponentBase
    {
        //PARAMETERS
        [Parameter] public DataObject DataObject { get; set; }

        [Parameter] public EventCallback<DataObject> DataObjectChanged { get; set; }

        [Parameter] public EventCallback RefreshParent { get; set; }

        [Parameter] public EditPage editPageRef { get; set; }
        // E.g. An enquiry could have agent and client section - we use this
        // to define what part of the record we want to fill out.
        [Parameter] public string EntityGroupSection { get; set; } = "";

        private bool LockScreenIfNoAPICredentials { get; set; } = false;
        private string LockedScreenErrorMessage { get; set; } = "";

        //Error handling
        protected string ErrorMessage { get; set; } = "";

        protected string PageMethod { get; set; } = "Not Set";
        protected MessageDisplay.ShowMessageType MessageType { get; set; } = MessageDisplay.ShowMessageType.Error;
        private MessageDisplay _messageDisplay = new();

        private API.Client.FormHelper? _formHelper;

        //VALUE ENTERED BY THE USER
        private string AddressSearchInput = "";

        //private bool forceAPI { get; set; } = false;

        //DROPDOWN OPTIONS
        private List<AddressSearchResult> addressRecommendations;

        private List<AddressResponse> postcodeRecommendations;

        private string DropdownSelectionForPostcode { get; set; } = "";
        private string DropdownSelectionForAddress { get; set; } = "";

        //CONTROL VARIABLE FOR READONLY FORM
        private bool IsReadOnlyForm { get; set; } = true;

        //Selected value from a given dropdown.
        private string SelectedAddressRecommendation { get; set; }

        private string SelectedPostcodeRecommendation { get; set; }

        private IEnumerable<AddressSearchResult> addressSearchResults;
        private IEnumerable<AddressResponse> postcodeSearchResults;

        //Postcode address details.
        private AddressResponse ResolvedAddress { get; set; } = new();

        //ISO CODES
        private List<CountryWithISO> ISOCodes = new();

        private string selectedISO { get; set; } = "GBR";

        //MODAL RELATED CONTROL VARIABLES.
        private bool WindowIsVisible { get; set; } = false;

        private TelerikWindow? ModalWindow { get; set; }

        private int nmbrOfAPICalls { get; set; } = 0;

        private string InputFieldText { get; set; } = "Enter Postcode:";
        private string SearchButtonTex { get; set; } = "Search";
        private string IsInvalid { get; set; } = "";
        private string IsInvalidMsg { get; set; } = "";

        private bool ShowDoneButton { get; set; } = false;
        private bool ShowManualEntryButton { get; set; } = false;
        private bool ShowOverwriteAddressButton { get; set; } = false;
        private bool DisableAddressSearch { get; set; } = false;
        private string ManualAddressEntryText { get; set; } = "Enter Address Manually";

        private TelerikComboBox<ComboDataItem, Guid> CountryCombo { get; set; } = new();
        private Dictionary<string, string> CountryComboOptions { get; set; } = new();
        private TelerikComboBox<ComboDataItem, Guid> CountyCombo { get; set; } = new();
        private Dictionary<string, string> CountyComboOptions { get; set; } = new();

        private int DebounceDelay { get; set; } = 100;

        //For the loader
        private bool LoaderVisible { get; set; } = false;

        /// <summary>
        /// Closes/opens the modal
        /// </summary>
        private void OpenModal()
        {
            WindowIsVisible = true;
        }


        /// <summary>
        /// Loads up the ISO codes (along with the name of the country) from a JSON file located in
        /// the wwwwroot folder.
        /// </summary>
        private async Task LoadCountryISOCodes()
        {
            ISOCodes = await Http.GetFromJsonAsync<List<CountryWithISO>>(
                "PostCodeLookup_Assets/country_iso_codes.json");
        }
        protected override async Task OnInitializedAsync()
        {
            _formHelper = new API.Client.FormHelper(
                coreClient,
                sageIntegrationService,
                PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(DataObject.EntityTypeGuid).ToString(),
                userService);

            await LoadCountryISOCodes();
        }

        public async Task OnError(Exception error)
        {
            if (string.IsNullOrEmpty(error.Message))
            {
                Console.WriteLine("DynamicBatchGridView: Error message is empty. Aborting.");
                return;
            }

            ErrorMessage = error.Message;
            PageMethod = error.Data.Contains("PageMethod")
                ? error.Data["PageMethod"]?.ToString() ?? "Not Set"
                : "Not Set";
            Console.WriteLine($"DynamicBatchGridView: PageMethod = {PageMethod}");

            if (error.Data.Contains("MessageType"))
            {
                MessageType = (ShowMessageType)(error.Data["MessageType"] ?? ShowMessageType.Information);
            }
            else
            {
                MessageType = ShowMessageType.Error;
                Console.WriteLine("DynamicBatchGridView: MessageType not found in error.Data. Defaulted to Error.");
            }

            // Extract all exception data
            var exceptionData = error.Data.Count > 0
                ? error.Data.Cast<DictionaryEntry>().ToDictionary(
                    de => de.Key?.ToString() ?? "UnknownKey",
                    de => de.Value!)
                : null;

            if (exceptionData != null)
            {
                foreach (var kvp in exceptionData)
                    Console.WriteLine($"    {kvp.Key} = {kvp.Value}");
            }

            _messageDisplay.UpdateExceptionData(exceptionData);
            _messageDisplay.UpdateStackTrace(error.StackTrace ?? "No additional details available.");
            _messageDisplay.ShowError(true);

            Console.WriteLine("DynamicBatchGridView: MessageDisplay updated and error shown.");

            // AI Error Reporting (only for actual errors)
            if (MessageType == ShowMessageType.Error)
            {
                try
                {
                    var context = new
                    {
                        ErrorMessage = error.Message,
                        PageMethod = error.Data.Contains("PageMethod") ? error.Data["PageMethod"]?.ToString() ?? "UnknownMethod" : "UnknownMethod",
                        StackTrace = error.StackTrace ?? "No stack trace",
                        AdditionalInfo = error.Data.Contains("AdditionalInfo") ? error.Data["AdditionalInfo"]?.ToString() ?? "None" : "None",
                        Data = error.Data.Cast<DictionaryEntry>()
                            .ToDictionary(
                                de => de.Key?.ToString() ?? "UnknownKey",
                                de => de.Value?.ToString() ?? "null"
                            )
                    };

                    var log = InteractionTracker.GetAllLogs();
                    var description = InteractionTracker.GetReplicationStepsFormatted(InteractionTracker);
                    error.Data["UserInteractionLog"] = description;
                    Console.WriteLine($"DynamicBatchGridView: UserInteractionLog = {description}");

                    var result = await AiErrorReporter.ReportAsync(error, context);

                    if (result != null && !string.IsNullOrEmpty(result.UiMessage))
                    {
                        _messageDisplay.SetMessage(result.UiMessage, result.MessageType);
                        _messageDisplay.ShowError(true);
                    }
                    else
                    {
                        Console.WriteLine("DynamicBatchGridView: AI Error Reporter returned no UI message.");
                    }
                }
                catch (Exception aiEx)
                {
                    Console.WriteLine($"DynamicBatchGridView: Exception in AI Error Reporter: {aiEx.Message}\n{aiEx.StackTrace}");
                }
            }

            StateHasChanged();
        }

        private async Task SearchByAddress(bool forceAPI = false)
        {
            try
            {
                if (_formHelper is null)
                {
                    throw new InvalidOperationException("FormHelper is not initialised.");
                }

                addressRecommendations = null;
                postcodeRecommendations = null;
                DropdownSelectionForAddress = string.Empty;
                DropdownSelectionForPostcode = string.Empty;

                var response = await _formHelper.AddressLookupSearchAsync(
                    AddressSearchInput,
                    selectedISO,
                    forceAPI);

                if (!string.IsNullOrWhiteSpace(response.ErrorReturned))
                {
                    throw new InvalidOperationException(response.ErrorReturned);
                }

                if (response.AddressSuggestions.Count > 0)
                {
                    addressRecommendations = response.AddressSuggestions
                        .Select(x => new AddressSearchResult
                        {
                            Id = x.Id ?? string.Empty,
                            Suggestion = x.Suggestion ?? string.Empty,
                            Udprn = x.Udprn ?? string.Empty,
                            Urls = x.Urls ?? string.Empty
                        })
                        .ToList();

                    DropdownSelectionForAddress = string.Empty;
                }
                else if (response.PostcodeAddresses.Count > 0)
                {
                    postcodeRecommendations = response.PostcodeAddresses
                        .Select(MapLookupAddress)
                        .ToList();

                    DropdownSelectionForPostcode = string.Empty;
                }

                StateHasChanged();
            }
            catch (Exception ex)
            {
                ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
                ex.Data["AdditionalInfo"] = "An error occurred while trying to search for an address.";
                ex.Data["PageMethod"] = "PostcodeLookupButton/SearchByAddress()";
                await OnError(ex);
            }
        }
        private async Task ResolveAddress(string id)
        {
            if (string.IsNullOrWhiteSpace(SelectedAddressRecommendation))
            {
                return;
            }

            try
            {
                if (_formHelper is null)
                {
                    throw new InvalidOperationException("FormHelper is not initialised.");
                }

                var response = await _formHelper.AddressLookupResolveAsync(id, selectedISO);

                if (!string.IsNullOrWhiteSpace(response.ErrorReturned))
                {
                    throw new InvalidOperationException(response.ErrorReturned);
                }

                if (response.Address is null)
                {
                    throw new InvalidOperationException("No address was returned by the lookup service.");
                }

                var mapped = MapLookupAddress(response.Address);
                PopulateReadOnlyFields(mapped);
                StateHasChanged();
            }
            catch (Exception ex)
            {
                ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
                ex.Data["AdditionalInfo"] = "An error occurred while trying to resolve an address.";
                ex.Data["PageMethod"] = "PostcodeLookupButton/ResolveAddress()";
                await OnError(ex);
            }
        }
        private async Task AddressNotListedHandle()
        {
            nmbrOfAPICalls++;

            if (nmbrOfAPICalls == 1)
            {
                await SearchByAddress(true);
            }
            else if (nmbrOfAPICalls == 2)
            {
                InputFieldText = "Enter streetname:";
                IsInvalid = "is-invalid";
                IsInvalidMsg = "Nothing found. Try searching by address or another property. Alternatively, enter the address manually on the right.";
                ShowManualEntryButton = true;
                nmbrOfAPICalls = 0;
            }
            else
            {
                ResetForm();
            }

            StateHasChanged();
        }

        /// <summary>
        /// Resets the form variables.
        /// </summary>
        private void ResetForm()
        {
            //Reset search values.
            InputFieldText = "Enter Postcode:";
            IsInvalid = "";
            IsInvalidMsg = "";
            IsReadOnlyForm = true;

            //Reset buttons
            ShowDoneButton = false;
            ShowManualEntryButton = false;
            ShowOverwriteAddressButton = false;

            //Enable input field for searching addresses + reset button text.
            DisableAddressSearch = false;
            ManualAddressEntryText = "Enter Address Manually";

            //Reset anything to do with selection.
            AddressSearchInput = "";
            ResolvedAddress = new();
            addressRecommendations = null;
            postcodeRecommendations = null;

            //Reset dropdown
            CountrySelection = Guid.Empty;
            CountySelection = Guid.Empty;
        }

        private static object GetProperty(dynamic obj, string name)
        {
            var prop = obj.GetType().GetProperty(name);
            return prop?.GetValue(obj, null) ?? "";
        }

        /// <summary>
        /// Populates the readonly field when a selected address is confirmed. Handles dropdowns +
        /// text replacement where needed.
        /// </summary>
        /// <param name="selectedAddress"> </param>
        private void PopulateReadOnlyFields(dynamic selectedAddress)
        {
            ResolvedAddress.Uprn =
             GetProperty(selectedAddress, "Uprn")?.ToString() ??
             GetProperty(selectedAddress, "UPRN")?.ToString();

            ResolvedAddress.AuthorityCode =
               GetProperty(selectedAddress, "AuthorityCode")?.ToString();

            ResolvedAddress.Line1 =
                GetProperty(selectedAddress, "Line1")?.ToString() ??
                GetProperty(selectedAddress, "Line_1")?.ToString();

            ResolvedAddress.Line2 =
                GetProperty(selectedAddress, "Line2")?.ToString() ??
                GetProperty(selectedAddress, "Line_2")?.ToString();

            ResolvedAddress.Town =
                GetProperty(selectedAddress, "Town")?.ToString() ??
                GetProperty(selectedAddress, "Post_town")?.ToString();

            ResolvedAddress.County =
                GetProperty(selectedAddress, "County")?.ToString();

            ResolvedAddress.Postcode =
                GetProperty(selectedAddress, "Postcode")?.ToString();

            ResolvedAddress.Country =
                GetProperty(selectedAddress, "Country")?.ToString();

            ResolvedAddress.Latitude =
                GetProperty(selectedAddress, "Latitude") as double?;

            ResolvedAddress.Longitude =
                GetProperty(selectedAddress, "Longitude") as double?;

            //Now, add the building number.
            if (selectedAddress.Number == "")
            {
                var houseNumber = System.Text.RegularExpressions.Regex.Match(ResolvedAddress.Line1, @"^\d+\w*").Value;

                if (houseNumber == "")
                {
                    houseNumber = System.Text.RegularExpressions.Regex.Match(ResolvedAddress.Line2, @"^\d+\w*").Value;

                    //Double-check it's not ""!
                    if (houseNumber != "")
                        ResolvedAddress.Line2 = ResolvedAddress.Line2.Replace(houseNumber, "");
                }
                else
                {
                    ResolvedAddress.Line1 = ResolvedAddress.Line1.Replace(houseNumber, "");
                }

                ResolvedAddress.Number = houseNumber;
            }

            //Populate the dropdowns as well for the countries.
            if (CountryComboOptions.ContainsKey(ResolvedAddress.Country))
            {
                CountrySelection = new Guid(CountryComboOptions[ResolvedAddress.Country]);
            }
            else if (CountyComboOptions.ContainsKey(ResolvedAddress.County))
            {
                CountySelection = new Guid(CountyComboOptions[ResolvedAddress.County]);
            }

            ShowDoneButton = true;
            ShowOverwriteAddressButton = true;

            StateHasChanged();
        }

        /// <summary>
        /// Binds the item selected from the dropdown and binds the values to the read-only fields.
        /// (For Addresses)
        /// </summary>
        private async Task SelectAddressSuggestion()
        {
            try
            {
                var selection = addressRecommendations
                    ?.FirstOrDefault(x => x.Urls == DropdownSelectionForAddress);

                if (selection is null)
                {
                    return;
                }

                if (selection.Suggestion == "Address Not Found, Update Addresses?")
                {
                    await AddressNotListedHandle();
                }
                else
                {
                    nmbrOfAPICalls = 0;
                    SelectedAddressRecommendation = selection.Urls ?? string.Empty;
                    await ResolveAddress(selection.Id);
                }
            }
            catch (Exception ex)
            {
                ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
                ex.Data["AdditionalInfo"] = "An error occurred while trying select an address to resolve.";
                ex.Data["PageMethod"] = "PostcodeLookupButton/SelectAddressSuggestion()";
                await OnError(ex);
            }
        }

        /// <summary>
        /// Binds the item selected from the dropdown and binds the values to the read-only fields.
        /// (For Postcodes)
        /// </summary>
        private async Task SelectPostcodeSuggestion()
        {
            try
            {
                var selection = postcodeRecommendations
                    ?.FirstOrDefault(x => x.Uprn == DropdownSelectionForPostcode);

                if (selection is null)
                {
                    return;
                }

                if (selection.FormattedAddress == "Address Not Found, Update Addresses?")
                {
                    await AddressNotListedHandle();
                }
                else
                {
                    nmbrOfAPICalls = 0;
                    PopulateReadOnlyFields(selection);
                }
            }
            catch (Exception ex)
            {
                ex.Data["MessageType"] = MessageDisplay.ShowMessageType.Error;
                ex.Data["AdditionalInfo"] = "An error occurred while trying select a postcode to resolve.";
                ex.Data["PageMethod"] = "PostcodeLookupButton/SelectPostcodeSuggestion()";
                await OnError(ex);
            }
        }

        private async Task ConfirmAddress()
        {
            WindowIsVisible = false;
            LoaderVisible = true;
            StateHasChanged();

            Console.WriteLine("Before populae!");
            await PopulateDataObject();

            //Reset the form and close the modal.
            ResetForm();

            editPageRef.SetHasChangedToTrue();

            LoaderVisible = false;
            StateHasChanged();
        }

        /// <summary>
        /// Enables the read-only form, allowing the user to enter the address manually. This is
        /// then saved to the parent record.
        /// </summary>
        private void EnableReadOnlyForm()
        {
            IsReadOnlyForm = !IsReadOnlyForm;
            ResolvedAddress = new();

            if (IsReadOnlyForm)
            {
                DisableAddressSearch = false;
                ManualAddressEntryText = "Enter Address Manually";
            }
            else
            {
                DisableAddressSearch = true; //Disable the search fields
                ManualAddressEntryText = "Cancel Manual Entry";
            }

            StateHasChanged();
        }

        /// <summary>
        /// Enables the read-only fields so that the user can overwrite the populated address. Could
        /// have used EnableReadOnlyForm() but seperated for simplicity.
        /// </summary>
        private void OverwriteAddress()
        {
            IsReadOnlyForm = !IsReadOnlyForm;
            StateHasChanged();
        }

        /// <summary>
        /// Reads the options into the Country dropdown.
        /// </summary>
        /// <param name="args"> ComboBoxReadEventArgs args </param>
        /// <returns> </returns>
        private async Task DropdownReadCountries(ComboBoxReadEventArgs args)
        {
            try
            {
                var dropDownDataListRequest = new DropDownDataListRequest
                {
                    Guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid("49255823-3c63-49a3-85b9-9dc8bc6e2fdc")
                        .ToString(),
                    ParentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(DataObject.Guid).ToString(),
                    RecordGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(DataObject.Guid).ToString(),
                    CurrentSelectedValueGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(Guid.Empty.ToString())
                        .ToString()
                };

                if (args.Request.Filters.Count > 0)
                {
                    var compositeFilter = new DataObjectCompositeFilter
                    {
                        LogicalOperator = FilterOperator.Contains.ToString()
                    };

                    foreach (var filterDescriptor in args.Request.Filters)
                    {
                        var filter = filterDescriptor as FilterDescriptor;
                        var userInput = filter?.Value.ToString();
                        var method = filter?.Operator.ToString();

                        var filterItem = new DataObjectFilter
                        {
                            Guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid("49255823-3c63-49a3-85b9-9dc8bc6e2fdc")
                                .ToString(),
                            Value = new Value { StringValue = userInput },
                            Operator = method,
                            ColumnName = "Name",
                            DataType = "string"
                        };

                        compositeFilter.Filters.Add(filterItem);
                    }

                    dropDownDataListRequest.Filters.Add(compositeFilter);
                }
                var dropDownDataListReply = await coreClient.DropDownDataListAsync(dropDownDataListRequest);

                //Add the options into CountryCombo - this will be used for reference
                //when populating the entity properties.
                CountryComboOptions = new();

                foreach (var item in dropDownDataListReply.Items)
                {
                    CountryComboOptions.Add(item.Name, item.Value);
                }

                args.Data = dropDownDataListReply.Items
                    .Select(item => new ComboDataItem(item))
                    .ToList();

                StateHasChanged();
            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("AdditionalInfo", "An error occurred while trying to read the countries into the dropdown!");
                ex.Data.Add("PageMethod", "PostcodeLookupButton/DropdownReadCountries()");
                OnError(ex);
            }
        }

        /// <summary>
        /// Reads the options into the County dropdown.
        /// </summary>
        /// <param name="args"> ComboBoxReadEventArgs args </param>
        /// <returns> </returns>
        private async Task DropdownReadCounties(ComboBoxReadEventArgs args)
        {
            try
            {
                var dropDownDataListRequest = new DropDownDataListRequest
                {
                    Guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid("f8b699d2-f678-47c2-b185-060a7d609fa8")
                        .ToString(),
                    ParentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(DataObject.Guid).ToString(),
                    RecordGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(DataObject.Guid).ToString(),
                    CurrentSelectedValueGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(Guid.Empty.ToString())
                        .ToString()
                };

                if (args.Request.Filters.Count > 0)
                {
                    var compositeFilter = new DataObjectCompositeFilter
                    {
                        LogicalOperator = FilterOperator.Contains.ToString()
                    };

                    foreach (var filterDescriptor in args.Request.Filters)
                    {
                        var filter = filterDescriptor as FilterDescriptor;
                        var userInput = filter?.Value.ToString();
                        var method = filter?.Operator.ToString();

                        var filterItem = new DataObjectFilter
                        {
                            Guid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid("f8b699d2-f678-47c2-b185-060a7d609fa8")
                                .ToString(),
                            Value = new Value { StringValue = userInput },
                            Operator = method,
                            ColumnName = "Name",
                            DataType = "string"
                        };

                        compositeFilter.Filters.Add(filterItem);
                    }

                    dropDownDataListRequest.Filters.Add(compositeFilter);
                }
                var dropDownDataListReply = await coreClient.DropDownDataListAsync(dropDownDataListRequest);

                CountyComboOptions = new();

                foreach (var item in dropDownDataListReply.Items)
                {
                    CountyComboOptions.Add(item.Name, item.Value);
                }

                args.Data = dropDownDataListReply.Items
                    .Select(item => new ComboDataItem(item))
                    .ToList();

                StateHasChanged();
            }
            catch (Exception ex)
            {
                ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
                ex.Data.Add("AdditionalInfo", "An error occurred while trying to read the counties into the dropdown!");
                ex.Data.Add("PageMethod", "PostcodeLookupButton/DropdownReadCounties()");
                OnError(ex);
            }
        }
        private static AddressResponse MapLookupAddress(LookupAddressRecordContract source)
        {
            return new AddressResponse
            {
                Number = source.Number ?? string.Empty,
                FormattedAddress = source.FormattedAddress ?? string.Empty,
                Line1 = source.Line1 ?? string.Empty,
                Line2 = string.IsNullOrWhiteSpace(source.Line2) ? null : source.Line2,
                Town = source.Town ?? string.Empty,
                County = string.IsNullOrWhiteSpace(source.County) ? null : source.County,
                Postcode = source.Postcode ?? string.Empty,
                Country = source.Country ?? string.Empty,
                Uprn = string.IsNullOrWhiteSpace(source.Uprn) ? null : source.Uprn,
                LocalAuthority = string.IsNullOrWhiteSpace(source.LocalAuthority) ? null : source.LocalAuthority,
                AuthorityCode = string.IsNullOrWhiteSpace(source.AuthorityCode) ? null : source.AuthorityCode,
                Latitude = source.HasLatitude ? source.Latitude : null,
                Longitude = source.HasLongitude ? source.Longitude : null
            };
        }
    }
}