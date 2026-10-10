"""W3: Clean Synthea patients, add age bands, save as Parquet."""
from pathlib import Path

import pandas as pd

DATA_PATH = Path(r"C:\data\Synthea\csv\patients.csv")      # your path here
OUTPUT_DIR = Path(r"C:\data\Synthea\processed")

PII_COLS = ["ssn", "drivers", "passport", "address", "prefix", "suffix", "maiden"]
AGE_BINS = [-1, 17, 34, 49, 64, 200]
AGE_LABELS = ["0-17", "18-34", "35-49", "50-64", "65+"]


def load_patients(path: Path) -> pd.DataFrame:
    return pd.read_csv(path)


def clean_patients(df: pd.DataFrame) -> pd.DataFrame:
    clean = df.copy()
    clean.columns = clean.columns.str.strip().str.lower()
    clean = clean.drop(columns=[c for c in PII_COLS if c in clean.columns])
    clean["birthdate"] = pd.to_datetime(clean["birthdate"], errors="coerce")
    clean["deathdate"] = pd.to_datetime(clean["deathdate"], errors="coerce")
    clean["is_deceased"] = clean["deathdate"].notna()
    if "marital" in clean.columns:
        clean["marital"] = clean["marital"].fillna("Unknown")
    text_cols = clean.select_dtypes(include="object").columns
    clean[text_cols] = clean[text_cols].apply(lambda s: s.str.strip())
    return clean.drop_duplicates(subset="id")


def add_age_band(df: pd.DataFrame, as_of: pd.Timestamp) -> pd.DataFrame:
    out = df.copy()
    # Deceased patients: age at death. Living patients: age today.
    end_date = out["deathdate"].fillna(as_of)
    out["age"] = ((end_date - out["birthdate"]).dt.days // 365.25).astype("Int64")
    out["age_band"] = pd.cut(out["age"], bins=AGE_BINS, labels=AGE_LABELS)
    return out


def summarize_by_age_band(df: pd.DataFrame) -> pd.DataFrame:
    return (
        df.groupby(["age_band", "gender"], observed=False)
        .size()
        .unstack(fill_value=0)
        .assign(total=lambda t: t.sum(axis=1))
    )


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    patients = add_age_band(clean_patients(load_patients(DATA_PATH)), pd.Timestamp.today())
    summary = summarize_by_age_band(patients)
    print(summary)

    patients.to_parquet(OUTPUT_DIR / "patients_clean.parquet", index=False)
    summary.to_parquet(OUTPUT_DIR / "patients_by_age_band.parquet")
    patients.to_parquet(OUTPUT_DIR / "patients_by_gender", partition_cols=["gender"], index=False)
    print(f"Wrote {len(patients)} patients to {OUTPUT_DIR}")


if __name__ == "__main__":
    main()