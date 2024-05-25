WITH yearly_cuisine_count AS (
    SELECT
        e.season AS year,
        cu.name AS cuisine_name,
        COUNT(*) AS participation_count
    FROM
        episodes_cuisines ec
    JOIN
        cuisines cu ON ec.cuisine_id = cu.id
    JOIN
        episodes e ON ec.episode_id = e.id
    GROUP BY
        year, cu.name
    HAVING
        COUNT(*) >= 3
)
SELECT
    yc1.cuisine_name,
    yc1.participation_count,
    yc1.year,
    yc2.year
FROM
    yearly_cuisine_count yc1
JOIN
    yearly_cuisine_count yc2 ON yc1.cuisine_name = yc2.cuisine_name AND yc1.participation_count = yc2.participation_count AND yc1.year = yc2.year - 1;
