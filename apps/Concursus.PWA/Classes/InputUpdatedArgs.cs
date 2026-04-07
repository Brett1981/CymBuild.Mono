using Google.Protobuf.WellKnownTypes;
using Concursus.API.Core;

namespace Concursus.PWA.Classes
{
    public class InputUpdatedArgs
    {
        public Any? NewValue { get; set; }

        public List<EntityPropertyDependant> Dependents { get; set; } = new List<EntityPropertyDependant>();
    }
}
