WITH chef_participation AS (
    SELECT
        chef_id,
        COUNT(*) AS participation_count
    FROM
        episodes_cuisines_chefs
    GROUP BY
        chef_id
),
max_participation AS (
    SELECT
        MAX(participation_count) AS max_participation_count
    FROM
        chef_participation
)
SELECT
    cp.chef_id
FROM
    chef_participation cp, max_participation mp
WHERE
    cp.participation_count <= mp.max_participation_count - 5;
