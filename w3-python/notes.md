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