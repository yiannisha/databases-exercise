SELECT
    e.id AS episode_id,
    SUM(c.experience) AS total_experience
FROM
    episodes e
JOIN episodes_cuisines ecc ON e.id = ecc.episode_id
JOIN episodes_cuisines_chefs eccc ON ecc.episode_id = eccc.episode_id AND ecc.cuisine_id = eccc.cuisine_id
JOIN chefs c ON eccc.chef_id = c.id
LEFT JOIN judges j ON e.id = j.episode_id
LEFT JOIN chefs jc ON j.judge_id = jc.id
GROUP BY
    e.id
ORDER BY
    total_experience ASC
LIMIT 1;
