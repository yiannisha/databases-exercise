SELECT
    tc.name,
    COUNT(*) AS appearance_count
FROM
    recipe_thematic_categories rtc
JOIN
    thematic_categories tc ON rtc.thematic_category_id = tc.id
GROUP BY
    tc.name
ORDER BY
    appearance_count DESC
LIMIT 1;
