using Concursus.EF.Types;
using Xunit;

namespace Concursus.EF.Tests;

/// <summary>
/// CYB-462: tvf_QuotesValidate (the Quotes HoBT validation query) locks the visible
/// Quote_ExtendedInfo.DescriptionOfWorks once a quote is Sent. Quote_ExtendedInfo has no
/// validation query of its own. On read, the main HoBT used to validate before the secondary
/// HoBT properties existed, so the lock only appeared after the first edit. DataObjectGet now
/// validates once every HoBT is read and applies the combined results with this overload.
/// </summary>
public sealed class CYB462ReadValidationAcrossHoBTsTests
{
    private static readonly Guid MainHoBT = Guid.NewGuid();
    private static readonly Guid ExtendedHoBT = Guid.NewGuid();
    private static readonly Guid MainDescription = Guid.NewGuid();
    private static readonly Guid ExpiryDate = Guid.NewGuid();
    private static readonly Guid ExtendedDescription = Guid.NewGuid();

    private static EntityType BuildQuoteLikeEntityType()
    {
        var entityType = new EntityType();
        entityType.EntityHoBTs.Add(new EntityHoBT { Guid = MainHoBT, IsMainHoBT = true });
        entityType.EntityHoBTs.Add(new EntityHoBT { Guid = ExtendedHoBT, IsMainHoBT = false });
        entityType.EntityProperties.Add(new EntityProperty { Guid = MainDescription, EntityHoBTGuid = MainHoBT, IsHidden = true });
        entityType.EntityProperties.Add(new EntityProperty { Guid = ExpiryDate, EntityHoBTGuid = MainHoBT });
        entityType.EntityProperties.Add(new EntityProperty { Guid = ExtendedDescription, EntityHoBTGuid = ExtendedHoBT });
        return entityType;
    }

    private static DataObject BuildDataObject()
    {
        var dataObject = new DataObject();
        dataObject.DataProperties.Add(new DataProperty { EntityPropertyGuid = MainDescription });
        dataObject.DataProperties.Add(new DataProperty { EntityPropertyGuid = ExpiryDate });
        dataObject.DataProperties.Add(new DataProperty { EntityPropertyGuid = ExtendedDescription });
        return dataObject;
    }

    private static ValidationResult ReadOnly(Guid target) =>
        new() { TargetGuid = target, TargetType = "P", IsReadOnly = true };

    private static DataProperty Property(DataObject dataObject, Guid guid) =>
        dataObject.DataProperties.Single(p => p.EntityPropertyGuid == guid);

    [Fact]
    public void MainHoBTLockOnSecondaryHoBTProperty_IsKeptWhenAllHoBTsApplyTogether()
    {
        var entityType = BuildQuoteLikeEntityType();
        var dataObject = BuildDataObject();

        // The Sent lockdown rows from the main HoBT validation query.
        var results = new List<ValidationResult> { ReadOnly(ExpiryDate), ReadOnly(ExtendedDescription) };

        Validation.ApplyValidationResults(ref dataObject, true, entityType, results, new[] { MainHoBT, ExtendedHoBT }, false);

        Assert.True(Property(dataObject, ExpiryDate).IsReadOnly);
        Assert.True(Property(dataObject, ExtendedDescription).IsReadOnly);
    }

    [Fact]
    public void ApplyingTheSecondaryHoBTOnItsOwn_ResetsItsProperties_WhichIsWhyReadMustApplyOnce()
    {
        var entityType = BuildQuoteLikeEntityType();
        var dataObject = BuildDataObject();

        Validation.ApplyValidationResults(ref dataObject, true, entityType, new List<ValidationResult> { ReadOnly(ExtendedDescription) }, MainHoBT, false);
        Validation.ApplyValidationResults(ref dataObject, true, entityType, new List<ValidationResult>(), ExtendedHoBT, false);

        Assert.False(Property(dataObject, ExtendedDescription).IsReadOnly);
    }

    [Fact]
    public void CombinedApply_ResetsEveryListedHoBTToMetadataDefaultsBeforeApplying()
    {
        var entityType = BuildQuoteLikeEntityType();
        var dataObject = BuildDataObject();
        Property(dataObject, ExpiryDate).IsReadOnly = true;
        Property(dataObject, ExtendedDescription).IsReadOnly = true;

        Validation.ApplyValidationResults(ref dataObject, true, entityType, new List<ValidationResult>(), new[] { MainHoBT, ExtendedHoBT }, false);

        Assert.False(Property(dataObject, ExpiryDate).IsReadOnly);
        Assert.False(Property(dataObject, ExtendedDescription).IsReadOnly);
        Assert.True(Property(dataObject, MainDescription).IsHidden);
    }

    [Fact]
    public void CombinedApply_ForInformationView_KeepsEveryPropertyReadOnly()
    {
        var entityType = BuildQuoteLikeEntityType();
        var dataObject = BuildDataObject();

        Validation.ApplyValidationResults(ref dataObject, true, entityType, new List<ValidationResult>(), new[] { MainHoBT, ExtendedHoBT }, true);

        Assert.All(dataObject.DataProperties, p => Assert.True(p.IsReadOnly));
    }
}
