using System;
using System.Collections.Generic;
using Google.Protobuf.WellKnownTypes;

/*
Example usage:

var transient = TransientContextHelper.Create(
    ("BypassReadOnlyForAutomationReenable", true),
    ("IsAutomationMode", true),
    ("ForceValidationOverride", false),
    ("ModeName", "Automation"),
    ("RetryCount", 3),
    ("InvoiceScheduleGuid", Guid.Parse("89F18AE4-72C9-4E1B-AB97-D3D20952B544")),
    ("EffectiveDate", DateTime.UtcNow),
    ("Percentage", 12.5m),
    ("NullableValue", null)
);

Pass to a page/component:

<EditPage TransientVirtualProperties="@transient" />

Ensure Parameters are defined in the receiving component/page:

[Parameter] public Dictionary<string, Any> TransientVirtualProperties { get; set; } = new();


*/
public static class TransientContextHelper
{
    public static Dictionary<string, Any> Create(params (string key, object? value)[] items)
    {
        var dict = new Dictionary<string, Any>(StringComparer.OrdinalIgnoreCase);

        foreach (var item in items)
        {
            ValidateKey(item.key);
            dict[item.key] = PackValue(item.key, item.value);
        }

        return dict;
    }

    public static void Add(IDictionary<string, Any> target, string key, object? value)
    {
        if (target == null)
        {
            throw new ArgumentNullException(nameof(target));
        }

        ValidateKey(key);
        target[key] = PackValue(key, value);
    }

    public static Dictionary<string, Any> Merge(
        IDictionary<string, Any>? first,
        IDictionary<string, Any>? second)
    {
        var result = new Dictionary<string, Any>(StringComparer.OrdinalIgnoreCase);

        if (first != null)
        {
            foreach (var kvp in first)
            {
                result[kvp.Key] = kvp.Value;
            }
        }

        if (second != null)
        {
            foreach (var kvp in second)
            {
                result[kvp.Key] = kvp.Value;
            }
        }

        return result;
    }

    private static Any PackValue(string key, object? value)
    {
        if (value == null)
        {
            return Any.Pack(new Empty());
        }

        if (value is Any packedAny)
        {
            return packedAny;
        }

        if (value is bool boolValue)
        {
            return Any.Pack(new BoolValue { Value = boolValue });
        }

        if (value is string stringValue)
        {
            return Any.Pack(new StringValue { Value = stringValue });
        }

        if (value is int intValue)
        {
            return Any.Pack(new Int32Value { Value = intValue });
        }

        if (value is short shortValue)
        {
            return Any.Pack(new Int32Value { Value = shortValue });
        }

        if (value is byte byteValue)
        {
            return Any.Pack(new Int32Value { Value = byteValue });
        }

        if (value is long longValue)
        {
            return Any.Pack(new Int64Value { Value = longValue });
        }

        if (value is double doubleValue)
        {
            return Any.Pack(new DoubleValue { Value = doubleValue });
        }

        if (value is float floatValue)
        {
            return Any.Pack(new DoubleValue { Value = floatValue });
        }

        if (value is decimal decimalValue)
        {
            return Any.Pack(new DoubleValue { Value = Convert.ToDouble(decimalValue) });
        }

        if (value is Guid guidValue)
        {
            return Any.Pack(new StringValue { Value = guidValue.ToString() });
        }

        if (value is DateTime dateTimeValue)
        {
            return Any.Pack(ToTimestamp(dateTimeValue));
        }

        if (value is DateTimeOffset dateTimeOffsetValue)
        {
            return Any.Pack(ToTimestamp(dateTimeOffsetValue.UtcDateTime));
        }

#if NET6_0_OR_GREATER
        if (value is DateOnly dateOnlyValue)
        {
            return Any.Pack(
                ToTimestamp(dateOnlyValue.ToDateTime(TimeOnly.MinValue))
            );
        }
#endif

        if (value is System.Enum enumValue)
        {
            return Any.Pack(new StringValue { Value = enumValue.ToString() });
        }

        throw new InvalidOperationException(
            $"Unsupported transient property type for key '{key}'. Type: '{value.GetType().FullName}'.");
    }

    private static Timestamp ToTimestamp(DateTime dateTime)
    {
        DateTime utcDateTime;

        switch (dateTime.Kind)
        {
            case DateTimeKind.Utc:
                utcDateTime = dateTime;
                break;

            case DateTimeKind.Local:
                utcDateTime = dateTime.ToUniversalTime();
                break;

            case DateTimeKind.Unspecified:
            default:
                utcDateTime = DateTime.SpecifyKind(dateTime, DateTimeKind.Utc);
                break;
        }

        return Timestamp.FromDateTime(utcDateTime);
    }

    private static void ValidateKey(string key)
    {
        if (string.IsNullOrWhiteSpace(key))
        {
            throw new ArgumentException("Transient property key cannot be null or whitespace.", nameof(key));
        }
    }
}