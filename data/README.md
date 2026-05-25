# Data

Generated CSVs are intentionally not committed because the full Trillium export
is large. Regenerate it with:

```bash
python scripts/fetch_trillium_validator_history.py \
  --start-epoch 553 \
  --output data/trillium_validator_client_history.csv
```

Upload the generated CSV to Dune and use the SQL files in `sql/`.
