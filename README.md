# Solana BAM Validator Stake Share

This repo shows how to reproduce a historical view of Solana stake by validator
client, with a focus on active Jito BAM stake versus Jito BAM disabled and other
validators.

The key point is that `client_type = 'Jito_BAM (6)'` does not always mean BAM is
active. Trillium exposes the additional `is_bam` field, which separates:

- `Jito BAM`: `client_type = 'Jito_BAM (6)'` and `is_bam = true`
- `Jito BAM disabled`: `client_type = 'Jito_BAM (6)'` and `is_bam = false`

## Data Source

Historical validator classification is fetched from Trillium:

```text
https://api.trillium.so/validator_rewards/{epoch}
```

The current/latest epoch can be fetched with:

```text
https://api.trillium.so/validator_rewards/
```

Important fields used:

```text
epoch
identity_pubkey
vote_account_pubkey
activated_stake
client_type
is_bam
bam_node_connection
bam_node_inferred
version
```

## Fetch The Data

Run:

```bash
python scripts/fetch_trillium_validator_history.py \
  --start-epoch 553 \
  --output data/trillium_validator_client_history.csv \
  --failures data/trillium_validator_client_history_failures.csv
```

Optional end epoch:

```bash
python scripts/fetch_trillium_validator_history.py \
  --start-epoch 553 \
  --end-epoch 975 \
  --output data/trillium_validator_client_history.csv
```

The generated CSV is intentionally ignored by git because it can be large.

## Upload To Dune

Upload the generated CSV to Dune as a user-uploaded table. The SQL files assume
the table name is:

```sql
trillium_validator_client_history_2026_05_25
```

If your uploaded table has a different name, replace that table name in the SQL
files.

## Dune Queries

Use these files:

- `sql/latest_epoch_validation.sql`: sanity check current stake by client label
- `sql/bam_stake_share_daily.sql`: active Jito BAM stake share over time
- `sql/validator_client_breakdown_daily.sql`: daily stake by validator client

The daily queries join Trillium epochs to Dune's Solana epoch timestamps from:

```sql
staking_solana.validator_stake_account_epochs
```

## Label Logic

Use this classification:

```sql
CASE
    WHEN client_type = 'Jito_BAM (6)' AND CAST(is_bam AS boolean) = true
        THEN 'Jito BAM'
    WHEN client_type = 'Jito_BAM (6)' AND COALESCE(CAST(is_bam AS boolean), false) = false
        THEN 'Jito BAM disabled'
    ELSE client_type
END
```

Do not classify active BAM using only:

```sql
client_type = 'Jito_BAM (6)'
```

That overcounts because it includes validators on the BAM-capable client with
BAM disabled.

## Expected Sanity Check

For the latest epoch fetched during this analysis, epoch `975`, the Trillium
split was approximately:

```text
Jito BAM:          133.3M SOL
Jito BAM disabled:  0.9M SOL
```

These values move with each epoch, so rerun the fetch and validation query when
you need a current snapshot.

## Files

```text
scripts/fetch_trillium_validator_history.py
sql/bam_stake_share_daily.sql
sql/validator_client_breakdown_daily.sql
sql/latest_epoch_validation.sql
data/README.md
```

## Notes

Earlier Jito Validator History exports are useful for identifying client
versions, but they do not expose the historical active BAM flag needed for this
analysis. Trillium's `is_bam` field is the missing signal.
