SELECT
    c.name AS chef_name,
    cu.name AS cuisine_name,
    AVG(m.mark) AS average_score
FROM
    marks m
JOIN
    chefs c ON m.chef_id = c.id
JOIN
    episodes_cuisines_chefs ecc ON m.chef_id = ecc.chef_id AND m.episode_id = ecc.episode_id
JOIN
    cuisines cu ON ecc.cuisine_id = cu.id
GROUP BY
    c.name, cu.name;
