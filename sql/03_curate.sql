-- Run after 02_ingest.sql. Rerunning replaces the Curated tables.

-- 01. Combine TMIN and SNOW by station and day
CREATE OR REPLACE TABLE `data732.weather_curated.curated_station_day`
PARTITION BY date
CLUSTER BY id AS
SELECT
  id,
  date,
  MAX(IF(element = 'TMIN' AND is_valid,
    (value / 10.0) * 9.0 / 5.0 + 32.0, NULL)) AS tmin_f,
  MAX(IF(element = 'SNOW' AND is_valid, value, NULL)) AS snow_mm,
  MAX(IF(element = 'SNOW' AND is_valid,
    IF(TRIM(mflag) = 'T', 1, 0), NULL)) AS trace_snow
FROM (
  SELECT
    *,
    NULLIF(TRIM(qflag), '') IS NULL
      AND value IS NOT NULL
      AND value != -9999 AS is_valid
  FROM `data732.weather_raw.raw_weather_2025`
)
GROUP BY id, date;

-- 02. Select stations using the P1 coverage rule
CREATE OR REPLACE TABLE `data732.weather_curated.selected_stations` AS
WITH coverage AS (
  SELECT
    id,
    COUNTIF(tmin_f IS NOT NULL AND snow_mm IS NOT NULL) AS paired_year,
    COUNTIF(tmin_f IS NOT NULL AND snow_mm IS NOT NULL
      AND date BETWEEN DATE '2025-01-01' AND DATE '2025-03-31')
      AS paired_jan_mar,
    COUNTIF(tmin_f IS NOT NULL AND snow_mm IS NOT NULL
      AND date BETWEEN DATE '2025-11-01' AND DATE '2025-12-31')
      AS paired_nov_dec
  FROM `data732.weather_curated.curated_station_day`
  GROUP BY id
)
SELECT *
FROM coverage
WHERE paired_year >= 300
  AND paired_jan_mar >= 72
  AND paired_nov_dec >= 49;

-- 03. Create station dimension
CREATE OR REPLACE TABLE `data732.weather_curated.dim_station` AS
SELECT
  ROW_NUMBER() OVER (ORDER BY s.id) AS station_key,
  s.id AS station_id,
  s.state,
  s.name AS station_name,
  s.latitude,
  s.longitude,
  s.elevation
FROM `data732.weather_raw.raw_stations` AS s
JOIN `data732.weather_curated.selected_stations` AS e
  ON s.id = e.id;

-- 04. Create date dimension
CREATE OR REPLACE TABLE `data732.weather_curated.dim_date` AS
SELECT
  CAST(FORMAT_DATE('%Y%m%d', calendar_date) AS INT64) AS date_key,
  calendar_date,
  EXTRACT(YEAR FROM calendar_date) AS calendar_year,
  EXTRACT(MONTH FROM calendar_date) AS calendar_month,
  EXTRACT(MONTH FROM calendar_date) IN (11, 12, 1, 2, 3)
    AS is_winter_month
FROM UNNEST(GENERATE_DATE_ARRAY(
  DATE '2025-01-01', DATE '2025-12-31'
)) AS calendar_date;

-- 05. Build daily fact
CREATE OR REPLACE TABLE `data732.weather_curated.fact_station_daily_weather`
PARTITION BY calendar_date
CLUSTER BY station_key AS
SELECT
  s.station_key,
  d.date_key,
  d.calendar_date,
  w.tmin_f,
  w.snow_mm,
  w.trace_snow,
  w.tmin_f IS NOT NULL AS has_valid_tmin,
  w.snow_mm IS NOT NULL AS has_valid_snow
FROM `data732.weather_curated.dim_station` AS s
CROSS JOIN `data732.weather_curated.dim_date` AS d
LEFT JOIN `data732.weather_curated.curated_station_day` AS w
  ON s.station_id = w.id
  AND d.calendar_date = w.date;

-- 06. Check Curated counts
SELECT
  (SELECT COUNT(*) FROM `data732.weather_curated.curated_station_day`)
    AS curated_source_station_days,
  (SELECT COUNT(*) FROM `data732.weather_curated.selected_stations`)
    AS selected_stations,
  (SELECT COUNT(*) FROM `data732.weather_curated.dim_station`)
    AS station_dimension_rows,
  (SELECT COUNT(*) FROM `data732.weather_curated.dim_date`)
    AS date_dimension_rows,
  COUNT(*) AS fact_rows,
  COUNTIF(has_valid_tmin AND has_valid_snow) AS paired_days,
  COUNTIF(has_valid_tmin AND NOT has_valid_snow) AS tmin_only_days,
  COUNTIF(NOT has_valid_tmin AND has_valid_snow) AS snow_only_days,
  COUNTIF(NOT has_valid_tmin AND NOT has_valid_snow) AS missing_both_days
FROM `data732.weather_curated.fact_station_daily_weather`;
