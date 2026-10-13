--Q1. How many patients are there by gender, and how many of each are deceased?
select gender, 
       count(*) as patients, 
       count(*) FILTER (where death_date is not NULL) as deceased 
from staging.patients 
group by gender
order by patients desc;

--Q2. What are the 10 most common diagnosed diseases, counted by number of distinct patients?
select description,
       count( distinct patient_id) as patients
from staging.conditions 
where description like '%disorder%'
group by description 
order by patients desc 
limit 10;

--Q3. For each encounter class (wellness, emergency, inpatient, and so on), how many encounters were there, and what was the average claim cost?
select encounter_class,
       count(*) as patients,
       round(avg(total_claim_cost),2) as average_claim_cost
from staging.encounters
group by encounter_class
order by average_claim_cost desc;

--Q4. Which 10 providers saw the most distinct patients? Show their specialty.
select p.name as name,
       p.specialty as specialty,
       count(distinct e.patient_id) as patients,
       count(*) as encounters
from staging.encounters e
join staging.providers p on p.provider_id = e.provider_id
group by p.provider_id, p.name, p.specialty
order by patients desc
limit 10;

--Q5 (first CTE). What are the 5 most common diseases among patients aged 65 or older?
with patient_age as (
   select patient_id,
          date_part('year', age(coalesce(death_date, current_date), birth_date)) as age
   from staging.patients
)
select c.description,
       count(distinct c.patient_id) as patients
from staging.conditions c
join patient_age pa on pa.patient_id = c.patient_id 
where age >= 65 and c.description like '%disorder%'
group by c.description 
order by patients desc
limit 5;

