-- Daily active BAM stake share using Trillium's historical validator classification.
--
-- Upload the generated CSV to Dune and replace the table name below if needed.

WITH trillium AS (
    SELECT
        CAST(epoch AS bigint) AS epoch,
        vote_account_pubkey AS vote_account,
        CAST(activated_stake AS double) AS staked_sol,
        client_type,
        CAST(is_bam AS boolean) AS is_bam
    FROM trillium_validator_client_history_2026_05_25
),

epoch_dates AS (
    SELECT
        epoch,
        MIN(epoch_time) AS epoch_time
    FROM staking_solana.validator_stake_account_epochs
    GROUP BY 1
),

classified AS (
    SELECT
        DATE_TRUNC('day', e.epoch_time) AS day,
        t.staked_sol,
        CASE
            WHEN t.client_type = 'Jito_BAM (6)' AND t.is_bam = true
                THEN 'Jito BAM'
            WHEN t.client_type = 'Jito_BAM (6)' AND COALESCE(t.is_bam, false) = false
                THEN 'Jito BAM disabled'
            ELSE 'Other'
        END AS validator_type
    FROM trillium t
    LEFT JOIN epoch_dates e
        ON t.epoch = e.epoch
)

SELECT
    day,
    SUM(CASE WHEN validator_type = 'Jito BAM' THEN staked_sol ELSE 0 END) AS jito_bam_staked_sol,
    SUM(CASE WHEN validator_type = 'Jito BAM disabled' THEN staked_sol ELSE 0 END) AS jito_bam_disabled_staked_sol,
    SUM(CASE WHEN validator_type = 'Other' THEN staked_sol ELSE 0 END) AS other_staked_sol,
    SUM(staked_sol) AS total_staked_sol,
    SUM(CASE WHEN validator_type = 'Jito BAM' THEN staked_sol ELSE 0 END)
        / NULLIF(SUM(staked_sol), 0) AS jito_bam_share
FROM classified
WHERE day >= DATE '{{start_date}}'
GROUP BY 1
ORDER BY 1;
