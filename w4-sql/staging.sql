CREATE SCHEMA IF NOT EXISTS staging;
DROP TABLE IF EXISTS staging.medications, staging.conditions,
                     staging.encounters, staging.providers, staging.patients;

-- Patients (PII left out on purpose)
CREATE TABLE staging.patients AS
SELECT id::text                              AS patient_id,
       birthdate::date                       AS birth_date,
       deathdate::date                       AS death_date,
       gender::text, race::text, ethnicity::text,
       city::text, state::text, county::text,
       healthcare_expenses::numeric(14,2)    AS healthcare_expenses,
       healthcare_coverage::numeric(14,2)    AS healthcare_coverage
FROM raw.patients;
ALTER TABLE staging.patients ADD PRIMARY KEY (patient_id);

-- Providers
CREATE TABLE staging.providers AS
SELECT id::text AS provider_id, organization::text AS organization_id,
       name::text, gender::text, speciality::text AS specialty,
       city::text, state::text
FROM raw.providers;
ALTER TABLE staging.providers ADD PRIMARY KEY (provider_id);

-- Encounters (visits)
CREATE TABLE staging.encounters AS
SELECT id::text                              AS encounter_id,
       start::timestamptz                    AS start_ts,
       stop::timestamptz                     AS stop_ts,
       patient::text                         AS patient_id,
       provider::text                        AS provider_id,
       organization::text                    AS organization_id,
       encounterclass::text                  AS encounter_class,
       code::text, description::text,
       base_encounter_cost::numeric(12,2)    AS base_cost,
       total_claim_cost::numeric(12,2)       AS total_claim_cost,
       payer_coverage::numeric(12,2)         AS payer_coverage,
       reasondescription::text               AS reason_description
FROM raw.encounters;
ALTER TABLE staging.encounters ADD PRIMARY KEY (encounter_id);
ALTER TABLE staging.encounters
  ADD FOREIGN KEY (patient_id) REFERENCES staging.patients (patient_id);

-- Conditions (diagnoses)
CREATE TABLE staging.conditions AS
SELECT start::date AS start_date, stop::date AS stop_date,
       patient::text AS patient_id, encounter::text AS encounter_id,
       code::text, description::text
FROM raw.conditions;
ALTER TABLE staging.conditions
  ADD FOREIGN KEY (patient_id) REFERENCES staging.patients (patient_id);

-- Medications
CREATE TABLE staging.medications AS
SELECT start::timestamptz AS start_ts, stop::timestamptz AS stop_ts,
       patient::text AS patient_id, encounter::text AS encounter_id,
       code::text, description::text,
       base_cost::numeric(12,2) AS base_cost,
       dispenses::int           AS dispenses,
       totalcost::numeric(14,2) AS total_cost
FROM raw.medications;
ALTER TABLE staging.medications
  ADD FOREIGN KEY (patient_id) REFERENCES staging.patients (patient_id);

-- Indexes for the joins and filters you'll use in Parts 2 and 3
CREATE INDEX ON staging.encounters  (patient_id, start_ts);
CREATE INDEX ON staging.conditions  (patient_id);
CREATE INDEX ON staging.conditions  (code);
CREATE INDEX ON staging.medications (patient_id);

-- Validation: raw and staging row counts must match
SELECT 'patients' AS tbl, (SELECT count(*) FROM raw.patients) AS raw_rows,
       (SELECT count(*) FROM staging.patients) AS staging_rows
UNION ALL SELECT 'providers',   (SELECT count(*) FROM raw.providers),   (SELECT count(*) FROM staging.providers)
UNION ALL SELECT 'encounters',  (SELECT count(*) FROM raw.encounters),  (SELECT count(*) FROM staging.encounters)
UNION ALL SELECT 'conditions',  (SELECT count(*) FROM raw.conditions),  (SELECT count(*) FROM staging.conditions)
UNION ALL SELECT 'medications', (SELECT count(*) FROM raw.medications), (SELECT count(*) FROM staging.medications);