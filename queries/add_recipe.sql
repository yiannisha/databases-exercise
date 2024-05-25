-- add_recipe.sql

INSERT INTO recipes (name, description, preparation_time, cooking_time, difficulty, meal_group, image_id, user_id)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)