const express = require('express');
const { Pool } = require('pg');
const bodyParser = require('body-parser');
const fs = require('fs');
const path = require('path');
const yargs = require('yargs/yargs');
const { hideBin } = require('yargs/helpers');
const { exec } = require('child_process');

// process cli args
const argv = yargs(hideBin(process.argv))
  .usage('Usage: $0 -u [name]')
  .option('u', {
    alias: 'user',
    describe: 'Database username',
    type: 'string',
    demandOption: 'Name is required',
    nargs: 1
  })
  .option('p', {
    alias: 'password',
    describe: 'Database password',
    type: 'string',
    demandOption: 'Password is required',
    nargs: 1
  })
  .option('H', {
    alias: 'host',
    describe: 'Database host',
    type: 'string',
    default: 'localhost',
    nargs: 1,
  })
  .option('d', {
    alias: 'database',
    describe: 'Database name',
    type: 'string',
    default: 'cooking',
    nargs: 1,
  })
  .option('P', {
    alias: 'port',
    describe: 'Database port',
    type: 'number',
    default: 5432,
    nargs: 1,
  })
  .option('s', {
    alias: 'setup',
    describe: 'Clear database and run setup.sql',
    type: 'boolean',
    default: false,
  })
  .help('h')
  .alias('h', 'help')
  .argv;

const app = express();
const app_port = 3000;

const pool = new Pool({
  user: argv.user,
  host: argv.host,
  database: argv.database,
  password: argv.password,
  port: argv.port,
});

let user = {
    username: null,
    role: null,
    loggedIn: false
};

// Check if the connection is successful
pool.on('connect', () => console.log('Connected to the database'));

pool.on('error', (err, client) => {
  console.error('Unexpected error on idle client', err);
  process.exit(-1);
});

// Helper function to load SQL files
const loadQuery = (file) => {
  return fs.readFileSync(path.join(__dirname, 'queries', file), 'utf8');
};

app.use(bodyParser.json());

// authentication
// login
app.post('/api/login', async (req, res) => {
    const { username, password } = req.body;
    const query = loadQuery('login.sql');
    try {
        console.log('Executing query: ', query, [username, password]);
        const { rows } = await pool.query(query, [username, password]);
        if (rows.length === 0) {
            res.status(401).send('Invalid username or password');
        } else {
            user.username = username;
            user.role = rows[0].login_user;
            user.loggedIn = true;
            console.log(user)
            res.status(200).send('Login successful');
        }
    } catch (err) {
        console.error('Error executing query: ', err);
        res.status(500).send('Internal server error');
    }
})

// logout
app.post('/api/logout', async (req, res) => {
    if (!user.loggedIn) {
        res.status(401).send('You are not logged in');
        return;
    }
    const query = loadQuery('logout.sql');
    await pool.query(query, [user.username]);

    user.username = null;
    user.role = null;
    user.loggedIn = false;
    res.status(200).send('Logout successful');
})

// admin functionality

// backup database
app.get('/api/backup', async (req, res) => {
    if (!user.loggedIn || user.role !== 'ADMIN') {
        res.status(401).send('Unauthorized');
        return;
    }

    const dumpFilePath = path.join(__dirname, `${argv.database}_backup.sql`);
    const dumpCommand = `pg_dump -U ${argv.user} -h ${argv.host} -p ${argv.port} -d ${argv.database} > "${dumpFilePath}"`;

    // Set the PGPASSWORD environment variable to avoid password prompt
    const env = { ...process.env, PGPASSWORD: argv.password };

    exec(dumpCommand, { env }, (error, stdout, stderr) => {
        if (error) {
            console.error(`Error creating database dump: ${error.message}`);
            res.status(500).send('Error creating database dump');
            return;
        }
        if (stderr) {
            console.error(`pg_dump stderr: ${stderr}`);
            res.status(500).send('Error during the database dump process');
            return;
        }
        console.log(`Database dump completed successfully: ${stdout}`);
        res.status(200).send('Database backup completed successfully');
    });
});

// restore database
app.post('/api/restore', async (req, res) => {
    if (!user.loggedIn || user.role !== 'ADMIN') {
        res.status(401).send('Unauthorized');
        return;
    }

    const dumpFilePath = path.join(__dirname, `${argv.database}_backup.sql`);
    const restoreCommand = `psql -U ${argv.user} -h ${argv.host} -p ${argv.port} -d ${argv.database} -f "${dumpFilePath}"`;

    // Set the PGPASSWORD environment variable to avoid password prompt
    const env = { ...process.env, PGPASSWORD: argv.password };

    exec(restoreCommand, { env }, (error, stdout, stderr) => {
        if (error) {
            console.error(`Error restoring database: ${error.message}`);
            res.status(500).send('Error restoring database');
            return;
        }
        if (stderr) {
            console.error(`psql stderr: ${stderr}`);
            res.status(500).send('Error during the database restore process');
            return;
        }
        console.log(`Database restore completed successfully: ${stdout}`);
        res.status(200).send('Database restore completed successfully');
    });
});

// add recipe
app.post('/api/recipe', async (req, res) => {
    if (!user.loggedIn || user.role !== 'CHEF') {
        res.status(401).send('Unauthorized');
        return;
    }

    const { recipe } = req.body;
    const query = loadQuery('add_recipe.sql');
    try {
        console.log('Executing query: ', query, [recipe.name, recipe.description, recipe.preparation_time, recipe.cooking_time, recipe.servings, recipe.difficulty, recipe.chef_id]);
        const { rows } = await pool.query(query, [recipe.name, recipe.description, recipe.preparation_time, recipe.cooking_time, recipe.servings, recipe.difficulty, recipe.chef_id]);
        res.status(200).send('Recipe added successfully');
    } catch (err) {
        console.error('Error executing query: ', err);
        res.status(500).send('Internal server error');
    }
});

// edit recipe
app.put('/api/recipe/:id', async (req, res) => {
    if (!user.loggedIn || user.role !== 'CHEF') {
        res.status(401).send('Unauthorized');
        return;
    }

    const { recipe } = req.body;
    const { id } = req.params;
    const query = loadQuery('edit_recipe.sql');
    try {

        console.log('Executing query: ', query, [recipe.name, recipe.description, recipe.preparation_time, recipe.cooking_time, recipe.difficulty, recipe.meal_group, recipe.image_id, id, user.username]);
        const { rows } = await pool.query(query, [recipe.name, recipe.description, recipe.preparation_time, recipe.cooking_time, recipe.difficulty, recipe.meal_group, recipe.image_id, id, user.username]);
        
        res.status(200).send('Recipe edited successfully');
    } catch (err) {
        console.error('Error executing query: ', err);
        res.status(500).send('Internal server error');
    }
});

// edit personal details
app.put('/api/user/:username', async (req, res) => {
    if (!user.loggedIn || user.role !== 'CHEF') {
        res.status(401).send('Unauthorized');
        return;
    }

    const { user: updatedUser } = req.body;
    const { username } = req.params;
    const query = loadQuery('edit_user.sql');
    try {
        console.log('Executing query: ', query, [updatedUser.username, updatedUser.password, username]);
        const { rows } = await pool.query(query, [updatedUser.username, updatedUser.password, username]);
        res.status(200).send('User edited successfully');
    } catch (err) {
        console.error('Error executing query: ', err);
        res.status(500).send('Internal server error');
    }
});

// run queries
app.get('/api/query/:queryId', async (req, res) => {
    if (!user.loggedIn) {
        res.status(401).send('Unauthorized');
        return;
    }

    const { queryId } = req.params;
    const queryFile = `query_${queryId}.sql`;

    try {
        const query = loadQuery(queryFile);
        console.log('Executing query: ', query);

        // Extract parameters from query string
        const queryParams = Object.values(req.query);
        console.log('With parameters: ', queryParams);

        // Execute query with parameters
        const { rows } = await pool.query(query, queryParams);
        res.status(200).json(rows);
    } catch (err) {
        console.error('Error executing query: ', err);
        res.status(500).send('Internal server error');
    }
});

pool.connect()
    .then(async client => {
        console.log("Database connection established!");
        client.release();

        // setup database
        if (argv.setup) {
            // clear database
            try {
                const clearQuery = fs.readFileSync(path.join(__dirname, 'queries', 'clear.sql'), 'utf8');
                await pool.query(clearQuery);
            }
            catch (err) {
                console.error("Error clearing the database: ", err);
                process.exit(-1);
            }

            try {
                const setupQuery = fs.readFileSync(path.join(__dirname, 'queries', 'setup.sql'), 'utf8');
                await pool.query(setupQuery);
            }
            catch (err) {
                console.error("Error setting up the database: ", err);
                process.exit(-1);
            }
        }

        // Start the server after establishing connection
        app.listen(app_port, () => {
            console.log(`Server running on port ${app_port}`);
        });
    });
