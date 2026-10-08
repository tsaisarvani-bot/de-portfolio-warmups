CREATE TABLE IF NOT EXISTS patients (
    id          TEXT PRIMARY KEY,
    birthdate   DATE,
    gender      TEXT,
    city        TEXT
);

INSERT INTO patients VALUES
  ('p1', '1985-03-12', 'F', 'Boston'),
  ('p2', '1972-11-30', 'M', 'Worcester'),
  ('p3', '2001-07-04', 'F', 'Springfield');