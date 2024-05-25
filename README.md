# Node.js Project Setup and Usage Guide

This guide will help you set up and use a simple Node.js project that connects to a PostgreSQL database, handles user authentication, and provides functionality for managing recipes.

## Prerequisites

Before you start, ensure you have the following installed:

- Node.js (v12 or later)
- npm (Node package manager, comes with Node.js)
- PostgreSQL (v9.5 or later)

## Project Structure

The project structure should look like this:

```
project-directory/
│
├── app.js
├── package.json
├── queries/
│   ├── add_recipe.sql
│   ├── clear.sql
│   ├── edit_recipe.sql
│   ├── edit_user.sql
│   ├── login.sql
│   ├── logout.sql
│   ├── setup.sql
│   └── query_*.sql
└── README.md
```

## Setting Up the Project

1. **Clone the repository**

   ```bash
   git clone <repository_url>
   cd project-directory
   ```

2. **Install dependencies**

   ```bash
   npm install
   ```

3. **Set up PostgreSQL**

   Ensure your PostgreSQL server is running and accessible. Create a database and a user with the necessary privileges.

## Running the Project

1. **Start the server**

   You can start the server with the necessary database connection parameters. Replace placeholders with your actual database credentials.

   ```bash
   node app.js -u <DB_USER> -p <DB_PASSWORD> -H <DB_HOST> -d <DB_NAME> -P <DB_PORT> --setup
   ```

   Example:

   ```bash
   node app.js -u postgres -p password123 -H localhost -d cooking -P 5432 --setup
   ```

   The `--setup` option will clear the database and run the `setup.sql` script.

2. **API Endpoints**

   - **Login**
     ```http
     POST /api/login
     Content-Type: application/json
     {
       "username": "your_username",
       "password": "your_password"
     }
     ```

   - **Logout**
     ```http
     POST /api/logout
     ```

   - **Backup Database**
     ```http
     GET /api/backup
     ```

   - **Restore Database**
     ```http
     POST /api/restore
     ```

   - **Add Recipe**
     ```http
     POST /api/recipe
     Content-Type: application/json
     {
       "recipe": {
         "name": "Recipe Name",
         "description": "Recipe Description",
         "preparation_time": 15,
         "cooking_time": 30,
         "servings": 4,
         "difficulty": "Medium",
         "chef_id": 1
       }
     }
     ```

   - **Edit Recipe**
     ```http
     PUT /api/recipe/:id
     Content-Type: application/json
     {
       "recipe": {
         "name": "Updated Recipe Name",
         "description": "Updated Recipe Description",
         "preparation_time": 20,
         "cooking_time": 35,
         "difficulty": "Hard",
         "meal_group": "Dinner",
         "image_id": 2
       }
     }
     ```

   - **Edit User**
     ```http
     PUT /api/user/:username
     Content-Type: application/json
     {
       "user": {
         "username": "new_username",
         "password": "new_password"
       }
     }
     ```

   - **Run Custom Query**
     ```http
     GET /api/query/:queryId
     ```

     Replace `:queryId` with the actual query ID. You can pass query parameters in the URL. For example, to run a query with ID 1 and parameters `param1` and `param2`:

     ```http
     GET /api/query/1?param1=value1&param2=value2
     ```

     The server will execute the SQL query from `queries/query_1.sql` with the provided parameters.

     Example `query_1.sql`:
     ```sql
     SELECT * FROM recipes WHERE chef_id = $1 AND difficulty = $2;
     ```

     In this case, `param1` corresponds to `$1` and `param2` corresponds to `$2`.

## Conclusion

You now have a running Node.js project with a PostgreSQL database. This setup allows for user authentication, recipe management, and administrative tasks such as database backup and restore. Make sure to customize the SQL queries and adapt the code to fit your specific requirements.