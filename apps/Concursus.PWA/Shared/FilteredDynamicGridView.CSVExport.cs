using Concursus.PWA.Classes;
using Microsoft.JSInterop;
using Concursus.API.Core;

namespace Concursus.PWA.Shared;

public partial class FilteredDynamicGridView
{
    private bool DisableExportBtn = false;

    private string ExportButtonTxt => 
        !DisableExportBtn 
            ? "Export Excel" 
            : "Please, wait, this might take a minute!";
     

    private string ExportButtonIcon =>
      !DisableExportBtn
          ? "bi bi-file-earmark-excel"
          : "bi bi-arrow-repeat export-spinner";


    /// <summary>
    /// Export the grid view in Excel format. 
    /// </summary>
    /// <returns></returns>
    private async Task ExportToExcelAsync()
    {
        try
        {
            if (ViewDefinition is null)
            {
                return;
            }

            var parentGuid = PWAFunctions.ParseAndReturnEmptyGuidIfInvalid(ParentGuid).ToString();
            if (parentGuid == Guid.Empty.ToString() && !FullGrid)
            {
                return;
            }

            NativeIsLoading = true;
            DisableExportBtn = true;

            var columns = VisibleGridColumns
                .Select(column => new
                {
                    key = column.Name,
                    title = string.IsNullOrWhiteSpace(column.Title) ? column.Name : column.Title
                })
                .ToList();

            var allRows = new List<Dictionary<string, string>>();
            int exportPageSize = 10000; //get 1000 pages -> Ensures all the records are exported.
            var exportPage = 1;

            while (true)
            {
                var request = new GridDataListRequest
                {
                    GridCode = GridCode,
                    GridViewCode = ViewDefinition.Code,
                    Page = exportPage,
                    PageSize = exportPageSize,
                    ParentGuid = parentGuid
                };

                if (CompositeFilter is not null)
                {
                    request.Filters.Add(CompositeFilter);
                }

                if (!string.IsNullOrWhiteSpace(NativeSortColumn))
                {
                    request.Sort.Add(new DataSort
                    {
                        ColumnName = NativeSortColumn,
                        Direction = NativeSortDescending ? "Descending" : "Ascending"
                    });
                }

                var reply = await coreClient.GridDataListAsync(request);

                foreach (var r in reply.DataTable)
                {
                    var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                    foreach (var c in r.Columns)
                    {
                        values[c.Name] = FormatGridColumnValue(c.Name, c.Value)?.ToString() ?? string.Empty;
                    }

                    allRows.Add(values);
                }

                if (reply.DataTable.Count < exportPageSize)
                {
                    break;
                }

                exportPage++;
            }

            var rows = allRows
                .Select(values => new { values })
                .ToList();

            var fileName = $"{SanitiseExcelFileName(ViewDefinition.Name)}_{DateTime.Now:yyyyMMdd_HHmmss}.xls";

            await JsRuntime.InvokeVoidAsync(
                "cymBuildV2.exportTreeGridToExcel",
                fileName,
                ViewDefinition.Name ?? "CymBuild Export",
                columns,
                rows);


            DisableExportBtn = false;
        }
        catch (Exception ex)
        {
            ex.Data.Add("MessageType", MessageDisplay.ShowMessageType.Error);
            ex.Data.Add("AdditionalInfo", "An error occurred while exporting the grid to Excel.");
            ex.Data.Add("PageMethod", "FilteredDynamicGridView/ExportToExcelAsync()");
            await OnError(ex);
        }
        finally
        {
            NativeIsLoading = false;
        }
    }

    private static string SanitiseExcelFileName(string? value)
    {
        var name = string.IsNullOrWhiteSpace(value) ? "CymBuild_Export" : value;

        foreach (var invalidChar in Path.GetInvalidFileNameChars())
        {
            name = name.Replace(invalidChar, '_');
        }

        return name.Replace(' ', '_');
    }
}
