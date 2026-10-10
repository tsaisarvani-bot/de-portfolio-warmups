# W3 Part 1: Loading and cleaning Synthea patients

## Key terms
- **DataFrame:** A table in Python made of rows and named columns, like an Excel sheet
  I can filter, join and transform with code. pandas is the library that provides it.
- **dtype:** The data type of a column. It decides what I can do with it: I can only
  do date math on a `datetime64` column, not on text (`object`).
- **Null (NaN / NaT):** A missing value. `NaN` is missing for numbers and text;
  `NaT` ("not a time") is missing for dates. A null isn't always a mistake. Sometimes
  it means "not applicable."
- **PII:** Personally identifiable information, data that identifies a real person,
  such as an SSN, passport number or home address. It needs to be removed or masked
  as early as possible in a pipeline.

## Why `errors="coerce"`
With the default setting, one badly formatted date (for example "2023-02-30" or a typo)
makes `pd.to_datetime` raise an error and stops the whole load. With `errors="coerce"`,
bad values become `NaT` and the rest of the file still loads. I then count those NaTs in
my quality checks, so bad data is caught and measured instead of crashing the pipeline
or slipping through unnoticed. In production I would send those rows to a quarantine
table for review.

## Why a null deathdate is valid
Most patients are alive, so they have no death date. Here the null means "still living,"
not "data is missing." Filling it with a fake date would be wrong and would break age
and mortality calculations. Instead I kept it null and added an `is_deceased` column
(True/False) so the meaning is explicit and easy to filter on.

## Why I dropped the PII columns
The analysis I need (age bands, patient counts, location) doesn't use SSN, driver's
license, passport or street address. Keeping data I don't need only adds risk: under
healthcare privacy rules such as HIPAA, every copy of PII is something that can leak.
The rule I follow is to keep only the columns the use case needs, and to remove
sensitive ones as early as possible, before data spreads to other tables or files.

## Quality checks I ran
- Null birthdates: 0
- Birthdates in the future: 0
- Death date before birth date: 0
- Duplicate patient IDs: 0

## Part 2: Age bands and Parquet

### Why I moved from a notebook to a script
A notebook is good for exploring: I could run one cell at a time and look at the
output. But a pipeline needs code that runs top to bottom with one command and
gives the same result every time. I split the logic into functions (load, clean,
add age band, summarize) so each step does one job, can be reused, and can be
tested on its own in W6. `if __name__ == "__main__"` means the script only runs
when called directly, not when another file imports its functions.

### CSV vs Parquet (measured)
- CSV: 0.34 MB → Parquet: 0.14 MB, about 2.4× smaller.
- Caveat: this isn't a pure format comparison. The Parquet file is missing the
  7 PII columns I dropped, and it has 3 new ones (is_deceased, age, age_band).
  Also, on a file this small, Parquet's fixed metadata overhead is a big share
  of the size. On larger data the savings are usually much bigger.
- Parquet stores data by column instead of by row. Values in one column are
  similar (all dates, all "M"/"F"), so they compress well.
- Parquet also stores each column's data type. When I reloaded the CSV, dates
  came back as text and needed converting again. Parquet gave back
  `datetime64` straight away.
- Query engines can read only the columns a query needs, instead of whole rows.

### Why age uses the death date for deceased patients
A deceased patient's age should stop at their death. If I measured everyone up
to today, someone born in 1920 who died in 1990 would show as 100+ instead of 70.
That would push them into the wrong age band and skew the summary. So:
end date = death date if it exists, otherwise today.

### What partitioning is and when it helps
Partitioning splits the output into folders by a column's value, such as
`gender=F/` and `gender=M/`. A query that filters on that column (for example
`WHERE gender = 'F'`) can skip the other folders entirely, so it reads less data
and runs faster. It helps most on large tables, with columns that are often used
in filters and have a small number of distinct values, such as date, region, or
gender. Partitioning on a column with thousands of distinct values, like patient
ID, creates lots of tiny files and makes things slower.