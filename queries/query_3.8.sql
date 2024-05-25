SELECT
    e.id AS episode_id,
    COUNT(re.equipment_id) AS equipment_count
FROM
    episodes e
JOIN episodes_cuisines ecc ON e.id = ecc.episode_id
JOIN episodes_cuisines_chefs eccc ON ecc.episode_id = eccc.episode_id AND ecc.cuisine_id = eccc.cuisine_id
JOIN recipes r ON eccc.recipe_id = r.id
JOIN recipe_equipment re ON r.id = re.recipe_id
GROUP BY
    e.id
ORDER BY
    equipment_count DESC
LIMIT 1;
