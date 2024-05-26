const express = require('express');
const { Pool } = require('pg');
const bodyParser = require('body-parser');
const fs = require('fs');
const path = require('path');
const yargs = require('yargs/yargs');
const { hideBin } = require('yargs/helpers');

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

// Endpoint to get all users
app.get('/test', async (req, res) => {
  const query = loadQuery('test.sql');
  const { rows } = await pool.query(query);
  res.json(rows);
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