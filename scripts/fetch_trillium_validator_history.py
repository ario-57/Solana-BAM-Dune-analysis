#!/usr/bin/env python3
"""Fetch historical Solana validator client classification from Trillium."""

from __future__ import annotations

import argparse
import csv
import sys
import time
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
import json


BASE_URL = "https://api.trillium.so/validator_rewards"

FIELDS = [
    "epoch",
    "identity_pubkey",
    "vote_account_pubkey",
    "name",
    "activated_stake",
    "client_type",
    "is_bam",
    "bam_node_connection",
    "bam_node_inferred",
    "is_rakurai",
    "scheduler_type",
    "fd_scheduler_mode",
    "version",
    "is_dz",
    "leader_slots",
    "blocks_produced",
]


def fetch_json(url: str, retries: int = 3, timeout: int = 90) -> Any:
    for attempt in range(1, retries + 1):
        try:
            req = Request(url, headers={"User-Agent": "solana-bam-dune-export/1.0"})
            with urlopen(req, timeout=timeout) as response:
                return json.loads(response.read().decode("utf-8"))
        except (HTTPError, URLError, TimeoutError) as exc:
            if attempt == retries:
                raise RuntimeError(f"failed to fetch {url}: {exc}") from exc
            time.sleep(1.5 * attempt)


def normalize_row(row: dict[str, Any]) -> dict[str, Any]:
    return {field: row.get(field) for field in FIELDS}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fetch Trillium validator_rewards history into a Dune-uploadable CSV."
    )
    parser.add_argument("--start-epoch", type=int, default=553)
    parser.add_argument(
        "--end-epoch",
        type=int,
        help="Defaults to the latest epoch returned by /validator_rewards/.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("data/trillium_validator_client_history.csv"),
    )
    parser.add_argument(
        "--failures",
        type=Path,
        default=Path("data/trillium_validator_client_history_failures.csv"),
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    latest_rows = fetch_json(f"{BASE_URL}/")
    latest_epoch = int(latest_rows[0]["epoch"])
    end_epoch = args.end_epoch or latest_epoch

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.failures.parent.mkdir(parents=True, exist_ok=True)

    total_rows = 0
    failed_epochs: list[tuple[int, str]] = []

    with args.output.open("w", newline="", encoding="utf-8") as output_file:
        writer = csv.DictWriter(output_file, fieldnames=FIELDS)
        writer.writeheader()

        for epoch in range(args.start_epoch, end_epoch + 1):
            try:
                rows = latest_rows if epoch == latest_epoch else fetch_json(f"{BASE_URL}/{epoch}")
            except RuntimeError as exc:
                failed_epochs.append((epoch, str(exc)))
                continue

            writer.writerows(normalize_row(row) for row in rows)
            total_rows += len(rows)

            if (epoch - args.start_epoch + 1) % 25 == 0:
                print(f"fetched through epoch {epoch}/{end_epoch}; rows={total_rows}")

    with args.failures.open("w", newline="", encoding="utf-8") as failures_file:
        writer = csv.writer(failures_file)
        writer.writerow(["epoch", "error"])
        writer.writerows(failed_epochs)

    print(f"wrote {total_rows} rows to {args.output}")
    print(f"failed epochs: {len(failed_epochs)}")
    return 0 if not failed_epochs else 1


if __name__ == "__main__":
    sys.exit(main())
