using Concursus.EF.Types;

namespace Concursus.EF;

public class Functions
{
    #region Public Methods

    public static string StripPredicateFromQuery(string sqlQuery)
    {
        int predicateIndex = sqlQuery.IndexOf("WHERE");

        if (predicateIndex > -1)
        {
            sqlQuery = sqlQuery[..predicateIndex];
        }

        return sqlQuery;
    }

    public static string ReplaceTargetGuidToken(EntityQuery query)
    {
        string targetGuidString = "";
        const string targetGuidToken = "[[TargetGuid]]";
        if (query.Statement.Contains(targetGuidToken))
        {
            targetGuidString = Guid.NewGuid().ToString();
            query.Statement = query.Statement.Replace(targetGuidToken, targetGuidString);
        }
        return targetGuidString;
    }

    #endregion Public Methods
}