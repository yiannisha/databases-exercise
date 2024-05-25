-- Create images table
CREATE TABLE images (
    id SERIAL PRIMARY KEY,
    description TEXT
);

-- Create food_groups table
CREATE TABLE food_groups (
    id SERIAL PRIMARY KEY,
    image_id INT REFERENCES images(id),
    name TEXT,
    description TEXT
);

-- Create ingredients table
CREATE TABLE ingredients (
    id SERIAL PRIMARY KEY,
    image_id INT REFERENCES images(id),
    name TEXT,
    food_group_id INT REFERENCES food_groups(id),
    quantity INT,
    calories INT,
    fat INT,
    protein INT,
    carbs INT
);

-- Create thematic category table
CREATE TABLE thematic_categories (
    id SERIAL PRIMARY KEY,
    image_id INT REFERENCES images(id),
    name TEXT,
    description TEXT
);

-- Create steps table
CREATE TABLE steps (
    id SERIAL PRIMARY KEY,
    image_id INT REFERENCES images(id),
    description TEXT,
    cooking_time INT,
    preparation_time INT
);

-- Create equipment table
CREATE TABLE equipment (
    id SERIAL PRIMARY KEY,
    image_id INT REFERENCES images(id),
    name TEXT,
    instructions TEXT
);

-- Create cuisines table
CREATE TABLE cuisines (
    id SERIAL PRIMARY KEY,
    image_id INT REFERENCES images(id),
    name TEXT
);

-- Create cooking type type
CREATE TYPE COOKING_TYPE AS ENUM ('BAKING', 'CONFECTIONERY');

-- Create difficulty type
CREATE TYPE DIFFICULTY AS ENUM ('VERY EASY', 'EASY', 'MEDIUM', 'HARD', 'VERY HARD');

-- Create meal group type
CREATE TYPE MEAL_GROUP AS ENUM ('BREAKFAST', 'LUNCH', 'DINNER', 'SNACK', 'DESSERT');

-- Create recipes table
CREATE TABLE recipes (
    id SERIAL PRIMARY KEY,
    image_id INT REFERENCES images(id),
    equipment_id INT REFERENCES equipment(id),
    basic_ingredient_id INT REFERENCES ingredients(id),
    cooking_type COOKING_TYPE,
    cuisine INT REFERENCES cuisines(id),
    difficulty DIFFICULTY,
    name TEXT,
    meal_group MEAL_GROUP,
    servings INT
);

-- Recipe ingredients table
CREATE TABLE recipe_ingredients (
    recipe_id INT REFERENCES recipes(id),
    ingredient_id INT REFERENCES ingredients(id)
);

-- Recipe tags table
CREATE TABLE recipe_tags (
    recipe_id INT REFERENCES recipes(id),
    tag TEXT
);

-- Recipe tips table
CREATE TABLE recipe_tips (
    -- each recipe can have up to 3 tips
    recipe_id INT REFERENCES recipes(id),
    tip TEXT
);

-- Recipe steps table
CREATE TABLE recipe_steps (
    recipe_id INT REFERENCES recipes(id),
    step_id INT REFERENCES steps(id)
);

-- Create JOB_TITLE type
CREATE TYPE JOB_TITLE AS ENUM ('CHEF', 'SOUS CHEF', 'LINE COOK', 'PASTRY CHEF', 'EXECUTIVE CHEF');

-- Create chefs table
CREATE TABLE chefs (
    id SERIAL PRIMARY KEY,
    image_id INT REFERENCES images(id),
    name TEXT,
    surname TEXT,
    phone_number TEXT,
    birth_date DATE,
    experience INT,
    job_title JOB_TITLE
);

-- Preparation time function
CREATE OR REPLACE FUNCTION preparation_time(recipe_id INT)
RETURNS INT AS $$
DECLARE
    total_time INT;
BEGIN
    SELECT SUM(preparation_time) INTO total_time
    FROM steps
    WHERE id IN (
        SELECT step_id
        FROM recipe_steps
        WHERE id = recipe_id
    );
    RETURN total_time;
END;
$$ LANGUAGE plpgsql;

-- Cooking time function
CREATE OR REPLACE FUNCTION cooking_time(recipe_id INT)
RETURNS INT AS $$
DECLARE
    total_time INT;
BEGIN
    SELECT SUM(cooking_time) INTO total_time
    FROM steps
    WHERE id IN (
        SELECT step_id
        FROM recipe_steps
        WHERE id = recipe_id
    );
    RETURN total_time;
END;
$$ LANGUAGE plpgsql;

-- Total time function
CREATE OR REPLACE FUNCTION total_time(recipe_id INT)
RETURNS INT AS $$
DECLARE
    total_time INT;
BEGIN
    total_time := preparation_time(recipe_id) + cooking_time(recipe_id);
    RETURN total_time;
END;
$$ LANGUAGE plpgsql;

-- Fat content per serving function
CREATE OR REPLACE FUNCTION fat_content(recipe_id INT)
RETURNS INT AS $$
DECLARE
    fat_content INT;
    total_servings INT;
BEGIN
    SELECT servings INTO total_servings
    FROM recipes
    WHERE id = recipe_id;

    SELECT SUM(fat) INTO fat_content
    FROM ingredients
    WHERE id IN (
        SELECT ingredient_id
        FROM recipe_ingredients
        WHERE id = recipe_id
    );

    RETURN fat_content / total_servings;
END;
$$ LANGUAGE plpgsql;

-- Protein content per serving function
CREATE OR REPLACE FUNCTION protein_content(recipe_id INT)
RETURNS INT AS $$
DECLARE
    protein_content INT;
    total_servings INT;
BEGIN
    SELECT servings INTO total_servings
    FROM recipes
    WHERE id = recipe_id;

    SELECT SUM(protein) INTO protein_content
    FROM ingredients
    WHERE id IN (
        SELECT ingredient_id
        FROM recipe_ingredients
        WHERE id = recipe_id
    );

    RETURN protein_content / total_servings;
END;
$$ LANGUAGE plpgsql;

-- Carbs content per serving function
CREATE OR REPLACE FUNCTION carbs_content(recipe_id INT)
RETURNS INT AS $$
DECLARE
    carbs_content INT;
    total_servings INT;
BEGIN
    SELECT servings INTO total_servings
    FROM recipes
    WHERE id = recipe_id;

    SELECT SUM(carbs) INTO carbs_content
    FROM ingredients
    WHERE id IN (
        SELECT ingredient_id
        FROM recipe_ingredients
        WHERE id = recipe_id
    );

    RETURN carbs_content / total_servings;
END;
$$ LANGUAGE plpgsql;

-- Calories content per serving function
CREATE OR REPLACE FUNCTION calories_content(recipe_id INT)
RETURNS INT AS $$
DECLARE
    calories_content INT;
    total_servings INT;
BEGIN
    SELECT servings INTO total_servings
    FROM recipes
    WHERE id = recipe_id;

    SELECT SUM(calories) INTO calories_content
    FROM ingredients
    WHERE id IN (
        SELECT ingredient_id
        FROM recipe_ingredients
        WHERE id = recipe_id
    );

    RETURN calories_content / total_servings;
END;
$$ LANGUAGE plpgsql;

-- Chef age function
CREATE OR REPLACE FUNCTION chef_age(chef_id INT)
RETURNS INT AS $$
DECLARE
    age INT;
BEGIN
    SELECT EXTRACT(YEAR FROM AGE(birth_date)) INTO age
    FROM chefs
    WHERE id = chef_id;
    RETURN age;
END;
$$ LANGUAGE plpgsql;