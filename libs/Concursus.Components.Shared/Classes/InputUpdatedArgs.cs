using Concursus.API.Core;
using Google.Protobuf.WellKnownTypes;

namespace Concursus.Components.Shared.Classes;

public class InputUpdatedArgs
{
    #region Public Properties

    public List<EntityPropertyDependant> Dependents { get; set; } = new();
    public Guid EntityId { get; set; } = Guid.Empty;
    public Any? NewValue { get; set; }

    #endregion Public Properties
}