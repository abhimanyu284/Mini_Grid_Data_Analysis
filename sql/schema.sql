USE minigrid;

DROP TABLE IF EXISTS fact_inverter_day;
DROP TABLE IF EXISTS fact_household_day;
DROP TABLE IF EXISTS fact_solar_weather;
DROP TABLE IF EXISTS fact_london_weather_day;
DROP TABLE IF EXISTS profile_by_tariff;
DROP TABLE IF EXISTS dim_inverter;
DROP TABLE IF EXISTS dim_plant;
DROP TABLE IF EXISTS dim_household;
DROP TABLE IF EXISTS dim_date;

CREATE TABLE dim_date (
  date_key DATE PRIMARY KEY,
  year SMALLINT, month TINYINT, day TINYINT,
  day_of_week TINYINT, is_weekend TINYINT,
  is_bank_holiday TINYINT, holiday_name VARCHAR(40)
);

CREATE TABLE dim_plant (
  plant_id INT PRIMARY KEY,
  plant_name VARCHAR(20)
);

CREATE TABLE dim_inverter (
  plant_id INT NOT NULL,
  source_key VARCHAR(20) NOT NULL,
  PRIMARY KEY (plant_id, source_key),
  FOREIGN KEY (plant_id) REFERENCES dim_plant(plant_id)
);

CREATE TABLE dim_household (
  household_id VARCHAR(12) PRIMARY KEY,
  tariff_type VARCHAR(3),
  acorn VARCHAR(10),
  acorn_group VARCHAR(15),
  days_observed_2013 SMALLINT,
  is_full_year TINYINT
);

CREATE TABLE fact_inverter_day (
  plant_id INT NOT NULL,
  source_key VARCHAR(20) NOT NULL,
  date_key DATE NOT NULL,
  energy_kwh DOUBLE, max_ac_kw DOUBLE,
  producing_intervals INT, expected_intervals INT,
  availability_pct DOUBLE, sun_kwh_m2 DOUBLE,
  yield_per_sun DOUBLE, rel_perf DOUBLE,
  PRIMARY KEY (plant_id, source_key, date_key),
  FOREIGN KEY (plant_id, source_key) REFERENCES dim_inverter(plant_id, source_key),
  FOREIGN KEY (date_key) REFERENCES dim_date(date_key)
);

CREATE TABLE fact_household_day (
  household_id VARCHAR(12) NOT NULL,
  date_key DATE NOT NULL,
  total_kwh DOUBLE, peak_kwh DOUBLE, night_kwh DOUBLE,
  max_halfhour_kwh DOUBLE, missing_slots TINYINT,
  peak_share DOUBLE, billed_gbp_flat DOUBLE,
  PRIMARY KEY (household_id, date_key),
  FOREIGN KEY (household_id) REFERENCES dim_household(household_id),
  FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
  INDEX idx_date (date_key)
);

CREATE TABLE fact_solar_weather (
  plant_id INT NOT NULL,
  ts DATETIME NOT NULL,
  ambient_temp DOUBLE, module_temp DOUBLE, irradiation DOUBLE,
  PRIMARY KEY (plant_id, ts),
  FOREIGN KEY (plant_id) REFERENCES dim_plant(plant_id)
);

CREATE TABLE fact_london_weather_day (
  date_key DATE PRIMARY KEY,
  temp_max DOUBLE, temp_min DOUBLE, humidity DOUBLE,
  cloud_cover DOUBLE, wind_speed DOUBLE,
  FOREIGN KEY (date_key) REFERENCES dim_date(date_key)
);

CREATE TABLE profile_by_tariff (
  tariff_type VARCHAR(3) NOT NULL,
  slot TINYINT NOT NULL,
  time_label VARCHAR(5),
  mean_kwh DOUBLE,
  PRIMARY KEY (tariff_type, slot)
);