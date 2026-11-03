using System.Collections.Generic;
using Concursus.API.Core;
using Concursus.PWA.Pages;
using Google.Protobuf.WellKnownTypes;
using Xunit;
using Assert = Xunit.Assert;

namespace Concursus.PWA.Tests;

/// <summary>
/// Covers the Add Absence modal fixes made under CYB-538:
/// - ValidateAbsence: end date must not be before the start date, and an Event Name
///   (AbsenceType) must be selected. Future end dates are explicitly allowed - an earlier,
///   overly-restrictive "end date cannot be in the future" rule was deliberately reverted.
/// - ApplyProgrammaticFields: TeamGroupId is always written as -1 (it is FK'd to
///   SCore.Groups, an unrelated ID space to the department/OrganisationalUnits id that used
///   to be written there and violated FK_NonActivityEvents_Groups), and MemberIdentityId is
///   written from the signed-in team member id.
/// </summary>
public sealed class ScheduleTeamAbsenceValidationTests
{
    private const string StartTimeEntityPropertyGuid = "f7f70fe8-ccb0-470b-b22c-564bbeb8feff";
    private const string EndTimeEntityPropertyGuid = "15aa2b43-a942-4405-a0ce-64f375aa3565";
    private const string NonActivityTypeEntityPropertyGuid = "9dab1bbf-3324-4e71-9b65-43c65541750d";
    private const string TeamGroupIdEntityPropertyGuid = "b138a1b2-4a0e-4aa4-8767-9c0c7ad5bf3e";
    private const string MemberIdentityIdEntityPropertyGuid = "3f36e529-2e57-46a8-b36e-cf7512ecc683";

    private const string ValidEventTypeGuid = "3fa85f64-5717-4562-b3fc-2c963f66afa6";

    private static DataProperty TimestampProperty(string entityPropertyGuid, DateTime value) =>
        new()
        {
            EntityPropertyGuid = entityPropertyGuid,
            Value = Any.Pack(Timestamp.FromDateTime(DateTime.SpecifyKind(value, DateTimeKind.Utc)))
        };

    private static DataProperty StringProperty(string entityPropertyGuid, string value) =>
        new()
        {
            EntityPropertyGuid = entityPropertyGuid,
            Value = Any.Pack(new StringValue { Value = value })
        };

    private static DataProperty Int32Property(string entityPropertyGuid, int value) =>
        new()
        {
            EntityPropertyGuid = entityPropertyGuid,
            Value = Any.Pack(new Int32Value { Value = value })
        };

    private static List<DataProperty> ValidAbsence(DateTime start, DateTime end) => new()
    {
        TimestampProperty(StartTimeEntityPropertyGuid, start),
        TimestampProperty(EndTimeEntityPropertyGuid, end),
        StringProperty(NonActivityTypeEntityPropertyGuid, ValidEventTypeGuid)
    };

    [Fact]
    public void ValidateAbsence_ReturnsNull_ForValidPastDatedAbsenceWithEventTypeSelected()
    {
        var properties = ValidAbsence(new DateTime(2026, 9, 1), new DateTime(2026, 9, 2));

        var result = ScheduleTeamAbsence.ValidateAbsence(properties);

        Assert.Null(result);
    }

    [Fact]
    public void ValidateAbsence_ReturnsNull_ForFutureDatedAbsence()
    {
        // Regression guard: an earlier "end date cannot be in the future" rule was added then
        // reverted as incorrect for a forward-looking holiday/absence scheduler - future dates
        // must remain valid.
        var farFuture = DateTime.UtcNow.AddYears(1);
        var properties = ValidAbsence(farFuture, farFuture.AddDays(1));

        var result = ScheduleTeamAbsence.ValidateAbsence(properties);

        Assert.Null(result);
    }

    [Fact]
    public void ValidateAbsence_ReturnsNull_WhenStartAndEndAreOnTheSameInstant()
    {
        var same = new DateTime(2026, 9, 2, 7, 30, 0);
        var properties = ValidAbsence(same, same);

        var result = ScheduleTeamAbsence.ValidateAbsence(properties);

        Assert.Null(result);
    }

    [Fact]
    public void ValidateAbsence_ReturnsError_WhenEndDateIsBeforeStartDate()
    {
        var properties = ValidAbsence(new DateTime(2026, 9, 5), new DateTime(2026, 9, 1));

        var result = ScheduleTeamAbsence.ValidateAbsence(properties);

        Assert.Equal("End date cannot be before the start date.", result);
    }

    [Fact]
    public void ValidateAbsence_SkipsDateOrderCheck_WhenOnlyOneOfStartOrEndIsPresent()
    {
        var properties = new List<DataProperty>
        {
            TimestampProperty(StartTimeEntityPropertyGuid, new DateTime(2026, 9, 5)),
            StringProperty(NonActivityTypeEntityPropertyGuid, ValidEventTypeGuid)
        };

        var result = ScheduleTeamAbsence.ValidateAbsence(properties);

        Assert.Null(result);
    }

    [Fact]
    public void ValidateAbsence_ReturnsError_WhenEventTypePropertyIsMissing()
    {
        var properties = new List<DataProperty>
        {
            TimestampProperty(StartTimeEntityPropertyGuid, new DateTime(2026, 9, 1)),
            TimestampProperty(EndTimeEntityPropertyGuid, new DateTime(2026, 9, 2))
        };

        var result = ScheduleTeamAbsence.ValidateAbsence(properties);

        Assert.Equal("Event Name must be selected.", result);
    }

    [Fact]
    public void ValidateAbsence_ReturnsError_WhenEventTypeValueIsEmptyGuid()
    {
        var properties = new List<DataProperty>
        {
            TimestampProperty(StartTimeEntityPropertyGuid, new DateTime(2026, 9, 1)),
            TimestampProperty(EndTimeEntityPropertyGuid, new DateTime(2026, 9, 2)),
            StringProperty(NonActivityTypeEntityPropertyGuid, Guid.Empty.ToString())
        };

        var result = ScheduleTeamAbsence.ValidateAbsence(properties);

        Assert.Equal("Event Name must be selected.", result);
    }

    [Fact]
    public void ValidateAbsence_ReturnsError_WhenEventTypeValueIsNotAString()
    {
        // Guards against the lookup value being unpacked as the wrong protobuf type - the
        // event type dropdown stores a StringValue-wrapped guid (see ShoreInput's
        // GuidValueBinding), not an Int32Value.
        var properties = new List<DataProperty>
        {
            TimestampProperty(StartTimeEntityPropertyGuid, new DateTime(2026, 9, 1)),
            TimestampProperty(EndTimeEntityPropertyGuid, new DateTime(2026, 9, 2)),
            Int32Property(NonActivityTypeEntityPropertyGuid, 2)
        };

        var result = ScheduleTeamAbsence.ValidateAbsence(properties);

        Assert.Equal("Event Name must be selected.", result);
    }

    [Fact]
    public void ValidateAbsence_ChecksDateOrderBeforeEventType()
    {
        // Both rules are violated - the date-order message should win, matching the order the
        // checks run in ValidateAbsence.
        var properties = new List<DataProperty>
        {
            TimestampProperty(StartTimeEntityPropertyGuid, new DateTime(2026, 9, 5)),
            TimestampProperty(EndTimeEntityPropertyGuid, new DateTime(2026, 9, 1))
        };

        var result = ScheduleTeamAbsence.ValidateAbsence(properties);

        Assert.Equal("End date cannot be before the start date.", result);
    }

    [Fact]
    public void ApplyProgrammaticFields_WritesNegativeOneToTeamGroupId()
    {
        // TeamGroupId is FK'd to SCore.Groups, a different ID space to the department id this
        // used to (incorrectly) carry - -1 is the column's own DEFAULT/sentinel value.
        var properties = new List<DataProperty>
        {
            Int32Property(TeamGroupIdEntityPropertyGuid, 42),
            Int32Property(MemberIdentityIdEntityPropertyGuid, -1)
        };

        ScheduleTeamAbsence.ApplyProgrammaticFields(properties, memberIdentityId: 1556);

        var teamGroupIdProp = properties.Single(p => p.EntityPropertyGuid == TeamGroupIdEntityPropertyGuid);
        Assert.True(teamGroupIdProp.Value.Is(Int32Value.Descriptor));
        Assert.Equal(-1, teamGroupIdProp.Value.Unpack<Int32Value>().Value);
    }

    [Fact]
    public void ApplyProgrammaticFields_WritesGivenMemberIdentityId()
    {
        var properties = new List<DataProperty>
        {
            Int32Property(TeamGroupIdEntityPropertyGuid, -1),
            Int32Property(MemberIdentityIdEntityPropertyGuid, -1)
        };

        ScheduleTeamAbsence.ApplyProgrammaticFields(properties, memberIdentityId: 1556);

        var memberIdProp = properties.Single(p => p.EntityPropertyGuid == MemberIdentityIdEntityPropertyGuid);
        Assert.True(memberIdProp.Value.Is(Int32Value.Descriptor));
        Assert.Equal(1556, memberIdProp.Value.Unpack<Int32Value>().Value);
    }

    [Fact]
    public void ApplyProgrammaticFields_DoesNotTouchUnrelatedProperties()
    {
        var eventType = StringProperty(NonActivityTypeEntityPropertyGuid, ValidEventTypeGuid);
        var properties = new List<DataProperty>
        {
            eventType,
            Int32Property(TeamGroupIdEntityPropertyGuid, 42),
            Int32Property(MemberIdentityIdEntityPropertyGuid, -1)
        };

        ScheduleTeamAbsence.ApplyProgrammaticFields(properties, memberIdentityId: 1556);

        Assert.True(eventType.Value.Is(StringValue.Descriptor));
        Assert.Equal(ValidEventTypeGuid, eventType.Value.Unpack<StringValue>().Value);
    }

    [Fact]
    public void ApplyProgrammaticFields_DoesNotThrow_WhenExpectedPropertiesAreAbsent()
    {
        var properties = new List<DataProperty>
        {
            StringProperty(NonActivityTypeEntityPropertyGuid, ValidEventTypeGuid)
        };

        var exception = Record.Exception(() =>
            ScheduleTeamAbsence.ApplyProgrammaticFields(properties, memberIdentityId: 1556));

        Assert.Null(exception);
    }
}
