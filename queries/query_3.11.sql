SELECT
    j.judge_id,
    jc.name AS judge_name,
    c.name AS chef_name,
    SUM(m.mark) AS total_score
FROM
    marks m
JOIN judges j ON m.judge_id = j.judge_id AND m.episode_id = j.episode_id
JOIN chefs jc ON j.judge_id = jc.id
JOIN chefs c ON m.chef_id = c.id
GROUP BY
    j.judge_id,
    jc.name,
    c.name
ORDER BY
    total_score DESC
LIMIT 5;
