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
    -- these values should be per 100g
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
    ingredient_id INT REFERENCES ingredients(id),
    quantity INT
);

-- Recipe tags table
CREATE TABLE recipe_tags (
    recipe_id INT REFERENCES recipes(id),
    tag TEXT
);

-- Recipe tips table
CREATE TABLE recipe_tips (
    -- each recipe can have up to 3 tips
    -- checked with check_recipe_tips_limit trigger
    recipe_id INT REFERENCES recipes(id),
    tip TEXT
);

-- Recipe steps table
CREATE TABLE recipe_steps (
    recipe_id INT REFERENCES recipes(id),
    step_id INT REFERENCES steps(id)
);

-- Recipe equipment table
CREATE TABLE recipe_equipment (
    -- each recipe must have at least one equipment
    -- checked with check_recipe_equipment_after_insert trigger
    recipe_id INT REFERENCES recipes(id),
    equipment_id INT REFERENCES equipment(id),
    quantity INT
);

-- Recipe thematic categories table
CREATE TABLE recipe_thematic_categories (
    recipe_id INT REFERENCES recipes(id),
    thematic_category_id INT REFERENCES thematic_categories(id)
);

-- Create JOB_TITLE type
CREATE TYPE JOB_TITLE AS ENUM ('CHEF', 'SOUS CHEF', 'LINE COOK', 'PASTRY CHEF', 'EXECUTIVE CHEF');

-- Create chefs table
CREATE TABLE chefs (
    id INT REFERENCES users(id) PRIMARY KEY,
    image_id INT REFERENCES images(id),
    name TEXT,
    surname TEXT,
    phone_number TEXT,
    birth_date DATE,
    experience INT,
    job_title JOB_TITLE
);

-- Create episodes table
CREATE TABLE episodes (
    -- there are 10 episodes per season
    -- checked with check_episodes_limit trigger
    id SERIAL PRIMARY KEY,
    image_id INT REFERENCES images(id),
    season INT,
);

-- Episodes cuisines table
CREATE TABLE episodes_cuisines (
    -- each episode must have 10 different cuisines
    -- checked with check_episodes_cuisines_limit trigger
    episode_id INT REFERENCES episodes(id),
    cuisine_id INT REFERENCES cuisines(id),
    PRIMARY KEY (episode_id, cuisine_id)
);

-- Episodes cuisines chefs table
CREATE TABLE episodes_cuisines_chefs (
    -- each cuisine in each episode must have 10 different chefs
    -- checked with check_episodes_cuisines_chefs_limit trigger
    episode_id INT,
    cuisine_id INT,
    PRIMARY KEY (episode_id, cuisine_id),
    FOREIGN KEY (episode_id, cuisine_id) REFERENCES episodes_cuisines(episode_id, cuisine_id),
    chef_id INT REFERENCES chefs(id),
    -- recipe must be from the same cuisine
    -- checked with check_episodes_cuisines_chefs_recipe trigger
    recipe_id INT REFERENCES recipes(id)
);

-- Create marks table
CREATE TABLE marks (
    episode_id INT REFERENCES episodes(id),
    -- ensure that the judge is not selected in the same episode as a chef
    -- checked with check_judge_chef_episode trigger
    judge_id INT REFERENCES chefs(id),
    mark INT CHECK (mark BETWEEN 1 AND 5)
);

-- Create USER_ROLE type
CREATE TYPE USER_ROLE AS ENUM ('ADMIN', 'CHEF');

-- Create users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username TEXT,
    password TEXT,
    role USER_ROLE
);

-- Recipe food group function
CREATE OR REPLACE FUNCTION recipe_food_group(recipe_id INT)
RETURNS TEXT AS $$
DECLARE
    food_group_name TEXT;
BEGIN
    SELECT name INTO food_group_name
    FROM food_groups
    WHERE id = (
        SELECT food_group_id
        FROM ingredients
        WHERE id = (
            SELECT basic_ingredient_id
            FROM recipes
            WHERE id = recipe_id
        )
    );
    RETURN food_group_name;
END;
$$ LANGUAGE plpgsql;

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

-- Create a trigger function to check if a recipe has more than 3 tips
CREATE OR REPLACE FUNCTION check_recipe_tips_limit() RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) FROM recipe_tips WHERE recipe_id = NEW.recipe_id) >= 3 THEN
        RAISE EXCEPTION 'A recipe can have up to 3 tips.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to check if a recipe has more than 3 tips
CREATE TRIGGER ensure_recipe_tips_limit
BEFORE INSERT OR UPDATE ON recipe_tips
FOR EACH ROW EXECUTE FUNCTION check_recipe_tips_limit();

-- Create a trigger function to check if a recipe has at least one step
CREATE OR REPLACE FUNCTION check_recipe_steps_after_insert() RETURNS TRIGGER AS $$
BEGIN
    -- We use PERFORM 1 to check if there is at least one step and discard the result
    PERFORM 1
    FROM recipe_steps
    WHERE recipe_id = NEW.id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'A recipe must have at least one step.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to check if a recipe has at least one step
-- The following trigger assumes that transactions are used
CREATE CONSTRAINT TRIGGER ensure_recipe_steps_exist
AFTER INSERT ON recipes
-- We use DEFERRABLE INITIALLY DEFERRED to allow the trigger to be deferred
-- This is necessary because we need to insert the recipe first and then the steps
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION check_recipe_steps_after_insert();

-- Create a trigger function to check if a recipe has at least one equipment
CREATE OR REPLACE FUNCTION check_recipe_equipment_after_insert() RETURNS TRIGGER AS $$
BEGIN
    PERFORM 1
    FROM recipe_equipment
    WHERE recipe_id = NEW.id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'A recipe must have at least one equipment.';
    END IF;

    RETURN NEW;
END;

-- Create a trigger to check if a recipe has at least one equipment
-- The following trigger assumes that transactions are used
CREATE CONSTRAINT TRIGGER ensure_recipe_equipment_exist
AFTER INSERT ON recipes
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION check_recipe_equipment_after_insert();

-- Create a trigger function to check if there are more than 10 episodes
CREATE OR REPLACE FUNCTION check_episodes_limit() RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) FROM episodes WHERE season = NEW.season) >= 10 THEN
        RAISE EXCEPTION 'There can be only 10 episodes per season.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to check if there are more than 10 episodes
CREATE TRIGGER ensure_episodes_limit
BEFORE INSERT OR UPDATE ON episodes
FOR EACH ROW EXECUTE FUNCTION check_episodes_limit();

-- Create a trigger function to check if there are more than 10 cuisines per episode
CREATE OR REPLACE FUNCTION check_episodes_cuisines_limit() RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) FROM episodes_cuisines WHERE episode_id = NEW.episode_id) != 10 THEN
        RAISE EXCEPTION 'There can be only 10 cuisines per episode.';
    END IF;
    RETURN NEW;
END;

-- Create a trigger to check if there are more than 10 cuisines per episode
-- Assuming that transactions are used
CREATE TRIGGER ensure_episodes_cuisines_limit
AFTER INSERT ON episodes
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION check_episodes_cuisines_limit();

-- Create a trigger function to check if there are more than 10 chefs per cuisine in an episode
CREATE OR REPLACE FUNCTION check_episodes_cuisines_chefs_limit() RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) FROM episodes_cuisines_chefs WHERE episode_cuisine_id = NEW.episode_cuisine_id) != 10 THEN
        RAISE EXCEPTION 'There can be only 10 chefs per cuisine in an episode.';
    END IF;
    RETURN NEW;
END;

-- Create a trigger to check if there are more than 10 chefs per cuisine in an episode
-- Assuming that transactions are used
CREATE TRIGGER ensure_episodes_cuisines_chefs_limit
AFTER INSERT ON episodes_cuisines
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION check_episodes_cuisines_chefs_limit();

-- Create a trigger function to check if a judge is not selected as a chef in the same episode
CREATE OR REPLACE FUNCTION check_judge_chef_episode() RETURNS TRIGGER AS $$
BEGIN
    -- Check that the judge is not selected as a chef in the same episode
    IF EXISTS (
        SELECT 1
        FROM episodes_cuisines_chefs
        WHERE episode_id = NEW.episode_id
        AND chef_id = NEW.judge_id
    ) THEN
        RAISE EXCEPTION 'A judge cannot be selected as a chef in the same episode.';
    END IF;

    -- Check that there are 3 judges per episode
    IF (SELECT COUNT(*) FROM marks WHERE episode_id = NEW.episode_id) != 3 THEN
        RAISE EXCEPTION 'There must be 3 judges per episode.';
    END IF;

    RETURN NEW;
END;

-- Create a trigger to check if a judge is not selected as a chef in the same episode
CREATE TRIGGER ensure_judge_chef_episode
AFTER INSERT ON marks
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_judge_chef_episode();

-- Create a trigger function to check if a recipe is from the same cuisine as the chef
CREATE OR REPLACE FUNCTION check_episodes_cuisines_chefs_recipe() RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT cuisine FROM recipes WHERE id = NEW.recipe_id) != NEW.cuisine_id THEN
        RAISE EXCEPTION 'A recipe must be from the same cuisine as the chef.';
    END IF;
    RETURN NEW;
END;

-- Create a trigger to check if a recipe is from the same cuisine as the chef
CREATE TRIGGER ensure_episodes_cuisines_chefs_recipe
AFTER INSERT ON episodes_cuisines_chefs
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_episodes_cuisines_chefs_recipe();

