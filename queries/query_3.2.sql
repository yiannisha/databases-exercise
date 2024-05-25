SELECT
    c.name AS chef_name,
    cu.name AS cuisine_name
FROM
    chefs c
JOIN episodes_cuisines_chefs ecc ON c.id = ecc.chef_id
JOIN cuisines cu ON ecc.cuisine_id = cu.id
JOIN episodes e ON ecc.episode_id = e.id
WHERE
    cu.name = $1
    AND e.season = $2;
