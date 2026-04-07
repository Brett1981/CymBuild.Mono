namespace Concursus.Common.Shared.Extensions;

public static class ListExtensions
{
    #region Public Methods

    public static IEnumerable<TSource> DistinctBy<TSource, TKey>
        (this IEnumerable<TSource> source, Func<TSource, TKey> keySelector)
    {
        HashSet<TKey> seenKeys = new();
        foreach (var element in source)
            if (seenKeys.Add(keySelector(element)))
                yield return element;
    }

    #endregion Public Methods
}