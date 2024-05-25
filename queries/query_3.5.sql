SELECT
    j.judge_id,
    COUNT(DISTINCT j.episode_id) AS episode_count
FROM
    judges j
JOIN episodes e ON j.episode_id = e.id
WHERE
    e.season = $1
GROUP BY
    j.judge_id
HAVING
    COUNT(DISTINCT j.episode_id) > 3
ORDER BY
    episode_count DESC;
