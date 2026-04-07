using Concursus.API.Core;
using Microsoft.AspNetCore.Components;

namespace Concursus.Components.Shared.Controls;

public partial class DocumentsButton
{
    [Parameter] public DataObject? dataObject { get; set; }
}