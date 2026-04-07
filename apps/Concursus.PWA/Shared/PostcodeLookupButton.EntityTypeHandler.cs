using Concursus.API.Core;
using Google.Protobuf.WellKnownTypes;


namespace Concursus.PWA.Shared
{
    /// <summary>
    /// Handles binding the dataobject values based on the entity type.
    /// </summary>
    public partial class PostcodeLookupButton
    {
        private Dictionary<string, string> EntityTypesWithAddresses { get; set; } = new Dictionary<string, string>()
        {
            { "Addresses", "45dd03aa-35f7-4b77-837d-6b563e3171f1" },
            { "Assets", "2cfbff39-93cd-436b-b8ca-b2fcf7609707" },
            { "Enquiries", "3b4f2df9-b6cf-4a49-9eed-2206473867a1" }

        };

        //Common entity properties for addresses by label.
        private Dictionary<string, string> AddressRelatedEntityProperties { get; set; } = new Dictionary<string, string>()
        {
            {"Number","c7421a54-ccef-4253-8cfd-5d07cb38e4f2"},
            {"AddressLine1","d3538bb9-07e3-4bac-8112-f3cd90feecf2" },
            {"AddressLine2", "902b2ade-469c-49e7-a8a5-5a9b301d5822" },
            {"AddressLine3", "c8b1d2ed-efd6-4882-b10e-62b6dbc5c7c0" },
            {"Town", "3794fbbd-ffbd-4990-882f-413a89cca773" },
            {"CountyId", "8cfd4e80-1d28-46f8-80c8-1e6a0fb63959" },
            {"Postcode", "eccd9ffa-0833-495f-9e39-872bbb9b7f22" },
            {"CountryId", "cd1300bc-3222-47a8-804d-f0c88e2b781a"},
        };

        //Common entity properties for assets by label.
        private Dictionary<string, string> AssetRelatedEntityProperties { get; set; } = new Dictionary<string, string>()
        {
            {"Number", "465ac77b-18c4-463f-86ea-f3c7f111454e"},
            {"AddressLine1", "c1282f49-d1f5-4de9-aa4d-293238e889b0" },
            {"AddressLine2", "43fbb638-9d69-4649-bf67-6371637fb8c4"},
            {"AddressLine3", "5056c116-88b2-4287-90cb-64f0a3f1ab1d"},
            {"Town", "41758df6-ab2b-4010-ba0c-a06e43fb10d1"},
            {"CountyId", "313686fc-322f-45cd-87bf-8131c333a1a9"},
            {"Postcode", "64e674c3-e42d-4a4b-8747-16212d7db19d"},
            {"CountryId", "a4a1588d-38b5-4a10-9c91-a2fccc2562f9"},
            {"Latitude","14bf36ce-da62-4dc3-b832-dd9b485ff32e" },
            {"Longitude", "8bdb4d5c-ebbf-4db3-86e4-1dd33e5b8bba" }
        };

        //Common entity properties for agents for enquiries by label.
        private Dictionary<string, string> EnquiryAgentRelatedEntityProperties { get; set; } = new Dictionary<string, string>()
        {
            {"Number", "4efe55a4-ea67-4781-acda-dbe689ab18a4"},
            {"AddressLine1", "349ab91f-f339-4590-a770-1ddd14d5ba72" },
            {"AddressLine2", "cd51e11b-92dc-4520-b087-17e23658a79c"},
            {"AddressLine3", "ef5f4ae4-99ed-4b25-8a4c-b6004816690a"},
            {"Town", "d58cfea9-9d98-4b50-b2f7-22d3a78aa70d"},
            {"CountyId", "7ea7cab9-f5bc-4b00-ae06-276e3b772910"},
            {"Postcode", "55364f4d-a927-43e2-a11b-005457a8fd23"},
            {"CountryId", "9b125b55-b220-4023-aa54-babcdf6afd1b"},
            {"AgentAssetJSONDetails", "7a86fe30-decc-41a0-b185-d8610471a0ea"},
        };

        //Common entity properties for clients for enquiries by label.
        private Dictionary<string, string> EnquiryClientRelatedEntityProperties { get; set; } = new Dictionary<string, string>()
        {
            {"Number", "51e26095-a0df-4932-bc06-8cac9e9d5cf6"},
            {"AddressLine1", "2d99daeb-a2dc-48e9-b761-fd8c42f50cae" },
            {"AddressLine2", "78693eb4-7c2d-4b67-8945-273f035a375d"},
            {"AddressLine3", "09341613-8603-4811-bab2-5ce35a721a58"},
            {"Town", "edf92030-975c-4793-82d1-ef296f45b37f"},
            {"CountyId", "a0db71c1-2e2b-4559-95e4-9cebf2f01ba5"},
            {"Postcode", "0bc7e7a3-1c63-4d8e-8707-a891a8877716"},
            {"CountryId", "3611ced8-53c2-4fa8-9acc-f508149bc716"},
            {"ClientAssetJSONDetails", "07dbe758-dadc-4e7d-8b8e-06a7ca374836"},
        };

        //Common entity properties for assets for enquiries by label.
        private Dictionary<string, string> EnquiryAssetRelatedEntityProperties { get; set; } = new Dictionary<string, string>()
        {
            {"Number", "baebbe4e-7820-4e79-b9a1-c303c56008b0"},
            {"AddressLine1", "c5c24d56-2d0b-4ecd-bc4e-1072388c7832" },
            {"AddressLine2", "65e43d43-c4b7-4ae6-a5e2-3cb36637876a"},
            {"AddressLine3", "821b0477-26de-4f10-8491-a72284fc22ca"},
            {"Town", "9b0704c8-baf7-49d0-a569-9ac3fdab27e8"},
            {"CountyId", "ef3e7956-4ecb-49b0-b930-8db68d545ffb"},
            {"Postcode", "9d4cc1f8-caa4-447c-902e-cc293d237410"},
            {"CountryId", "c1b43942-f1b0-42dd-8ab7-e1d2c02dfa1b"},
            {"AssetJSONDetails", "da16a588-9b8e-4e68-8207-f8beed32d893"},
        };

        //Common entity properties for assets for enquiries by label.
        private Dictionary<string, string> EnquiryFinanceRelatedEntityProperties { get; set; } = new Dictionary<string, string>()
        {
            {"Number", "a9562579-17c5-48d1-8537-442c50400294"},
            {"AddressLine1", "fa31ee6c-16e6-4f02-a1ff-d36f602181d0" },
            {"AddressLine2", "a36f3745-09e5-4f65-9cd7-3df45e87733c"},
            {"AddressLine3", "410f255a-ea84-42ea-93d0-00fe6f7054e2"},
            {"Town", "5af55e20-632e-41e3-8ac1-4acd475dff26"},
            {"CountyId", "70fea0ea-c279-484c-931d-2d23f42d01c3"},
            {"FinanceAssetJSONDetails", "4380c140-2885-4704-ae36-3890998f2b46"},
        };

        private Guid CountrySelection { get; set; } = Guid.Empty;
        private Guid CountySelection { get; set; } = Guid.Empty;

        

        /// <summary>
        /// Populates the parent DataObject with the returned values from Ideal Postcode Finder. Can
        /// handle type "Address" and "Assets"
        /// </summary>
        /// <param name="EntityGroupSection">
        ///     Used when there are multiple sections for a record where an anddress can be filled.
        ///     E.g. Enquiris -> Has "Agent" and "Client" -> We define which one it should fill the details in for!
        /// </param>
        /// <returns></returns>
        private async Task PopulateDataObject()
        {
            var entityType = DataObject.EntityTypeGuid;

            //We will save this to the database using an invisible field, which we have 4 of (Agent, client, finance, and asset)
            var assetJSONDetails = "";

            //[ADDRESSES]
            if (entityType == EntityTypesWithAddresses["Addresses"])
            {
                foreach (var eP in DataObject.DataProperties)
                {
                    if (eP.EntityPropertyGuid == AddressRelatedEntityProperties["Number"])
                    {
                        //Set the building number if present.
                        if (ResolvedAddress.Number != "")
                        {
                            StringValue Number = new StringValue { Value = ResolvedAddress.Number ?? "" };
                            eP.Value = Any.Pack(Number);
                        }
                        else
                        {
                            //Set it to "nothing" otherwise.
                            StringValue Number = new StringValue { Value = "" };
                            eP.Value = Any.Pack(Number);
                        }
                    }
                    else if (eP.EntityPropertyGuid == AddressRelatedEntityProperties["AddressLine1"])
                    {
                        //Check if the number is part of address line 1 - if so,remove it so it is duplicated.
                        if (ResolvedAddress.Number != "")
                        {
                            if (ResolvedAddress.Line1.Contains(ResolvedAddress.Number))
                                ResolvedAddress.Line1 = ResolvedAddress.Line1.Replace(ResolvedAddress.Number, "");
                        }

                        var val = new StringValue { Value = ResolvedAddress.Line1 ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == AddressRelatedEntityProperties["AddressLine2"])
                    {
                        //Do the same check for line 2 in case the number is contained in here.
                        if (ResolvedAddress.Number != "")
                        {
                            if (ResolvedAddress.Line2.Contains(ResolvedAddress.Number))
                                ResolvedAddress.Line2 = ResolvedAddress.Line2.Replace(ResolvedAddress.Number, "");
                        }

                        var val = new StringValue { Value = ResolvedAddress.Line2 ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == AddressRelatedEntityProperties["Town"])
                    {
                        var val = new StringValue { Value = ResolvedAddress.Town ?? "" };
                        eP.Value = Any.Pack(val);

                        await editPageRef.HandleInputUpdated(new Components.Shared.Classes.InputUpdatedArgs
                        {
                            NewValue = eP.Value,
                            EntityId = new Guid(eP.EntityPropertyGuid)
                        });
                    }
                    //County
                    else if (eP.EntityPropertyGuid == AddressRelatedEntityProperties["CountyId"])
                    {
                        try
                        {
                            //Check if the county is present.
                            if (CountyComboOptions.ContainsKey(ResolvedAddress.County))
                            {
                                CountySelection = new Guid(CountyComboOptions[ResolvedAddress.County]);

                                var val = new StringValue { Value = CountySelection.ToString() };
                                eP.Value = Any.Pack(val);
                            }
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine(ex.Message);
                        }
                    }
                    else if (eP.EntityPropertyGuid == AddressRelatedEntityProperties["Postcode"])
                    {
                        var val = new StringValue { Value = ResolvedAddress.Postcode ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    //Country
                    else if (eP.EntityPropertyGuid == AddressRelatedEntityProperties["CountryId"])
                    {
                        try
                        {
                            //Check if the county is present.
                            if (CountryComboOptions.ContainsKey(ResolvedAddress.Country))
                            {
                                CountrySelection = new Guid(CountyComboOptions[ResolvedAddress.Country]);

                                var val = new StringValue { Value = CountrySelection.ToString() };
                                eP.Value = Any.Pack(val);
                            }
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine(ex.Message);
                        }
                    }

                    var fieldToPopulate = DataObject.DataProperties.Where(x => x.EntityPropertyGuid == eP.EntityPropertyGuid).FirstOrDefault();

                    if (fieldToPopulate != null)
                    {
                        fieldToPopulate.Value = eP.Value;
                    }
                }

                await DataObjectChanged.InvokeAsync(DataObject);
                StateHasChanged();
            }
            //[ASSETS]
            else if (entityType == EntityTypesWithAddresses["Assets"])
            {
                foreach (var eP in DataObject.DataProperties)
                {
                    if (eP.EntityPropertyGuid == AssetRelatedEntityProperties["Number"])
                    {
                        if (ResolvedAddress.Number != "")
                        {
                            ResolvedAddress.Number = ResolvedAddress.Number.Replace("/", "");
                            ResolvedAddress.Number = ResolvedAddress.Number.Replace("\"", "");

                            //Set the building number if present.
                            StringValue Number = new StringValue { Value = ResolvedAddress.Number ?? "" };
                            eP.Value = Any.Pack(Number);
                        }
                        else
                        {
                            //Set it to "nothing" otherwise.
                            StringValue Number = new StringValue { Value = "" };
                            eP.Value = Any.Pack(Number);
                        }
                    }
                    else if (eP.EntityPropertyGuid == AssetRelatedEntityProperties["AddressLine1"])
                    {
                        //Check if the number is part of address line 1 - if so,remove it so it is duplicated.
                        if (ResolvedAddress.Number != "")
                        {

                            ResolvedAddress.Line1 = ResolvedAddress.Line1.Replace("/", "");
                            ResolvedAddress.Line1 = ResolvedAddress.Line1.Replace("\"", "");

                            if (ResolvedAddress.Line1.Contains(ResolvedAddress.Number))
                                ResolvedAddress.Line1 = ResolvedAddress.Line1.Replace(ResolvedAddress.Number, "");
                        }

                        var val = new StringValue { Value = ResolvedAddress.Line1 ?? "" };
                        eP.Value = Any.Pack(val);

                        //This is to ensure the record picks up on the changes.
                        await editPageRef.HandleInputUpdated(new Components.Shared.Classes.InputUpdatedArgs
                        {
                            NewValue = eP.Value,
                            EntityId = new Guid(eP.EntityPropertyGuid)
                        });
                    }
                    else if (eP.EntityPropertyGuid == AssetRelatedEntityProperties["AddressLine2"])
                    {
                        //Do the same check for line 2 in case the number is contained in here.
                        if (ResolvedAddress.Number != "")
                        {
                            ResolvedAddress.Line2 = ResolvedAddress.Line2.Replace("/", "");
                            ResolvedAddress.Line2 = ResolvedAddress.Line2.Replace("\"", "");

                            if (ResolvedAddress.Line2.Contains(ResolvedAddress.Number))
                                ResolvedAddress.Line2 = ResolvedAddress.Line2.Replace(ResolvedAddress.Number, "");
                        }

                        var val = new StringValue { Value = ResolvedAddress.Line2 ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == AssetRelatedEntityProperties["Town"])
                    {
                        ResolvedAddress.Town = ResolvedAddress.Town.Replace("/", "");
                        ResolvedAddress.Town = ResolvedAddress.Town.Replace("\"", "");

                        var val = new StringValue { Value = ResolvedAddress.Town ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == AssetRelatedEntityProperties["CountyId"])
                    {
                        try
                        {
                            //Check if the county is present.
                            if (CountyComboOptions.ContainsKey(ResolvedAddress.County))
                            {
                                CountySelection = new Guid(CountyComboOptions[ResolvedAddress.County]);

                                var val = new StringValue { Value = CountySelection.ToString() };
                                eP.Value = Any.Pack(val);
                            }
                           
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine(ex.Message);
                        }
                    }
                    else if (eP.EntityPropertyGuid == AssetRelatedEntityProperties["Postcode"])
                    {
                        ResolvedAddress.Postcode = ResolvedAddress.Postcode.Replace("/", "");
                        ResolvedAddress.Postcode = ResolvedAddress.Postcode.Replace("\"", "");

                        var val = new StringValue { Value = ResolvedAddress.Postcode ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == AssetRelatedEntityProperties["CountryId"])
                    {
                        try
                        {
                            //Check if the county is present.
                            if (CountryComboOptions.ContainsKey(ResolvedAddress.Country))
                            {
                                CountrySelection = new Guid(CountryComboOptions[ResolvedAddress.Country]);
                            
                                var val = new StringValue { Value = CountrySelection.ToString() };
                                eP.Value = Any.Pack(val);
                            }
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine(ex.Message);
                        }
                    }
                    else if (ResolvedAddress.Latitude != null && eP.EntityPropertyGuid == AssetRelatedEntityProperties["Latitude"])
                    {
                        var val = new DoubleValue { Value = (double)ResolvedAddress.Latitude };
                        eP.Value = Any.Pack(val);
                    }
                    else if (ResolvedAddress.Longitude != null && eP.EntityPropertyGuid == AssetRelatedEntityProperties["Longitude"])
                    {
                        var val = new DoubleValue { Value = (double)ResolvedAddress.Longitude };
                        eP.Value = Any.Pack(val);
                    }

                    var fieldToPopulate = DataObject.DataProperties.Where(x => x.EntityPropertyGuid == eP.EntityPropertyGuid).FirstOrDefault();

                    if (fieldToPopulate != null)
                    {
                        fieldToPopulate.Value = eP.Value;
                    }
                }
               
            }
            //Handling the Agent section on enquiries.
            else if (entityType == EntityTypesWithAddresses["Enquiries"] && EntityGroupSection == "Agent")
            {
                foreach (var eP in DataObject.DataProperties)
                {
                    if (eP.EntityPropertyGuid == EnquiryAgentRelatedEntityProperties["Number"])
                    {
                        Console.WriteLine("Number");
                        if (ResolvedAddress.Number != "")
                        {
                            ResolvedAddress.Number = ResolvedAddress.Number.Replace("/", "");
                            ResolvedAddress.Number = ResolvedAddress.Number.Replace("\"", "");

                            //Set the building number if present.
                            StringValue Number = new StringValue { Value = ResolvedAddress.Number ?? "" };
                            eP.Value = Any.Pack(Number);
                        }
                        else
                        {
                            //Set it to "nothing" otherwise.
                            StringValue Number = new StringValue { Value = "" };
                            eP.Value = Any.Pack(Number);
                        }
                    }
                    else if (eP.EntityPropertyGuid == EnquiryAgentRelatedEntityProperties["AddressLine1"])
                    {
                        

                        //Check if the number is part of address line 1 - if so,remove it so it is duplicated.
                        if (ResolvedAddress.Number != "")
                        {
                            if (ResolvedAddress.Line1.Contains(ResolvedAddress.Number))
                                ResolvedAddress.Line1 = ResolvedAddress.Line1.Replace(ResolvedAddress.Number, "");
                        }

                        ResolvedAddress.Line1 = ResolvedAddress.Line1.Replace("/", "");
                        ResolvedAddress.Line1 = ResolvedAddress.Line1.Replace("\"", "");

                        var val = new StringValue { Value = ResolvedAddress.Line1 ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == EnquiryAgentRelatedEntityProperties["AddressLine2"])
                    {
                        

                        //Do the same check for line 2 in case the number is contained in here.
                        if (ResolvedAddress.Number != "")
                        {
                            if (ResolvedAddress.Line2.Contains(ResolvedAddress.Number))
                                ResolvedAddress.Line2 = ResolvedAddress.Line2.Replace(ResolvedAddress.Number, "");
                        }

                        ResolvedAddress.Line2 = ResolvedAddress.Line2.Replace("/", "");
                        ResolvedAddress.Line2 = ResolvedAddress.Line2.Replace("\"", "");

                        var val = new StringValue { Value = ResolvedAddress.Line2 ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == EnquiryAgentRelatedEntityProperties["Town"])
                    {
                        ResolvedAddress.Town = ResolvedAddress.Town.Replace("/", "");
                        ResolvedAddress.Town = ResolvedAddress.Town.Replace("\"", "");

                        var val = new StringValue { Value = ResolvedAddress.Town ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == EnquiryAgentRelatedEntityProperties["CountyId"])
                    {
                        try
                        {
                            //Check if the county is present.
                            if (CountyComboOptions.ContainsKey(ResolvedAddress.County))
                            {
                                CountySelection = new Guid(CountyComboOptions[ResolvedAddress.County]);

                                var val = new StringValue { Value = CountySelection.ToString() };
                                eP.Value = Any.Pack(val);
                            }
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine(ex.Message);
                        }
                    }
                    else if (eP.EntityPropertyGuid == EnquiryAgentRelatedEntityProperties["Postcode"])
                    {

                        ResolvedAddress.Postcode = ResolvedAddress.Postcode.Replace("/", "");
                        ResolvedAddress.Postcode = ResolvedAddress.Postcode.Replace("\"", "");

                        var val = new StringValue { Value = ResolvedAddress.Postcode ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == EnquiryAgentRelatedEntityProperties["CountryId"])
                    {
                   
                        try
                        {
                            //Check if the county is present.
                            if (CountryComboOptions.ContainsKey(ResolvedAddress.Country))
                            {
                                CountrySelection = new Guid(CountryComboOptions[ResolvedAddress.Country]);
                                var val = new StringValue { Value = CountrySelection.ToString() };
                                eP.Value = Any.Pack(val);
                            }
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine(ex.Message);
                        }
                    }
                  


                    var fieldToPopulate = DataObject.DataProperties.Where(x => x.EntityPropertyGuid == eP.EntityPropertyGuid).FirstOrDefault();

                    if (fieldToPopulate != null)
                    {
                        fieldToPopulate.Value = eP.Value;
                    }

                }
            }
            //Handling the Client section for enquiries.
            else if (entityType == EntityTypesWithAddresses["Enquiries"] && EntityGroupSection == "Client")
            {
                foreach (var eP in DataObject.DataProperties)
                {
                    if (eP.EntityPropertyGuid == EnquiryClientRelatedEntityProperties["Number"])
                    {
                        Console.WriteLine("Number");
                        if (ResolvedAddress.Number != "")
                        {
                            ResolvedAddress.Number = ResolvedAddress.Number.Replace("/", "");
                            ResolvedAddress.Number = ResolvedAddress.Number.Replace("\"", "");

                            //Set the building number if present.
                            StringValue Number = new StringValue { Value = ResolvedAddress.Number ?? "" };
                            eP.Value = Any.Pack(Number);
                        }
                        else
                        {
                            //Set it to "nothing" otherwise.
                            StringValue Number = new StringValue { Value = "" };
                            eP.Value = Any.Pack(Number);
                        }
                    }
                    else if (eP.EntityPropertyGuid == EnquiryClientRelatedEntityProperties["AddressLine1"])
                    {


                        //Check if the number is part of address line 1 - if so,remove it so it is duplicated.
                        if (ResolvedAddress.Number != "")
                        {
                            if (ResolvedAddress.Line1.Contains(ResolvedAddress.Number))
                                ResolvedAddress.Line1 = ResolvedAddress.Line1.Replace(ResolvedAddress.Number, "");
                        }

                        ResolvedAddress.Line1 = ResolvedAddress.Line1.Replace("/", "");
                        ResolvedAddress.Line1 = ResolvedAddress.Line1.Replace("\"", "");

                        var val = new StringValue { Value = ResolvedAddress.Line1 ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == EnquiryClientRelatedEntityProperties["AddressLine2"])
                    {


                        //Do the same check for line 2 in case the number is contained in here.
                        if (ResolvedAddress.Number != "")
                        {
                            if (ResolvedAddress.Line2.Contains(ResolvedAddress.Number))
                                ResolvedAddress.Line2 = ResolvedAddress.Line2.Replace(ResolvedAddress.Number, "");
                        }

                        ResolvedAddress.Line2 = ResolvedAddress.Line2.Replace("/", "");
                        ResolvedAddress.Line2 = ResolvedAddress.Line2.Replace("\"", "");

                        var val = new StringValue { Value = ResolvedAddress.Line2 ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == EnquiryClientRelatedEntityProperties["Town"])
                    {
                        ResolvedAddress.Town = ResolvedAddress.Town.Replace("/", "");
                        ResolvedAddress.Town = ResolvedAddress.Town.Replace("\"", "");

                        var val = new StringValue { Value = ResolvedAddress.Town ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == EnquiryClientRelatedEntityProperties["CountyId"])
                    {
                        try
                        {
                            //Check if the county is present.
                            if (CountyComboOptions.ContainsKey(ResolvedAddress.County))
                            {
                                CountySelection = new Guid(CountyComboOptions[ResolvedAddress.County]);

                                var val = new StringValue { Value = CountySelection.ToString() };
                                eP.Value = Any.Pack(val);
                            }
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine(ex.Message);
                        }
                    }
                    else if (eP.EntityPropertyGuid == EnquiryClientRelatedEntityProperties["Postcode"])
                    {

                        ResolvedAddress.Postcode = ResolvedAddress.Postcode.Replace("/", "");
                        ResolvedAddress.Postcode = ResolvedAddress.Postcode.Replace("\"", "");

                        var val = new StringValue { Value = ResolvedAddress.Postcode ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == EnquiryClientRelatedEntityProperties["CountryId"])
                    {

                        try
                        {
                            //Check if the county is present.
                            if (CountryComboOptions.ContainsKey(ResolvedAddress.Country))
                            {
                                CountrySelection = new Guid(CountryComboOptions[ResolvedAddress.Country]);
                                var val = new StringValue { Value = CountrySelection.ToString() };
                                eP.Value = Any.Pack(val);
                            }
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine(ex.Message);
                        }
                    }
                   

                    var fieldToPopulate = DataObject.DataProperties.Where(x => x.EntityPropertyGuid == eP.EntityPropertyGuid).FirstOrDefault();

                    if(fieldToPopulate != null)
                    {
                        fieldToPopulate.Value = eP.Value;
                    }
                }
            }
            //Handling the Asset section for enquiries.
            else if (entityType == EntityTypesWithAddresses["Enquiries"] && EntityGroupSection == "Asset")
            {
                foreach (var eP in DataObject.DataProperties)
                {
                    Console.WriteLine(eP.EntityPropertyGuid.ToString());
                    if (eP.EntityPropertyGuid == EnquiryAssetRelatedEntityProperties["Number"])
                    {
                        Console.WriteLine("Number");
                        if (ResolvedAddress.Number != "")
                        {
                            ResolvedAddress.Number = ResolvedAddress.Number.Replace("/", "");
                            ResolvedAddress.Number = ResolvedAddress.Number.Replace("\"", "");

                            //Set the building number if present.
                            StringValue Number = new StringValue { Value = ResolvedAddress.Number ?? "" };
                            eP.Value = Any.Pack(Number);
                        }
                        else
                        {
                            //Set it to "nothing" otherwise.
                            StringValue Number = new StringValue { Value = "" };
                            eP.Value = Any.Pack(Number);
                        }
                    }
                    else if (eP.EntityPropertyGuid == EnquiryAssetRelatedEntityProperties["AddressLine1"])
                    {


                        //Check if the number is part of address line 1 - if so,remove it so it is duplicated.
                        if (ResolvedAddress.Number != "")
                        {
                            if (ResolvedAddress.Line1.Contains(ResolvedAddress.Number))
                                ResolvedAddress.Line1 = ResolvedAddress.Line1.Replace(ResolvedAddress.Number, "");
                        }

                        ResolvedAddress.Line1 = ResolvedAddress.Line1.Replace("/", "");
                        ResolvedAddress.Line1 = ResolvedAddress.Line1.Replace("\"", "");

                        var val = new StringValue { Value = ResolvedAddress.Line1 ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == EnquiryAssetRelatedEntityProperties["AddressLine2"])
                    {


                        //Do the same check for line 2 in case the number is contained in here.
                        if (ResolvedAddress.Number != "")
                        {
                            if (ResolvedAddress.Line2.Contains(ResolvedAddress.Number))
                                ResolvedAddress.Line2 = ResolvedAddress.Line2.Replace(ResolvedAddress.Number, "");
                        }

                        ResolvedAddress.Line2 = ResolvedAddress.Line2.Replace("/", "");
                        ResolvedAddress.Line2 = ResolvedAddress.Line2.Replace("\"", "");

                        var val = new StringValue { Value = ResolvedAddress.Line2 ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == EnquiryAssetRelatedEntityProperties["Town"])
                    {
                        ResolvedAddress.Town = ResolvedAddress.Town.Replace("/", "");
                        ResolvedAddress.Town = ResolvedAddress.Town.Replace("\"", "");

                        var val = new StringValue { Value = ResolvedAddress.Town ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == EnquiryAssetRelatedEntityProperties["CountyId"])
                    {
                        try
                        {
                            //Check if the county is present.
                            if (CountyComboOptions.ContainsKey(ResolvedAddress.County))
                            {
                                CountySelection = new Guid(CountyComboOptions[ResolvedAddress.County]);

                                var val = new StringValue { Value = CountySelection.ToString() };
                                eP.Value = Any.Pack(val);
                            }
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine(ex.Message);
                        }
                    }
                    else if (eP.EntityPropertyGuid == EnquiryAssetRelatedEntityProperties["Postcode"])
                    {

                        ResolvedAddress.Postcode = ResolvedAddress.Postcode.Replace("/", "");
                        ResolvedAddress.Postcode = ResolvedAddress.Postcode.Replace("\"", "");

                        var val = new StringValue { Value = ResolvedAddress.Postcode ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == EnquiryAssetRelatedEntityProperties["CountryId"])
                    {

                        try
                        {
                            //Check if the county is present.
                            if (CountryComboOptions.ContainsKey(ResolvedAddress.Country))
                            {
                                CountrySelection = new Guid(CountryComboOptions[ResolvedAddress.Country]);
                                var val = new StringValue { Value = CountrySelection.ToString() };
                                eP.Value = Any.Pack(val);
                            }
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine(ex.Message);
                        }
                    }
                   


                    var fieldToPopulate = DataObject.DataProperties.Where(x => x.EntityPropertyGuid == eP.EntityPropertyGuid).FirstOrDefault();

                    if (fieldToPopulate != null)
                    {
                        fieldToPopulate.Value = eP.Value;
                    }

                }

                //Last, combine uprn, latitude, and longitude
                assetJSONDetails = ResolvedAddress.Uprn + "|" + ResolvedAddress.Latitude + "|" + ResolvedAddress.Longitude + "|";
                var AssetJSONDetailsField = DataObject.DataProperties.Where(x => x.EntityPropertyGuid == EnquiryAssetRelatedEntityProperties["AssetJSONDetails"]).FirstOrDefault();

                if (AssetJSONDetailsField != null)
                {
                    var val = new StringValue { Value = assetJSONDetails };
                    AssetJSONDetailsField.Value = Any.Pack(val);
                }
            }
            //Handling the Finance section for enquiries.
            else if (entityType == EntityTypesWithAddresses["Enquiries"] && EntityGroupSection == "Finance")
            {
                foreach (var eP in DataObject.DataProperties)
                {
                    if (eP.EntityPropertyGuid == EnquiryFinanceRelatedEntityProperties["Number"])
                    {
                        Console.WriteLine("Number");
                        if (ResolvedAddress.Number != "")
                        {
                            ResolvedAddress.Number = ResolvedAddress.Number.Replace("/", "");
                            ResolvedAddress.Number = ResolvedAddress.Number.Replace("\"", "");

                            //Set the building number if present.
                            StringValue Number = new StringValue { Value = ResolvedAddress.Number ?? "" };
                            eP.Value = Any.Pack(Number);
                        }
                        else
                        {
                            //Set it to "nothing" otherwise.
                            StringValue Number = new StringValue { Value = "" };
                            eP.Value = Any.Pack(Number);
                        }
                    }
                    else if (eP.EntityPropertyGuid == EnquiryFinanceRelatedEntityProperties["AddressLine1"])
                    {

                        //Check if the number is part of address line 1 - if so,remove it so it is duplicated.
                        if (ResolvedAddress.Number != "")
                        {
                            if (ResolvedAddress.Line1.Contains(ResolvedAddress.Number))
                                ResolvedAddress.Line1 = ResolvedAddress.Line1.Replace(ResolvedAddress.Number, "");
                        }

                        ResolvedAddress.Line1 = ResolvedAddress.Line1.Replace("/", "");
                        ResolvedAddress.Line1 = ResolvedAddress.Line1.Replace("\"", "");

                        var val = new StringValue { Value = ResolvedAddress.Line1 ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == EnquiryFinanceRelatedEntityProperties["AddressLine2"])
                    {


                        //Do the same check for line 2 in case the number is contained in here.
                        if (ResolvedAddress.Number != "")
                        {
                            if (ResolvedAddress.Line2.Contains(ResolvedAddress.Number))
                                ResolvedAddress.Line2 = ResolvedAddress.Line2.Replace(ResolvedAddress.Number, "");
                        }

                        ResolvedAddress.Line2 = ResolvedAddress.Line2.Replace("/", "");
                        ResolvedAddress.Line2 = ResolvedAddress.Line2.Replace("\"", "");

                        var val = new StringValue { Value = ResolvedAddress.Line2 ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == EnquiryFinanceRelatedEntityProperties["Town"])
                    {
                        ResolvedAddress.Town = ResolvedAddress.Town.Replace("/", "");
                        ResolvedAddress.Town = ResolvedAddress.Town.Replace("\"", "");

                        var val = new StringValue { Value = ResolvedAddress.Town ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == EnquiryFinanceRelatedEntityProperties["CountyId"])
                    {
                        try
                        {
                            //Check if the county is present.
                            if (CountyComboOptions.ContainsKey(ResolvedAddress.County))
                            {
                                CountySelection = new Guid(CountyComboOptions[ResolvedAddress.County]);

                                var val = new StringValue { Value = CountySelection.ToString() };
                                eP.Value = Any.Pack(val);
                            }
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine(ex.Message);
                        }
                    }
                    else if (eP.EntityPropertyGuid == EnquiryFinanceRelatedEntityProperties["Postcode"])
                    {

                        ResolvedAddress.Postcode = ResolvedAddress.Postcode.Replace("/", "");
                        ResolvedAddress.Postcode = ResolvedAddress.Postcode.Replace("\"", "");

                        var val = new StringValue { Value = ResolvedAddress.Postcode ?? "" };
                        eP.Value = Any.Pack(val);
                    }
                    else if (eP.EntityPropertyGuid == EnquiryFinanceRelatedEntityProperties["CountryId"])
                    {

                        try
                        {
                            //Check if the county is present.
                            if (CountryComboOptions.ContainsKey(ResolvedAddress.Country))
                            {
                                CountrySelection = new Guid(CountryComboOptions[ResolvedAddress.Country]);
                                var val = new StringValue { Value = CountrySelection.ToString() };
                                eP.Value = Any.Pack(val);
                            }
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine(ex.Message);
                        }
                    }
                   


                    var fieldToPopulate = DataObject.DataProperties.Where(x => x.EntityPropertyGuid == eP.EntityPropertyGuid).FirstOrDefault();

                    if (fieldToPopulate != null)
                    {
                        fieldToPopulate.Value = eP.Value;
                    }
                }
            }

            Console.WriteLine("Assigned data to address related fields!");

            await DataObjectChanged.InvokeAsync(DataObject);
            StateHasChanged();
        }

        /// <summary>
        /// Creates an account which will be marked as local authority.
        /// </summary>
        /// <returns> </returns>
        private async Task UpsertLocalAuthority()
        {
            // DataObject dataObjectForAccount = _formHelper.ReadDataObjectAsync(new
            // Guid().ToString(), )
        }
    }
}