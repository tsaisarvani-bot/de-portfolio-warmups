# W4 Part 1: Loading Synthea into Postgres

## Key terms

- **Schema:** A named folder inside a database that groups related tables.
  I used two: `raw` for untouched copies of the CSVs, and `staging` for the
  cleaned, typed versions. The same table name can exist in both
  (`raw.encounters` vs `staging.encounters`) without clashing.

- **Primary key:** A column whose value is unique and never null, so it
  identifies exactly one row. `patient_id` in `staging.patients` is a primary
  key, and Postgres rejects any insert that would duplicate it.

- **Foreign key:** A column that must match an existing primary key in another
  table. `staging.encounters.patient_id` references `staging.patients`, so the
  database won't accept a visit for a patient who doesn't exist. It enforces
  data integrity at the database level instead of trusting the source.

- **Index:** A sorted lookup structure on one or more columns, like the index
  at the back of a book. Without one, Postgres scans every row to find a
  patient's encounters. With an index on `(patient_id, start_ts)`, it jumps
  straight to them. Indexes speed up reads but slightly slow down writes and
  use extra storage.

## Why a separate raw layer?

1. **Reprocessing without re-extracting.** If I find a bug in my cleaning
   logic, I fix the SQL and rebuild staging from raw. I don't have to go back
   to the source system, which in real life may be slow, rate-limited, or no
   longer have the old data.
2. **The load never fails on bad data.** Raw accepts whatever the source
   sends. Type problems (a bad date, text in a number column) show up in the
   staging step, where I can see and handle them, instead of crashing the
   extract.
3. **Auditability.** Raw is the record of exactly what the source delivered.
   If a number in a report looks wrong, I can trace it back and prove whether
   the issue came from the source or from my transformations.
4. **Separation of concerns.** Extract-and-load and transform are separate
   steps that can fail and rerun independently. This is the ELT pattern that
   dbt is built around.

## Load results (from `load_raw.py`)

| Table        | Rows | Load time (s) |
|--------------|-----:|--------------:|
| patients     | 1,163|  0.7s         |
| providers    | 5,056|  0.9s         |
| encounters   |61,459| 13.9s         |
| conditions   |38,094|  3.2s         |
| medications  |56,430| 10.8s         |

Validation: raw and staging row counts matched for all 5 tables.

Observation: the load time grows with row count, and the largest table takes
the longest. `to_sql` with `chunksize=5000` and `method="multi"` sends rows in
batches instead of one INSERT per row, which is much faster. For millions of
rows, Postgres `COPY` would be faster still.

## What ON_ERROR_STOP protects against

By default, `psql` reports an error and then carries on with the next
statement. If one `CREATE TABLE` failed, the script would keep going: later
statements would fail too, or succeed against missing tables, leaving the
database half-built. The final output could even look normal.

`-v ON_ERROR_STOP=1` makes `psql` stop at the first error and exit with a
failure code. That gives me:
- a clear signal of exactly which statement broke,
- no partially built staging layer that looks finished but isn't,
- a non-zero exit code, so an orchestrator like Airflow (W9) marks the task
  as failed instead of reporting success.