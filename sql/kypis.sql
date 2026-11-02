USE minigrid;

-- 1a. inverters with fewer than 34 days of data
SELECT plant_id, source_key, COUNT(*) AS days
FROM fact_inverter_day
GROUP BY plant_id, source_key
HAVING days < 34
ORDER BY days;

-- 1b. the 2013 day with no London weather
SELECT d.date_key
FROM dim_date d
LEFT JOIN fact_london_weather_day w USING (date_key)
WHERE d.year = 2013 AND w.date_key IS NULL;

-- 2. solar: inverter scorecard
CREATE OR REPLACE VIEW vw_inverter_scorecard AS
SELECT p.plant_name, f.plant_id, f.source_key,
       COUNT(*)                          AS days_reported,
       ROUND(SUM(f.energy_kwh), 0)       AS total_kwh,
       ROUND(AVG(f.availability_pct), 1) AS avg_availability_pct,
       ROUND(AVG(f.rel_perf), 3)         AS avg_rel_perf,
       RANK() OVER (PARTITION BY f.plant_id ORDER BY AVG(f.rel_perf)) AS perf_rank_in_plant
FROM fact_inverter_day f
JOIN dim_plant p USING (plant_id)
GROUP BY p.plant_name, f.plant_id, f.source_key;

SELECT * FROM vw_inverter_scorecard WHERE avg_rel_perf < 0.9 ORDER BY avg_rel_perf;

-- 3. solar: plant daily energy with 7-day moving average
CREATE OR REPLACE VIEW vw_plant_daily AS
SELECT plant_id, date_key,
       ROUND(SUM(energy_kwh), 0)       AS plant_kwh,
       ROUND(AVG(availability_pct), 1) AS avg_availability_pct,
       ROUND(MAX(sun_kwh_m2), 2)       AS sun_kwh_m2,
       ROUND(AVG(SUM(energy_kwh)) OVER (PARTITION BY plant_id ORDER BY date_key
             ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 0) AS kwh_7d_avg
FROM fact_inverter_day
GROUP BY plant_id, date_key;

SELECT * FROM vw_plant_daily ORDER BY plant_id, date_key;

-- 4. london: household-month KPIs (full-year households only)
CREATE OR REPLACE VIEW vw_household_month AS
SELECT h.household_id, h.tariff_type, h.acorn_group, d.month,
       COUNT(f.total_kwh)                       AS days,
       ROUND(SUM(f.total_kwh), 1)               AS kwh,
       ROUND(AVG(f.peak_share), 4)              AS avg_peak_share,
       ROUND(AVG(f.night_kwh), 3)               AS avg_night_kwh,
       ROUND(MAX(f.max_halfhour_kwh), 3)        AS peak_halfhour_kwh,
       ROUND(SUM(f.total_kwh) / (COUNT(f.total_kwh) * 48) / MAX(f.max_halfhour_kwh), 3) AS load_factor,
       ROUND(SUM(f.billed_gbp_flat), 2)         AS billed_gbp
FROM fact_household_day f
JOIN dim_household h USING (household_id)
JOIN dim_date d ON d.date_key = f.date_key
WHERE h.is_full_year = 1
GROUP BY h.household_id, h.tariff_type, h.acorn_group, d.month;

SELECT * FROM vw_household_month LIMIT 20;

-- 5. london: Std vs ToU
SELECT h.tariff_type,
       COUNT(DISTINCT h.household_id)  AS households,
       ROUND(AVG(f.total_kwh), 2)      AS avg_daily_kwh,
       ROUND(AVG(f.peak_share), 4)     AS avg_peak_share,
       ROUND(AVG(f.night_kwh), 3)      AS avg_night_kwh
FROM fact_household_day f
JOIN dim_household h USING (household_id)
WHERE h.is_full_year = 1
GROUP BY h.tariff_type;

-- 6. london: Acorn groups
SELECT h.acorn_group,
       COUNT(DISTINCT h.household_id)   AS households,
       ROUND(AVG(f.total_kwh), 2)       AS avg_daily_kwh,
       ROUND(AVG(f.billed_gbp_flat), 3) AS avg_daily_bill_gbp,
       ROUND(AVG(f.peak_share), 4)      AS avg_peak_share
FROM fact_household_day f
JOIN dim_household h USING (household_id)
WHERE h.is_full_year = 1
GROUP BY h.acorn_group
ORDER BY avg_daily_kwh DESC;

-- 7. london: temperature sensitivity
SELECT CASE WHEN w.temp_max < 5  THEN '1: under 5C'
            WHEN w.temp_max < 10 THEN '2: 5-10C'
            WHEN w.temp_max < 15 THEN '3: 10-15C'
            WHEN w.temp_max < 20 THEN '4: 15-20C'
            ELSE '5: 20C+' END AS temp_band,
       COUNT(*)                   AS household_days,
       ROUND(AVG(f.total_kwh), 2) AS avg_daily_kwh
FROM fact_household_day f
JOIN fact_london_weather_day w USING (date_key)
JOIN dim_household h USING (household_id)
WHERE h.is_full_year = 1
GROUP BY temp_band
ORDER BY temp_band;

-- 8. london: weekdays, weekends, bank holidays
SELECT CASE WHEN d.is_bank_holiday = 1 THEN 'bank holiday'
            WHEN d.is_weekend = 1 THEN 'weekend' ELSE 'weekday' END AS day_type,
       ROUND(AVG(f.total_kwh), 2)  AS avg_daily_kwh,
       ROUND(AVG(f.peak_share), 4) AS avg_peak_share
FROM fact_household_day f
JOIN dim_date d ON d.date_key = f.date_key
JOIN dim_household h USING (household_id)
WHERE h.is_full_year = 1
GROUP BY day_type;

-- 9. london: anomaly candidates (7+ days under 20% of usual use)
WITH hh_avg AS (
  SELECT household_id, AVG(total_kwh) AS avg_kwh
  FROM fact_household_day
  GROUP BY household_id
)
SELECT f.household_id, COUNT(*) AS low_days, ROUND(MAX(a.avg_kwh), 2) AS normal_daily_kwh
FROM fact_household_day f
JOIN hh_avg a USING (household_id)
WHERE f.total_kwh < 0.2 * a.avg_kwh
GROUP BY f.household_id
HAVING low_days >= 7
ORDER BY low_days DESC
LIMIT 20;