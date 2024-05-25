-- edit_recipe.sql

-- Update a recipe

-- check if the recipe is assigned to the chef
SELECT check_recipe_assigned_to_chef($9, $8);

-- update the recipe
UPDATE recipes
set
name = $1,
description = $2,
preparation_time = $3,
cooking_time = $4,
difficulty = $5,
meal_group = $6,
image_id = $7
WHERE id = $8
RETURNING *;