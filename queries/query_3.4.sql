SELECT
    c.name
FROM
    chefs c
LEFT JOIN
    judges j ON c.id = j.judge_id
WHERE
    j.judge_id IS NULL;
