-- Sanity check: the latest epoch should put active BAM stake near the public
-- Blockworks/Trillium chart for the same epoch.

WITH latest_epoch AS (
    SELECT MAX(CAST(epoch AS bigint)) AS epoch
    FROM trillium_validator_client_history_2026_05_25
)

SELECT
    CASE
        WHEN t.client_type = 'Jito_BAM (6)' AND CAST(t.is_bam AS boolean) = true
            THEN 'Jito BAM'
        WHEN t.client_type = 'Jito_BAM (6)' AND COALESCE(CAST(t.is_bam AS boolean), false) = false
            THEN 'Jito BAM disabled'
        ELSE t.client_type
    END AS validator_client,
    COUNT(*) AS validator_count,
    SUM(CAST(t.activated_stake AS double)) AS staked_sol
FROM trillium_validator_client_history_2026_05_25 t
JOIN latest_epoch l
    ON CAST(t.epoch AS bigint) = l.epoch
GROUP BY 1
ORDER BY staked_sol DESC;
