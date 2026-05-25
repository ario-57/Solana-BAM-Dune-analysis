-- Daily validator client stake breakdown in the style of the Blockworks chart.
--
-- Upload the generated CSV to Dune and replace the table name below if needed.

WITH epoch_dates AS (
    SELECT
        epoch,
        MIN(epoch_time) AS epoch_time
    FROM staking_solana.validator_stake_account_epochs
    GROUP BY 1
)

SELECT
    DATE_TRUNC('day', e.epoch_time) AS day,
    CASE
        WHEN t.client_type = 'Jito_BAM (6)' AND CAST(t.is_bam AS boolean) = true
            THEN 'Jito BAM'
        WHEN t.client_type = 'Jito_BAM (6)' AND COALESCE(CAST(t.is_bam AS boolean), false) = false
            THEN 'Jito BAM disabled'
        ELSE t.client_type
    END AS validator_client,
    SUM(CAST(t.activated_stake AS double)) AS staked_sol
FROM trillium_validator_client_history_2026_05_25 t
LEFT JOIN epoch_dates e
    ON CAST(t.epoch AS bigint) = e.epoch
WHERE e.epoch_time >= TIMESTAMP '{{start_date}}'
GROUP BY 1, 2
ORDER BY 1, 3 DESC;
