SELECT
    fg.name
FROM
    food_groups fg
WHERE
    NOT EXISTS (
        SELECT 1
        FROM recipe_ingredients ri
        JOIN ingredients i ON ri.ingredient_id = i.id
        WHERE i.food_group_id = fg.id
    );
