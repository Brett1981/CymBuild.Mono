//using Concursus.API.Client;
//using Concursus.API.Client.Models;
//using Concursus.API.Core;
//using Concursus.Components.Shared.Controls;
//using Concursus.PWA.Classes;
//using Concursus.PWA.Pages;
//using Google.Protobuf.WellKnownTypes;
//using Grpc.Core;
//using Microsoft.AspNetCore.Components;
//using Microsoft.JSInterop;
//using System.Dynamic;
//using Telerik.Blazor.Components;
//using static Concursus.Components.Shared.Controls.MessageDisplay;
//using EntityProperty = Concursus.API.Core.EntityProperty;
//using Concursus.API.Core;
//using Concursus.API.Client.Classes;
//using Concursus.Components.Shared.Classes;
//using Microsoft.AspNetCore.Components.Web;

//namespace Concursus.PWA.Shared;

//public partial class GridButtonMenu
//{
//    private GridViewDefinition _value;
//    [Parameter] public string EntityTypeGuid { get; set; } = Guid.Empty.ToString();
//    [Parameter] public GridViewDefinition ViewDefinition { get; set; }
//    [Parameter] public string ParentGuid { get; set; }
//    [Parameter] public DataObjectReference ParentDataObjectReference { get; set; }
//    [Parameter] public string GridCode { get; set; }
//    [Parameter] public string GridViewCode { get; set; }
//    [Parameter] public EventCallback GridUpdated { get; set; }

// //CBLD-260 public DynamicBatchGridView DBG { get; set; } private bool ShowGrid { get; set; } =
// true; private bool ShowEntityProperties { get; set; } = false; private API.Client.FormHelper?
// _formHelper; private EntityType EntityTypeProperties { get; set; } private List<EntityProperty>
// EntityProperties { get; set; } private EntityPropertyGroup EntityPropertyGroup { get; set; }
// private IEnumerable<ExpandoObject> BatchSelection { get; set; } private string ButtonText { get;
// set; } = "Next >>";

// private IDictionary<string, object> _detailPageParameters = new Dictionary<string, object>();
// private System.Type? _detailPageType; private string modalId = Guid.Empty.ToString();

// protected string ErrorMessage { get; set; } = ""; protected MessageDisplay.ShowMessageType
// MessageType { get; set; } = MessageDisplay.ShowMessageType.Error; protected MessageDisplay?
// messageDisplay; protected string PageMethod { get; set; } = "Not Set";

// private string? GridCodeSelection { get; set; } private string HeaderCssIcon { get; set; } = "";
// private string HeaderText { get; set; } = ""; private string? LoadPageUrl { get; set; } private
// bool ModalWindowIsVisible { get; set; } = false; private bool windowIsClosable { get; set; } =
// true; private string? WindowTitle { get; set; }

// protected FormHelper? formHelper;

// private IDictionary<string, object> DetailPageParameters = new Dictionary<string, object>();
// public BulkChangeAction? ClickedItem { get; set; } public List<BulkChangeAction> MenuItems { get;
// set; } public TelerikWindow ModalWindow { get; set; }

// public class BulkChangeAction { public string Text { get; set; } = ""; public string Icon { get;
// set; } = "";

// public List<BulkChangeAction> Items { get; set; }

// }

// // GridButtonMenu.razor.cs public void OpenBatchEditModal() { // Get selected items from
// DynamicGridView BatchSelection = DBG.GetSelectionForBatch();

// if (!BatchSelection.Any()) { throw new Exception("You must select an item to proceed."); }

// // Trigger the modal for batch editing ModalWindowIsVisible = true; StateHasChanged(); }

// public void OnError(Exception error) { if (string.IsNullOrEmpty(error.Message)) return;

// ErrorMessage = error.Message; PageMethod = (error.Data.Contains("PageMethod") ?
// error.Data["PageMethod"]?.ToString() : "Not Set") ?? string.Empty;

// if (error.Data.Contains("MessageType")) MessageType =
// (MessageDisplay.ShowMessageType)(error.Data["MessageType"] ??
// MessageDisplay.ShowMessageType.Information); else MessageType =
// MessageDisplay.ShowMessageType.Error; messageDisplay?.ShowError(true);
// //customErrorBoundary.Recover(); StateHasChanged();

// }

// public void OpenBulkModal() { var (parentDataObjectReference,
// serializedParentDataObjectReference) = PWAFunctions.ProcessDataObjectReference(modalService,
// ParentDataObjectReference, ParentGuid, ViewDefinition.EntityTypeGuid);

// modalId = Guid.NewGuid().ToString(); _detailPageParameters.Clear();
// _detailPageParameters.Add("_EntityTypeGuid",
// PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(EntityTypeGuid).ToString());
// _detailPageParameters.Add("Windowed", true); _detailPageParameters.Add("CloseWindow",
// EventCallback.Factory.Create(this, CloseWindowCross)); //The RecordGuid refers to the modal
// content - in this case, the client details. _detailPageParameters.Add("RecordGuid",
// Guid.Empty.ToString()); _detailPageParameters.Add("GridUpdated",
// EventCallback.Factory.Create(this, GridUpdated));
// _detailPageParameters.Add("SerializedDataObjectReference", serializedParentDataObjectReference);
// _detailPageParameters.Add("ParentDataObjectReference", ParentDataObjectReference);
// _detailPageParameters.Add("ModalId", modalId); _detailPageParameters.Add("IsDetailWindowed",
// true); //_detailPageParameters.Add("inputUpdated", EventCallback.Factory.Create(this,
// HandleInputUpdated)); _detailPageParameters.Add("GridCode", GridCode);
// _detailPageParameters.Add("ParentGuid", ParentGuid); _detailPageParameters.Add("ViewDefinition",
// ViewDefinition); _detailPageParameters.Add("ButtonText", "Next >>");

// modalService.RegisterModal(modalId, ParentDataObjectReference);

// ModalWindowIsVisible = true; StateHasChanged();

// }

// protected void CloseWindowCross() { ModalWindowIsVisible = false;

// ShowGrid = true; ShowEntityProperties = false; ButtonText = "Next >>"; }

// //CBLD-265 protected async Task<Task> OnClickHandler(BulkChangeAction item) { try { formHelper =
// new FormHelper(coreClient, EntityTypeGuid, userService);

// if (item.Text == "Bulk Change") { try { OpenBulkModal();

// } catch (Exception ex) { Console.WriteLine(ex); } }

// } catch (Exception ex) { ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
// ex.Data.Add("PageMethod", "BatchButtonMenu/OnClickHandler()"); OnError(ex); }

// return Task.CompletedTask; }

// /**
// * CBLD-265: Ensures that the actions for the action button are always the right ones.
// * **/ protected override void OnParametersSet() { reloadButton(); base.OnParametersSet(); }

// public async void reloadButton() { try { MenuItems = new List<BulkChangeAction> { new() { Text =
// "Actions", Items = new List<BulkChangeAction> { new() { Text = "Bulk Change", Icon = "bi-stack" }
// } } };

// StateHasChanged();

// } catch (Exception ex) { ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
// ex.Data.Add("PageMethod", "BatchButtonMenu/OnInitialized()"); OnError(ex); } }

// private string GetParentGuid() { try { // Retrieve the value associated with the "RecordGuid //
// (ParentDataObjectReference)" key when loading a DynamicGrid if
// (DetailPageParameters.TryGetValue("RecordGuid", out var parentGuid)) return
// parentGuid?.ToString(); } catch (Exception ex) { ex.Data.Add("MessageType",
// MessageDisplay.ShowMessageType.Error); ex.Data.Add("PageMethod", "ButtonMenu/GetParentGuid()");
// OnError(ex); }

//        // If the key is not found, you can return a default value or handle it
//        // as needed
//        return Guid.Empty.ToString();
//    }
//}