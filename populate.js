const { Client } = require('pg');
const fs = require('fs');

// Read JSON data
const data = JSON.parse(fs.readFileSync('data.json', 'utf8'));

// Database connection configuration
const client = new Client({
    user: 'yiannis',
    host: 'localhost',
    database: 'cooking',
    password: 'apoel123',
    port: 5432,
});

async function populateDatabase() {
    try {
        await client.connect();

        // Insert images
        for (const image of data.images) {
            await client.query(
                'INSERT INTO images (id, description) VALUES ($1, $2)',
                [image.id, image.description]
            );
        }

        // Insert food_groups
        for (const group of data.food_groups) {
            await client.query(
                'INSERT INTO food_groups (name, description) VALUES ($1, $2)',
                [group.name, group.description]
            );
        }

        // Insert ingredients
        for (const ingredient of data.ingredients) {
            await client.query(
                'INSERT INTO ingredients (id, image_id, name, food_group_id, calories, fat, protein, carbs) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)',
                [
                    ingredient.id, 
                    ingredient.image_id, 
                    ingredient.name, 
                    ingredient.food_group_id, 
                    ingredient.calories, 
                    ingredient.fat, 
                    ingredient.protein, 
                    ingredient.carbs
                ]
            );
        }

        // Insert thematic categories
        for (const category of data.thematic_categories) {
            await client.query(
                'INSERT INTO thematic_categories (image_id, name, description) VALUES ($1, $2, $3)',
                [category.image_id, category.name, category.description]
            );
        }

        // Insert equipment
        for (const equip of data.equipment) {
            await client.query(
                'INSERT INTO equipment (id, image_id, name, instructions) VALUES ($1, $2, $3, $4)',
                [equip.id, equip.image_id, equip.name, equip.instructions]
            );
        }

        // Insert cuisines
        for (const cuisine of data.cuisines) {
            await client.query(
                'INSERT INTO cuisines (id, image_id, name) VALUES ($1, $2, $3)',
                [cuisine.id, cuisine.image_id, cuisine.name]
            );
        }

        // Insert recipes
        for (const recipe of data.recipes) {
            await client.query(
                'INSERT INTO recipes (id, image_id, basic_ingredient_id, cooking_type, cuisine, difficulty, name, meal_group, servings) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)',
                [
                    recipe.id,
                    recipe.image_id,
                    recipe.basic_ingredient_id,
                    recipe.cooking_type,
                    recipe.cuisine,
                    recipe.difficulty,
                    recipe.name,
                    recipe.meal_group,
                    recipe.servings
                ]
            );
        }

        // Insert recipe_ingredients
        for (const recipeIngredient of data.recipe_ingredients) {
            await client.query(
                'INSERT INTO recipe_ingredients (recipe_id, ingredient_id, quantity) VALUES ($1, $2, $3)',
                [
                    recipeIngredient.recipe_id,
                    recipeIngredient.ingredient_id,
                    recipeIngredient.quantity
                ]
            );
        }

        // Insert steps
        for (const step of data.steps) {
            await client.query(
                'INSERT INTO steps (id, image_id, description, cooking_time, preparation_time) VALUES ($1, $2, $3, $4, $5)',
                [
                    step.id,
                    step.image_id,
                    step.description,
                    step.cooking_time,
                    step.preparation_time
                ]
            );
        }

        // Insert recipe_steps
        for (const recipeStep of data.recipe_steps) {
            await client.query(
                'INSERT INTO recipe_steps (recipe_id, step_id) VALUES ($1, $2)',
                [recipeStep.recipe_id, recipeStep.step_id]
            );
        }

        // Insert recipe_tips
        for (const recipeTip of data.recipe_tips) {
            await client.query(
                'INSERT INTO recipe_tips (recipe_id, tip) VALUES ($1, $2)',
                [recipeTip.recipe_id, recipeTip.tip]
            );
        }

        // Insert recipe_tags
        for (const recipeTag of data.recipe_tags) {
            await client.query(
                'INSERT INTO recipe_tags (recipe_id, tag) VALUES ($1, $2)',
                [recipeTag.recipe_id, recipeTag.tag]
            );
        }

        // Insert recipe_equipment
        for (const recipeEquip of data.recipe_equipment) {
            await client.query(
                'INSERT INTO recipe_equipment (recipe_id, equipment_id, quantity) VALUES ($1, $2, $3)',
                [recipeEquip.recipe_id, recipeEquip.equipment_id, recipeEquip.quantity]
            );
        }

        // Insert recipe_thematic_categories
        for (const recipeCategory of data.recipe_thematic_categories) {
            await client.query(
                'INSERT INTO recipe_thematic_categories (recipe_id, thematic_category_id) VALUES ($1, $2)',
                [recipeCategory.recipe_id, recipeCategory.thematic_category_id-200]
            );
        }
        
        // Insert users
        for (const user of data.users) {
            await client.query(
                'INSERT INTO users (username, password, user_role) VALUES ($1, $2, $3)',
                [user.username, user.password, 'CHEF']
            );
        }
        // Insert admin
        await client.query(
            'INSERT INTO users (username, password, user_role) VALUES ($1, $2, $3)',
            ['admin', 'admin', 'ADMIN']
        );

        // Insert chefs
        for (const chef of data.chefs) {
            await client.query(
                'INSERT INTO chefs (id, image_id, name, surname, phone_number, birth_date, experience, job_title) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)',
                [
                    chef.id,
                    chef.image_id,
                    chef.name,
                    chef.surname,
                    chef.phone_number,
                    chef.birth_date,
                    chef.experience,
                    chef.job_title
                ]
            );
        }

        // insert episodes
        for (const episode of data.episodes) {
            await client.query(
                'INSERT INTO episodes (image_id, season) VALUES ($1, $2)',
                [episode.image_id, episode.season]
            );
        }

        // Insert episodes_cuisines
        for (const episodeCuisine of data.episodes_cuisines) {
            await client.query(
                'INSERT INTO episodes_cuisines (episode_id, cuisine_id) VALUES ($1, $2)',
                [episodeCuisine.episode_id, episodeCuisine.cuisine_id]
            );
        }

        // Insert episodes_cuisines_chefs
        for (const episodeCuisineChef of data.episodes_cuisines_chefs) {
            await client.query(
                'INSERT INTO episodes_cuisines_chefs (episode_id, cuisine_id, chef_id, recipe_id) VALUES ($1, $2, $3, $4)',
                [episodeCuisineChef.episode_id, episodeCuisineChef.cuisine_id, episodeCuisineChef.chef_id, episodeCuisineChef.recipe_id]
            );
        }

        // Insert judges
        for (const judge of data.judges) {
            await client.query(
                'INSERT INTO judges (episode_id, judge_id) VALUES ($1, $2)',
                [judge.episode_id, judge.judge_id]
            );
        }

        // Insert marks
        for (const mark of data.marks) {
            await client.query(
                'INSERT INTO marks (episode_id, judge_id, chef_id, mark) VALUES ($1, $2, $3, $4)',
                [mark.episode_id, mark.judge_id, mark.chef_id, mark.mark]
            );
        }

        console.log('Data inserted successfully');
    } catch (err) {
        console.error('Error inserting data', err);
    } finally {
        await client.end();
    }
}

populateDatabase();
