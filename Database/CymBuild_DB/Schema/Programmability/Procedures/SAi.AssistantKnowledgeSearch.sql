SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SAi].[AssistantKnowledgeSearch]')
GO

CREATE PROCEDURE [SAi].[AssistantKnowledgeSearch]
(
      @SearchText         NVARCHAR(1000)
    , @CategoryGuid       UNIQUEIDENTIFIER = NULL
    , @PublishedOnly      BIT = 1
    , @AuthoritativeFirst BIT = 1
    , @Top                INT = 5
    , @MinimumScore       INT = 1
)
AS
BEGIN
    SET NOCOUNT ON;

    SET @Top = CASE
                   WHEN @Top IS NULL OR @Top < 1 THEN 5
                   WHEN @Top > 20 THEN 20
                   ELSE @Top
               END;

    SET @MinimumScore = CASE
                            WHEN @MinimumScore IS NULL OR @MinimumScore < 1 THEN 1
                            ELSE @MinimumScore
                        END;

    DECLARE @Terms TABLE
    (
        Term NVARCHAR(100) NOT NULL PRIMARY KEY
    );

    INSERT INTO @Terms
    (
        Term
    )
    SELECT DISTINCT
        LEFT(LOWER(LTRIM(RTRIM(ss.value))), 100) AS Term
    FROM STRING_SPLIT(
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(ISNULL(@SearchText, N''), N'?', N' '),
                N'.', N' '),
            N',', N' '),
        N'''', N' '),
        N' '
    ) AS ss
    WHERE LEN(LTRIM(RTRIM(ss.value))) >= 3
      AND LOWER(LTRIM(RTRIM(ss.value))) NOT IN
      (
            N'how'
          , N'does'
          , N'what'
          , N'when'
          , N'where'
          , N'why'
          , N'the'
          , N'and'
          , N'for'
          , N'with'
          , N'from'
          , N'this'
          , N'that'
          , N'can'
          , N'you'
          , N'are'
          , N'into'
          , N'onto'
      );

    IF NOT EXISTS
    (
        SELECT
            1
        FROM @Terms AS t
    )
    BEGIN
        INSERT INTO @Terms
        (
            Term
        )
        SELECT
            LEFT(LOWER(LTRIM(RTRIM(ISNULL(@SearchText, N'')))), 100)
        WHERE LEN(LTRIM(RTRIM(ISNULL(@SearchText, N'')))) > 0;
    END;

    ;WITH Matches AS
    (
        SELECT
              aki.ID
            , aki.Guid
            , aki.Title
            , aki.Slug
            , ISNULL(kc.Name, N'') AS CategoryName
            , aki.ContentTypeCode
            , aki.SourceTypeCode
            , aki.StorageUrl
            , aki.PreviewUrl
            , aki.Summary
            , aki.IsAuthoritative
            , aki.IsPublished
            , ISNULL(currentVersion.VersionNumber, 1) AS VersionNumber
            , COALESCE(currentVersion.ExtractedText, aki.Summary, N'') AS ExtractedText
            , SUM
              (
                    CASE
                        WHEN LOWER(aki.Title) LIKE N'%' + t.Term + N'%'
                        THEN 100
                        ELSE 0
                    END
                  + CASE
                        WHEN LOWER(aki.Slug) LIKE N'%' + t.Term + N'%'
                        THEN 60
                        ELSE 0
                    END
                  + CASE
                        WHEN LOWER(ISNULL(aki.Summary, N'')) LIKE N'%' + t.Term + N'%'
                        THEN 30
                        ELSE 0
                    END
                  + CASE
                        WHEN LOWER(ISNULL(currentVersion.ExtractedText, N'')) LIKE N'%' + t.Term + N'%'
                        THEN 15
                        ELSE 0
                    END
              )
              + CASE
                    WHEN aki.IsAuthoritative = 1
                    THEN 20
                    ELSE 0
                END AS MatchScore
        FROM SAi.AssistantKnowledgeItems AS aki
        LEFT JOIN SAi.AssistantKnowledgeCategories AS kc
            ON kc.ID = aki.KnowledgeCategoryId
           AND kc.RowStatus NOT IN (0, 254)
        OUTER APPLY
        (
            SELECT TOP (1)
                  akiv.VersionNumber
                , akiv.ExtractedText
            FROM SAi.AssistantKnowledgeItemVersions AS akiv
            WHERE akiv.KnowledgeItemId = aki.ID
              AND akiv.RowStatus NOT IN (0, 254)
              AND akiv.IsCurrent = 1
            ORDER BY
                  akiv.VersionNumber DESC
                , akiv.ID DESC
        ) AS currentVersion
        JOIN @Terms AS t
            ON LOWER(aki.Title) LIKE N'%' + t.Term + N'%'
            OR LOWER(aki.Slug) LIKE N'%' + t.Term + N'%'
            OR LOWER(ISNULL(aki.Summary, N'')) LIKE N'%' + t.Term + N'%'
            OR LOWER(ISNULL(currentVersion.ExtractedText, N'')) LIKE N'%' + t.Term + N'%'
        WHERE aki.RowStatus NOT IN (0, 254)
          AND
          (
              @PublishedOnly = 0
              OR aki.IsPublished = 1
          )
          AND
          (
              @CategoryGuid IS NULL
              OR kc.Guid = @CategoryGuid
          )
        GROUP BY
              aki.ID
            , aki.Guid
            , aki.Title
            , aki.Slug
            , kc.Name
            , aki.ContentTypeCode
            , aki.SourceTypeCode
            , aki.StorageUrl
            , aki.PreviewUrl
            , aki.Summary
            , aki.IsAuthoritative
            , aki.IsPublished
            , currentVersion.VersionNumber
            , currentVersion.ExtractedText
    )
    SELECT TOP (@Top)
          m.Guid
        , m.Title
        , m.Slug
        , m.CategoryName
        , m.ContentTypeCode
        , m.SourceTypeCode
        , m.StorageUrl
        , m.PreviewUrl
        , m.Summary
        , m.IsAuthoritative
        , m.IsPublished
        , m.VersionNumber
        , m.ExtractedText
        , m.MatchScore
    FROM Matches AS m
    WHERE m.MatchScore >= @MinimumScore
    ORDER BY
          CASE
              WHEN @AuthoritativeFirst = 1
               AND m.IsAuthoritative = 1
              THEN 0
              ELSE 1
            END
        , m.MatchScore DESC
        , m.ID DESC;
END;
GO