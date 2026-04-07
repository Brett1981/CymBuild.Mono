using Concursus.API.Core;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Concursus.Components.Shared.Classes
{
    public static class LanguageData
    {
        public static List<LanguageItemModel> GetLanguages()
        {
            return new List<LanguageItemModel>
            {
                new LanguageItemModel { Text = "Spanish", Value = "es_ES" },
                new LanguageItemModel { Text = "French", Value = "fr_FR" },
                new LanguageItemModel { Text = "German", Value = "de_DE" },
                new LanguageItemModel { Text = "Italian", Value = "it_IT" },
                new LanguageItemModel { Text = "Portuguese", Value = "pt_PT" },
                new LanguageItemModel { Text = "Dutch", Value = "nl_NL" },
                new LanguageItemModel { Text = "Russian", Value = "ru_RU" },
                new LanguageItemModel { Text = "Chinese", Value = "zh_CN" },
                new LanguageItemModel { Text = "Japanese", Value = "ja_JP" },
                new LanguageItemModel { Text = "Korean", Value = "ko_KR" },
                new LanguageItemModel { Text = "Arabic", Value = "ar_SA" },
                new LanguageItemModel { Text = "Hindi", Value = "hi_IN" },
                new LanguageItemModel { Text = "Bengali", Value = "bn_BD" },
                new LanguageItemModel { Text = "Punjabi", Value = "pa_IN" },
                new LanguageItemModel { Text = "Javanese", Value = "jv_ID" },
                new LanguageItemModel { Text = "Vietnamese", Value = "vi_VN" },
                new LanguageItemModel { Text = "Urdu", Value = "ur_PK" },
                new LanguageItemModel { Text = "Turkish", Value = "tr_TR" },
                new LanguageItemModel { Text = "Persian", Value = "fa_IR" },
                new LanguageItemModel { Text = "Swahili", Value = "sw_KE" },
                new LanguageItemModel { Text = "Tamil", Value = "ta_IN" },
                new LanguageItemModel { Text = "Telugu", Value = "te_IN" },
                new LanguageItemModel { Text = "Marathi", Value = "mr_IN" },
                new LanguageItemModel { Text = "Gujarati", Value = "gu_IN" },
                new LanguageItemModel { Text = "Polish", Value = "pl_PL" },
                new LanguageItemModel { Text = "Ukrainian", Value = "uk_UA" },
                new LanguageItemModel { Text = "Romanian", Value = "ro_RO" },
                new LanguageItemModel { Text = "Hungarian", Value = "hu_HU" },
                new LanguageItemModel { Text = "Greek", Value = "el_GR" },
                new LanguageItemModel { Text = "Czech", Value = "cs_CZ" },
                new LanguageItemModel { Text = "Swedish", Value = "sv_SE" },
                new LanguageItemModel { Text = "Finnish", Value = "fi_FI" },
                new LanguageItemModel { Text = "Norwegian", Value = "no_NO" },
                new LanguageItemModel { Text = "Danish", Value = "da_DK" },
                new LanguageItemModel { Text = "Thai", Value = "th_TH" },
                new LanguageItemModel { Text = "Malay", Value = "ms_MY" },
                new LanguageItemModel { Text = "Indonesian", Value = "id_ID" },
                new LanguageItemModel { Text = "Filipino", Value = "fil_PH" },
                new LanguageItemModel { Text = "Hebrew", Value = "he_IL" },
                new LanguageItemModel { Text = "Malayalam", Value = "ml_IN" },
                new LanguageItemModel { Text = "Kannada", Value = "kn_IN" },
                new LanguageItemModel { Text = "Burmese", Value = "my_MM" },
                new LanguageItemModel { Text = "Khmer", Value = "km_KH" }
            };
        }

        private static List<LanguageLabelsModel> ConvertToLanguageLabelsModel(GridDataListReply gridDataListReply)
        {
            var languageLabels = new List<LanguageLabelsModel>();

            foreach (var row in gridDataListReply.DataTable.ToList())
            {
                var model = new LanguageLabelsModel();

                foreach (var column in row.Columns)
                {
                    switch (column.Name)
                    {
                        case "ID":
                            model.ID = column.Value;
                            break;

                        case "Guid":
                            model.Guid = column.Value;
                            break;

                        case "Name":
                            model.Name = column.Value;
                            break;
                    }
                }

                languageLabels.Add(model);
            }

            return languageLabels;
        }

        private static List<LanguageLabelTranslationModel> ConvertToLanguageLabelTranslationModel(GridDataListReply gridDataListReply)
        {
            var languageLabelTranslations = new List<LanguageLabelTranslationModel>();

            foreach (var row in gridDataListReply.DataTable.ToList())
            {
                var model = new LanguageLabelTranslationModel();

                foreach (var column in row.Columns)
                {
                    switch (column.Name)
                    {
                        case "Guid":
                            model.Guid = column.Value;
                            break;

                        case "Text":
                            model.Text = column.Value;
                            break;

                        case "TextPlural":
                            model.TextPlural = column.Value;
                            break;

                        case "LanguageLabelID":
                            model.LanguageLabelID = int.Parse(column.Value);
                            break;

                        case "LanguageID":
                            model.LanguageID = int.Parse(column.Value);
                            break;

                        case "HelpText":
                            model.HelpText = column.Value;
                            break;
                    }
                }

                languageLabelTranslations.Add(model);
            }

            return languageLabelTranslations;
        }

        public static async Task<List<LanguageLabelTranslationModel>> GetLanguageLabelTranslationsAsync(Core.CoreClient coreClient, int languageID)
        {
            var languageLabelTranslations = new List<LanguageLabelTranslationModel>();

            int page = 1;
            int pageSize = 50;
            int totalRows = 0;

            do
            {
                var gridDataListRequest = new GridDataListRequest
                {
                    GridCode = "DEV",
                    GridViewCode = "LANGUAGELABELTRANSLATIONS",
                    Page = page,
                    PageSize = pageSize,
                    ParentGuid = "00000000-0000-0000-0000-000000000000"
                };

                var gridDataListReply = await coreClient.GridDataListAsync(gridDataListRequest);
                totalRows = gridDataListReply.TotalRows;

                if (totalRows == 0)
                {
                    break;
                }

                var languageLabels = ConvertToLanguageLabelTranslationModel(gridDataListReply);
                languageLabelTranslations.AddRange(languageLabels);

                // Debugging information
                Console.WriteLine($"Page: {page}, PageSize: {pageSize}, TotalRows: {totalRows}, FetchedRows: {languageLabels.Count}");

                page++;
            } while ((page - 1) * pageSize < totalRows);

            // Final debug information
            Console.WriteLine($"Total Language Labels Fetched: {languageLabelTranslations.Count}");

            return languageLabelTranslations;
        }

        public static async Task<List<LanguageLabelModel>> GetLanguagesSetAsync(Core.CoreClient coreClient)
        {
            var languages = new List<LanguageLabelModel>();

            int page = 1;
            int pageSize = 50;
            int totalRows = 0;

            do
            {
                var gridDataListRequest = new GridDataListRequest
                {
                    GridCode = "DEV",
                    GridViewCode = "LANGUAGES",
                    Page = page,
                    PageSize = pageSize,
                    ParentGuid = "00000000-0000-0000-0000-000000000000"
                };

                var gridDataListReply = await coreClient.GridDataListAsync(gridDataListRequest);
                totalRows = gridDataListReply.TotalRows;

                if (totalRows == 0)
                {
                    break;
                }

                var languageLabels = new List<LanguageLabelModel>();

                foreach (var row in gridDataListReply.DataTable.ToList())
                {
                    var model = new LanguageLabelModel();

                    foreach (var column in row.Columns)
                    {
                        switch (column.Name)
                        {
                            case "ID":
                                model.ID = int.Parse(column.Value);
                                break;

                            case "Guid":
                                model.Guid = column.Value;
                                break;

                            case "Name":
                                model.Name = column.Value;
                                break;

                            case "Locale":
                                model.Locale = column.Value;
                                break;
                        }
                    }

                    languages.Add(model);
                }

                // Debugging information
                Console.WriteLine($"Page: {page}, PageSize: {pageSize}, TotalRows: {totalRows}, FetchedRows: {languageLabels.Count}");

                page++;
            } while ((page - 1) * pageSize < totalRows);

            // Final debug information
            Console.WriteLine($"Total Language Labels Fetched: {languages.Count}");

            return languages;
        }

        public static async Task<List<LanguageLabelsModel>> GetAllLanguageLabelsAsync(Core.CoreClient coreClient)
        {
            var allLanguageLabels = new List<LanguageLabelsModel>();
            int page = 1;
            int pageSize = 50;
            int totalRows = 0;

            do
            {
                var gridDataListRequest = new GridDataListRequest
                {
                    GridCode = "DEV",
                    GridViewCode = "LANGUAGELABELS",
                    Page = page,
                    PageSize = pageSize,
                    ParentGuid = "00000000-0000-0000-0000-000000000000"
                };

                var gridDataListReply = await coreClient.GridDataListAsync(gridDataListRequest);
                totalRows = gridDataListReply.TotalRows;

                if (totalRows == 0)
                {
                    break;
                }

                var languageLabels = ConvertToLanguageLabelsModel(gridDataListReply);
                allLanguageLabels.AddRange(languageLabels);

                // Debugging information
                Console.WriteLine($"Page: {page}, PageSize: {pageSize}, TotalRows: {totalRows}, FetchedRows: {languageLabels.Count}");

                page++;
            } while ((page - 1) * pageSize < totalRows);

            // Final debug information
            Console.WriteLine($"Total Language Labels Fetched: {allLanguageLabels.Count}");

            return allLanguageLabels;
        }
    }

    public class LanguageItemModel
    {
        public string Text { get; set; } = "";
        public string Value { get; set; } = ""; //Locale
    }

    public class LanguageLabelsModel
    {
        public string ID { get; set; } = "-1"; //LanguageLabelID
        public string Guid { get; set; } = "00000000-0000-0000-0000-000000000000";
        public string Name { get; set; } = "";
    }

    public class LanguageLabelTranslationModel
    {
        public string Guid { get; set; } = "00000000-0000-0000-0000-000000000000";
        public string Text { get; set; } = "";
        public string TextPlural { get; set; } = "";
        public int LanguageLabelID { get; set; } = -1;
        public int LanguageID { get; set; } = -1;
        public string HelpText { get; set; } = "";
    }

    public class LanguageLabelModel
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int ID { get; set; }

        public string Guid { get; set; } = "00000000-0000-0000-0000-000000000000";
        public string Name { get; set; } = "";
        public string Locale { get; set; } = "";
    }
}