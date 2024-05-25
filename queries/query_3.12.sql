WITH difficulty_numeric AS (
    SELECT
        r.id AS recipe_id,
        r.difficulty,
        CASE r.difficulty
            WHEN 'VERY EASY' THEN 1
            WHEN 'EASY' THEN 2
            WHEN 'MEDIUM' THEN 3
            WHEN 'HARD' THEN 4
            WHEN 'VERY HARD' THEN 5
        END AS difficulty_value
    FROM
        recipes r
)
SELECT
    e.season AS year,
    e.id AS episode_id,
    AVG(dn.difficulty_value) AS avg_difficulty
FROM
    episodes e
JOIN episodes_cuisines ecc ON e.id = ecc.episode_id
JOIN episodes_cuisines_chefs eccc ON ecc.episode_id = eccc.episode_id AND ecc.cuisine_id = eccc.cuisine_id
JOIN difficulty_numeric dn ON eccc.recipe_id = dn.recipe_id
GROUP BY
    e.season,
    e.id
ORDER BY
    year,
    avg_difficulty DESC
LIMIT 1;
