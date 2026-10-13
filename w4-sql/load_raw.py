"""W4: Load 5 Synthea CSVs into Postgres schema 'raw', unchanged."""
import os
import time
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text

DATA_DIR = Path(r"C:\data\Synthea\csv")          # folder containing patients.csv
DB_URL = os.getenv("DB_URL", "postgresql+psycopg2://de:de_pass@localhost:5432/warmups")
TABLES = ["patients", "providers", "encounters", "conditions", "medications"]


def load_table(engine, name: str) -> int:
    df = pd.read_csv(DATA_DIR / f"{name}.csv")
    df.columns = df.columns.str.strip().str.lower()
    df.to_sql(name, engine, schema="raw", if_exists="replace",
              index=False, chunksize=5000, method="multi")
    return len(df)


def main() -> None:
    engine = create_engine(DB_URL)
    with engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS raw"))

    for name in TABLES:
        start = time.perf_counter()
        rows = load_table(engine, name)
        print(f"raw.{name:12} {rows:>8,} rows  {time.perf_counter() - start:5.1f}s")


if __name__ == "__main__":
    main()