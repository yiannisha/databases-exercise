-- edit_user.sql

-- Update a user

-- check if the user is assigned to the chef

BEGIN;
DECLARE
    user_id INT;
BEGIN
    SELECT id INTO user_id FROM users WHERE id = $1;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found';
    END IF;
END;

-- update the user
UPDATE users
SET
    username = $2,
    email = $3
WHERE id = $1
RETURNING *;

COMMIT;