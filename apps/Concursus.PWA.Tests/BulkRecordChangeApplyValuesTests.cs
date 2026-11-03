using Concursus.API.Core;
using Concursus.PWA.Pages;
using Google.Protobuf.WellKnownTypes;
using Xunit;
using Assert = Xunit.Assert;

namespace Concursus.PWA.Tests
{
    /// <summary>
    /// CYB-579: a bulk update must not count a record as updated when none of the chosen fields
    /// could be changed on it (e.g. completed activities, whose fields are read-only). The count
    /// returned by ApplyBulkValues decides whether the record is saved or reported as skipped.
    /// </summary>
    public class BulkRecordChangeApplyValuesTests
    {
        private const string AssigneeGuid = "assignee-property-guid";
        private const string StatusGuid = "status-property-guid";

        [Fact]
        public void ApplyBulkValues_ReturnsZeroAndLeavesValues_WhenEveryTargetFieldIsReadOnly()
        {
            var dataObject = new DataObject
            {
                DataProperties = { Property(AssigneeGuid, "Original Assignee", isReadOnly: true) }
            };

            var applied = BulkRecordChange.ApplyBulkValues(dataObject, Values((AssigneeGuid, "New Assignee")));

            Assert.Equal(0, applied);
            Assert.Equal("Original Assignee", dataObject.DataProperties[0].Value.Unpack<StringValue>().Value);
        }

        [Fact]
        public void ApplyBulkValues_AppliesOnlyTheWritableFields()
        {
            var dataObject = new DataObject
            {
                DataProperties =
                {
                    Property(AssigneeGuid, "Original Assignee", isReadOnly: false),
                    Property(StatusGuid, "Complete", isReadOnly: true)
                }
            };

            var applied = BulkRecordChange.ApplyBulkValues(
                dataObject,
                Values((AssigneeGuid, "New Assignee"), (StatusGuid, "Tentative")));

            Assert.Equal(1, applied);
            Assert.Equal("New Assignee", dataObject.DataProperties[0].Value.Unpack<StringValue>().Value);
            Assert.Equal("Complete", dataObject.DataProperties[1].Value.Unpack<StringValue>().Value);
        }

        [Fact]
        public void ApplyBulkValues_IgnoresFieldsTheRecordDoesNotHave()
        {
            var dataObject = new DataObject
            {
                DataProperties = { Property(StatusGuid, "Tentative", isReadOnly: false) }
            };

            var applied = BulkRecordChange.ApplyBulkValues(dataObject, Values((AssigneeGuid, "New Assignee")));

            Assert.Equal(0, applied);
        }

        private static DataProperty Property(string entityPropertyGuid, string value, bool isReadOnly) =>
            new()
            {
                EntityPropertyGuid = entityPropertyGuid,
                Value = Any.Pack(new StringValue { Value = value }),
                IsReadOnly = isReadOnly
            };

        private static Dictionary<string, Any> Values(params (string Guid, string Value)[] values) =>
            values.ToDictionary(v => v.Guid, v => Any.Pack(new StringValue { Value = v.Value }));
    }
}
