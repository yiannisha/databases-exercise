SELECT /*+ INDEX(t1 idx_recipe_tags) INDEX(t2 idx_recipe_tags) */
    t1.tag AS tag1,
    t2.tag AS tag2,
    COUNT(*) AS pair_count
FROM
    recipe_tags t1
JOIN
    recipe_tags t2 ON t1.recipe_id = t2.recipe_id AND t1.tag < t2.tag
GROUP BY
    t1.tag, t2.tag
ORDER BY
    pair_count DESC
LIMIT 3;
