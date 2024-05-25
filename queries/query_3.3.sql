SELECT
    c.name AS chef_name,
    COUNT(ecc.recipe_id) AS recipe_count
FROM
    chefs c
JOIN episodes_cuisines_chefs ecc ON c.id = ecc.chef_id
WHERE
    EXTRACT(YEAR FROM AGE(c.birth_date)) < 30
GROUP BY
    c.name
ORDER BY
    recipe_count DESC
LIMIT 5;
