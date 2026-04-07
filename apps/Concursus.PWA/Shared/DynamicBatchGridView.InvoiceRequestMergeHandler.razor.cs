using Concursus.API.Client;
using Concursus.API.Client.Models;
using Concursus.PWA.Classes;
using Google.Protobuf.WellKnownTypes;
using Microsoft.AspNetCore.Components;
using Microsoft.JSInterop;
using Newtonsoft.Json;
using Org.BouncyCastle.Asn1.X509.Qualified;
using System.Dynamic;
using System.Security.Cryptography.Xml;
using System.Web;



namespace Concursus.PWA.Shared;

public partial class DynamicBatchGridView
{

    private bool ShowInvoiceMergeButton { get; set; } = false;
    private bool isMergeLoadingScreenVisible { get; set; } = false;
    private List<Guid> InvoiceReqsToMerge { get; set; } = new List<Guid>();


    private static class EntityPropertiesToCopy
    {
        public const string JobID       = "dddabd42-c753-48fa-800f-a73c88fcadcd";
        public const string Notes       = "f22eb049-a999-4485-9838-751b3f577293";
        public const string Consultant  = "8c1f4236-36a8-44ed-af70-c43f56840943";

    }





    /// <summary>
    /// After each selection, the function checks if the records can be merged into one (new) record. 
    /// </summary>
    /// <param name="SelectedItemsInList">List of selected items</param>
    /// <returns name="CanBeMerged">Boolean value which controls the merge button.</returns>
    private bool CanInvoiceRequestRecordsBeMerged(IEnumerable<ExpandoObject> SelectedItemsInList)
    {
        bool CanBeMerged = false;

        //Conditions that must be met.
        bool MoreThanOneItemSelected = SelectedItems.Count() > 1;
        bool IsInvoiceRequestGridView = ViewDefinition?.Code == "INVOICEREQUESTS";


        if (!IsInvoiceRequestGridView || !MoreThanOneItemSelected)
            return CanBeMerged;

        try
        {
            //HashSets for unique values -> this is what we use to define if the values are unique, therefore can be merged.
            var JobNumbers = new HashSet<string>();
            var FinanceAccounts = new HashSet<string>();


            foreach (var sI in SelectedItems)
            {
                //Transform into IDictionary so that we can read the values.
                var InvoiceReqAsDict = sI as IDictionary<string, object>;

                if (InvoiceReqAsDict != null)
                    foreach (var InvoiceReq in InvoiceReqAsDict)
                    {
                        //Extract the number && Finance Account. Both hashshets should only 1 value each,
                        //if the selected items have matching properties.
                        if (InvoiceReq.Key == "Number")
                            JobNumbers.Add(InvoiceReq.Value.ToString());
                        else if (InvoiceReq.Key == "FinanceAccountID" && InvoiceReq.Value.ToString() != "")
                            FinanceAccounts.Add(InvoiceReq.Value.ToString());
                        else if (InvoiceReq.Key == "Guid")
                            InvoiceReqsToMerge.Add(new Guid(InvoiceReq.Value.ToString()));
                    }
            }

            //Both hashsets should only have 1 value each (if they are i
            if (JobNumbers.Count == 1 && FinanceAccounts.Count == 1)
                CanBeMerged = true;
               

            return CanBeMerged;
        }
        catch(Exception ex)
        {
            Console.WriteLine(ex.ToString());
        }

        return CanBeMerged;
    }

    /// <summary>
    /// 
    /// </summary>
    private async Task MergeInvoiceRequests()
    {
       
        try
        {
            // Display confirmation dialog
            bool isConfirmed = await JsRuntime.InvokeAsync<bool>("confirm", "Are you sure you wish to merge the selected invoice Requests?");
            if (!isConfirmed)
                return;


            isMergeLoadingScreenVisible = true;

            StateHasChanged();


            var formHelperForInvoiceReq = new FormHelper(coreClient, sageIntegrationService, "27a13441-73c4-425a-8b55-dc048dabe6bb", userService);
            var entityType = await formHelperForInvoiceReq.GetEntityType();

            string Notes = "";


            /*
                ==================================================
                =       INVOICE REQUEST HEADER                   =
                ==================================================
             */

            //Create empty/new dataobjects - invoice request + items.
            var NewInvoiceReqDataObject  = await formHelperForInvoiceReq.ReadDataObjectAsync("00000000-0000-0000-0000-000000000000", new DataObjectReference("00000000-0000-0000-0000-000000000000", "27a13441-73c4-425a-8b55-dc048dabe6bb"));
            

            bool ProcessingFirstInvoice = true;
            //Process the header/invoice requests first.
            foreach (var req in InvoiceReqsToMerge)
            {
         
                var CurrentInvoiceReq = await formHelperForInvoiceReq.ReadDataObjectAsync(req.ToString(), new DataObjectReference(req.ToString(), "27a13441-73c4-425a-8b55-dc048dabe6bb"), false);

                //Only extract JobID + Consultant for the first invoice request -> Use first invoice request.
                if (ProcessingFirstInvoice)
                {
                    //Populate the properties we would like to copy.
                    var PackedJobId = CurrentInvoiceReq.DataProperties.Where(x => x.EntityPropertyGuid == EntityPropertiesToCopy.JobID).FirstOrDefault();
                    var PackedConsultant = CurrentInvoiceReq.DataProperties.Where(x => x.EntityPropertyGuid == EntityPropertiesToCopy.Consultant).FirstOrDefault();

                    //Extract Job ID.
                    if (PackedJobId != null)
                    {
                        var NewInvoiceReqJobID = NewInvoiceReqDataObject.DataProperties.Where(x => x.EntityPropertyGuid == EntityPropertiesToCopy.JobID).FirstOrDefault();
                        NewInvoiceReqJobID.Value = PackedJobId.Value;
                    }
                    //Extract Consultant
                    else if(PackedConsultant != null)
                    {
                        var NewInvoiceReqConsultant = NewInvoiceReqDataObject.DataProperties.Where(x => x.EntityPropertyGuid == EntityPropertiesToCopy.Consultant).FirstOrDefault();
                        NewInvoiceReqConsultant.Value = PackedConsultant.Value;
                    }

                    ProcessingFirstInvoice = false;
                }

                //Check if the record was created from automation. 
                var SourceTypeInt = CurrentInvoiceReq.DataProperties.Where(x => x.EntityPropertyGuid == "39cab0f1-fc6a-4705-823b-ddc608f3edef").FirstOrDefault();
                var SourceGuid = CurrentInvoiceReq.DataProperties.Where(x => x.EntityPropertyGuid == "238c2ce0-75f4-466b-877f-d86dca9e45f9").FirstOrDefault();

                if (SourceTypeInt?.Value != null &&
                    SourceTypeInt.Value.TypeUrl != "type.googleapis.com/google.protobuf.Empty")
                {
                    var SourceTypeIntVal = SourceTypeInt.Value.Unpack<Int32Value>().Value;

                    if(SourceTypeIntVal != -1)
                    {
                        var SourceTypeToSet = NewInvoiceReqDataObject.DataProperties.Where(x => x.EntityPropertyGuid == "39cab0f1-fc6a-4705-823b-ddc608f3edef").FirstOrDefault();
                        SourceTypeToSet.Value = SourceTypeInt.Value;
                    }
                       
                }
                else if (SourceGuid?.Value != null && SourceGuid.Value.TypeUrl != "type.googleapis.com/google.protobuf.Empty")
                {
                    if(SourceTypeInt.Value.TypeUrl != "type.googleapis.com/google.protobuf.Empty")
                    {
                        var SourceGuidVal = SourceTypeInt.Value.Unpack<StringValue>().Value;

                        if (SourceGuidVal != Guid.Empty.ToString())
                        {
                            var SourceGuidValToSet = NewInvoiceReqDataObject.DataProperties.Where(x => x.EntityPropertyGuid == "39cab0f1-fc6a-4705-823b-ddc608f3edef").FirstOrDefault();
                            SourceGuidValToSet.Value = SourceGuid.Value;
                        }
                    }
                }

                //Unpack the notes -> we need combine the various notes. 
                var PackedNotes = CurrentInvoiceReq.DataProperties.Where(x => x.EntityPropertyGuid == EntityPropertiesToCopy.Notes).FirstOrDefault();

                if (PackedNotes != null && PackedNotes.Value.TypeUrl != "type.googleapis.com/google.protobuf.Empty")
                    Notes = Notes + PackedNotes.Value.Unpack<StringValue>().Value  + " \n" ;
            }


            //Assign the comment
            var NewInvoiceReqComment = NewInvoiceReqDataObject.DataProperties.Where(x => x.EntityPropertyGuid == EntityPropertiesToCopy.Notes).FirstOrDefault();

            if (NewInvoiceReqComment != null) 
                NewInvoiceReqComment.Value = Any.Pack(new StringValue() { Value = Notes});
            

            //Create the new invoice request.
            var (message, UpsertedNewInvoiceRequest ) = await formHelperForInvoiceReq.UpsertDataObject(NewInvoiceReqDataObject, null, false);

            //Mark original invoice requests as merged!
            if(message == "")
            {
                NewInvoiceReqDataObject = UpsertedNewInvoiceRequest;

                foreach(var invReq in InvoiceReqsToMerge)
                    await MarkOriginalInvoiceRequestAsMerged(invReq.ToString());
            }

            /*
                ==================================================
                =       INVOICE REQUEST ITEMS                    =
                ==================================================
             */

            //Get the invoice request items.
            List<string> InvoiceReqItemGuids = new List<string>();
            foreach (var reqItem in InvoiceReqsToMerge)
            {
                var InvoiceReqItemsToProcess = await formHelperForInvoiceReq.GetInvoiceRequestItems(reqItem.ToString());

                foreach (var i in InvoiceReqItemsToProcess)
                    InvoiceReqItemGuids.Add(i);
            }



            var formHelperForInvoiceReqItems = new FormHelper(coreClient, sageIntegrationService, "ad87cd7f-7181-401a-9f63-8dfc8abec5f1", userService);
            await formHelperForInvoiceReqItems.GetEntityType();

            //Create the new invoice request.
            foreach (var invReqItem in InvoiceReqItemGuids)
            {
                //Load the current invoice request item record.
                var CurrentInvoiceReqItem = await formHelperForInvoiceReqItems.ReadDataObjectAsync(invReqItem, new DataObjectReference(invReqItem, "ad87cd7f-7181-401a-9f63-8dfc8abec5f1"));
                
                var InvoiceReqItemRequestID =  CurrentInvoiceReqItem.DataProperties.Where(x => x.EntityPropertyGuid == "395d9343-c3c2-4dd1-a20c-a254ba403724").FirstOrDefault();

                if(InvoiceReqItemRequestID != null)
                    //Assign the new invoice req ID to the item -> the item should appear under the new invoice req.
                    InvoiceReqItemRequestID.Value = Any.Pack(new StringValue() { Value = NewInvoiceReqDataObject.Guid });
                
                //Upsert the invoice request
                await formHelperForInvoiceReqItems.UpsertDataObject(CurrentInvoiceReqItem, null, false);
            }

            ResetGrid();

            //Rebind grid.
            GridRef?.Rebind();

            //Open new invoice request.
            OpenMergedInvoiceRequest(NewInvoiceReqDataObject.Guid);

        }
        catch (Exception ex)
        {
            await OnError(ex);
            ResetGrid();
        }
    }


    /// <summary>
    /// Resets certain parm
    /// </summary>
    private async void ResetGrid()
    {


        //Close loading screen & hide merge button..
        isMergeLoadingScreenVisible = false;
        ShowInvoiceMergeButton = false;

        //Reset items
        SelectedItems = new List<ExpandoObject>(); ;
        InvoiceReqsToMerge = new List<Guid>();

        await RefreshMe();

        StateHasChanged();
    }


    /// <summary>
    /// Removes an invoice request once it is merged with another one.
    /// </summary>
    private async Task<bool> MarkOriginalInvoiceRequestAsMerged(string InvoiceRequestGuid)
    {
       
        var formHelperForInvoiceReq = new FormHelper(coreClient, sageIntegrationService, "27a13441-73c4-425a-8b55-dc048dabe6bb", userService);
        var entityType = await formHelperForInvoiceReq.GetEntityType();

        bool IsDeleted = await formHelperForInvoiceReq.DeleteInvoiceRequestByGuid(InvoiceRequestGuid);

        return IsDeleted;
    }


    /// <summary>
    /// Opens up the newly merged invoice request in a modal.
    /// </summary>
    /// <param name="InvoiceRequestGuid"></param>
    private void OpenMergedInvoiceRequest(string InvoiceRequestGuid)
    {

        DataObjectReference _parentDataObjectReference = new DataObjectReference( InvoiceRequestGuid, "27a13441-73c4-425a-8b55-dc048dabe6bb" );
        var _serializedParentDataObjectReference = HttpUtility.UrlEncode(JsonConvert.SerializeObject(_parentDataObjectReference));



        modalId = InvoiceRequestGuid;
        _detailPageParameters.Clear();
        _detailPageParameters.Add("EntityTypeGuid", PWAFunctions.ParseAndReturnEmptyGuidIfInvalid("27a13441-73c4-425a-8b55-dc048dabe6bb").ToString());
        _detailPageParameters.Add("Windowed", true);
        _detailPageParameters.Add("CloseWindow", EventCallback.Factory.Create(this, CloseWindow));
        _detailPageParameters.Add("RecordGuid", InvoiceRequestGuid);
        _detailPageParameters.Add("GridUpdated", EventCallback.Factory.Create(this, GridUpdated));
        _detailPageParameters.Add("SerializedDataObjectReference", _serializedParentDataObjectReference);
        _detailPageParameters.Add("ParentDataObjectReference", _parentDataObjectReference);
        _detailPageParameters.Add("ModalId", modalId);
        _detailPageParameters.Add("IsDetailWindowed", true);
        _detailPageParameters.Add("MergeSuccessMsg", "Succesfully created merged invoice request.");

        modalService.RegisterModal(modalId, _parentDataObjectReference);

        WindowIsVisible = true;
    }

}

