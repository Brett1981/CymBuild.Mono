namespace Concursus.Common.Shared.Functions;

public class Compare<T>
{
    #region Private Fields

    private T _default;

    private T _value;

    #endregion Private Fields

    #region Public Constructors

    public Compare(T @default, T value)
    {
        _default = default;
        _value = default;
        _default = @default;
        _value = value;
    }

    #endregion Public Constructors

    #region Public Properties

    public T Default => _default;

    public bool HasChanged
    {
        get
        {
            if (Value == null && Default == null) return false;
            if (!((Value == null) & (Default != null)) && !((Value != null) & (Default == null)) &&
                (Value == null || Value.Equals(Default)) && (Default == null || Default.Equals(Value))) return false;
            return true;
        }
    }

    public T Value
    {
        get => _value;
        set => _value = value;
    }

    #endregion Public Properties
}