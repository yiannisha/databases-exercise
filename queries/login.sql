-- check user login
-- if login is successful, change user auth state and return role
-- if login is unsuccessful, return NULL
SELECT login_user($1, $2);