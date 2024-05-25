SELECT
    e.season AS year,
    AVG(i.carbs) AS avg_carbs
FROM
    recipe_ingredients ri
JOIN
    ingredients i ON ri.ingredient_id = i.id
JOIN
    episodes e ON ri.recipe_id = e.id
GROUP BY
    e.season;
