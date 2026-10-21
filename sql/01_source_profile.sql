-- 01. Check missing station IDs and dates
SELECT
  COUNTIF(id IS NULL) AS missing_station_ids,
  COUNTIF(date IS NULL) AS missing_dates
FROM `bigquery-public-data.ghcn_d.ghcnd_2025`
WHERE element IN ('TMIN', 'SNOW');

-- 02. Count Minnesota records and check repeated station-days
CREATE TEMP TABLE mn_weather AS
SELECT
  w.id,
  w.date,
  w.element,
  w.value,
  w.qflag,
  w.mflag
FROM `bigquery-public-data.ghcn_d.ghcnd_2025` AS w
JOIN `bigquery-public-data.ghcn_d.ghcnd_stations` AS s
  ON w.id = s.id
WHERE s.state = 'MN'
  AND w.date >= DATE '2025-01-01'
  AND w.date < DATE '2026-01-01'
  AND w.element IN ('TMIN', 'SNOW');

WITH station_days AS (
  SELECT
    id,
    date,
    COUNT(*) AS observation_rows,
    COUNTIF(element = 'TMIN') AS tmin_rows,
    COUNTIF(element = 'SNOW') AS snow_rows
  FROM mn_weather
  GROUP BY id, date
)
SELECT
  SUM(observation_rows) AS source_rows,
  COUNT(*) AS station_day_groups,
  COUNTIF(observation_rows > 1) AS repeated_station_days,
  COUNTIF(tmin_rows > 1 OR snow_rows > 1) AS duplicate_element_days,
  COUNTIF(tmin_rows > 0 AND snow_rows > 0) AS paired_source_days
FROM station_days;

-- 03. Check quality flags, missing values, and trace snow
SELECT
  element,
  COUNT(*) AS observation_count,
  COUNTIF(NULLIF(TRIM(qflag), '') IS NOT NULL) AS quality_flagged_rows,
  COUNTIF(value IS NULL OR value = -9999) AS missing_values,
  COUNTIF(TRIM(mflag) = 'T') AS trace_rows
FROM mn_weather
GROUP BY element
ORDER BY element;

-- 04. Combine daily observations and check station coverage
CREATE TEMP TABLE station_days AS
SELECT
  id,
  date,
  MAX(IF(element = 'TMIN', value, NULL)) AS tmin_raw,
  MAX(IF(element = 'SNOW', value, NULL)) AS snow_mm,
  MAX(IF(element = 'SNOW', IF(TRIM(mflag) = 'T', 1, 0), NULL)) AS trace_snow
FROM mn_weather
WHERE NULLIF(TRIM(qflag), '') IS NULL
  AND value IS NOT NULL
  AND value != -9999
GROUP BY id, date;

CREATE TEMP TABLE station_coverage AS
SELECT
  id,
  COUNTIF(tmin_raw IS NOT NULL AND snow_mm IS NOT NULL) AS paired_year,
  COUNTIF(tmin_raw IS NOT NULL AND snow_mm IS NOT NULL
    AND date BETWEEN DATE '2025-01-01' AND DATE '2025-03-31') AS paired_jan_mar,
  COUNTIF(tmin_raw IS NOT NULL AND snow_mm IS NOT NULL
    AND date BETWEEN DATE '2025-11-01' AND DATE '2025-12-31') AS paired_nov_dec
FROM station_days
GROUP BY id;

SELECT
  COUNTIF(paired_year >= 300) AS stations_with_300_days,
  COUNTIF(paired_year >= 300
    AND paired_jan_mar >= 72
    AND paired_nov_dec >= 49) AS selected_stations
FROM station_coverage;

-- 05. Build the daily fact and check missing days
CREATE TEMP TABLE selected_stations AS
SELECT id
FROM station_coverage
WHERE paired_year >= 300
  AND paired_jan_mar >= 72
  AND paired_nov_dec >= 49;

CREATE TEMP TABLE fact_days AS
SELECT
  s.id,
  calendar_date,
  d.tmin_raw,
  d.snow_mm,
  d.trace_snow,
  d.tmin_raw IS NOT NULL AS has_valid_tmin,
  d.snow_mm IS NOT NULL AS has_valid_snow
FROM selected_stations AS s
CROSS JOIN UNNEST(
  GENERATE_DATE_ARRAY(DATE '2025-01-01', DATE '2025-12-31')
) AS calendar_date
LEFT JOIN station_days AS d
  ON s.id = d.id AND calendar_date = d.date;

SELECT
  COUNT(*) AS planned_fact_rows,
  COUNTIF(has_valid_tmin AND has_valid_snow) AS paired_days,
  COUNTIF(has_valid_tmin AND NOT has_valid_snow) AS tmin_only_days,
  COUNTIF(NOT has_valid_tmin AND has_valid_snow) AS snow_only_days,
  COUNTIF(NOT has_valid_tmin AND NOT has_valid_snow) AS missing_both_days,
  COUNTIF(id IS NULL OR calendar_date IS NULL) AS missing_fact_keys,
  (SELECT COUNTIF(rows_per_key > 1)
   FROM (
     SELECT id, calendar_date, COUNT(*) AS rows_per_key
     FROM fact_days
     GROUP BY id, calendar_date
   )) AS repeated_fact_keys
FROM fact_days;

-- 06. Count cold and snow days and compare two thresholds
WITH weather AS (
  SELECT
    id,
    has_valid_tmin,
    has_valid_snow,
    snow_mm,
    trace_snow,
    (tmin_raw / 10.0) * 9.0 / 5.0 + 32.0 AS tmin_f
  FROM fact_days
)
SELECT
  COUNTIF(has_valid_tmin) AS valid_tmin_days,
  COUNTIF(has_valid_tmin AND tmin_f <= -20) AS cold_all_tmin_days,
  COUNTIF(has_valid_tmin AND NOT has_valid_snow AND tmin_f <= -20)
    AS cold_tmin_only_days,
  COUNTIF(has_valid_tmin AND has_valid_snow AND tmin_f <= -20)
    AS cold_paired_minus20f,
  COUNTIF(has_valid_tmin AND has_valid_snow AND tmin_f <= -15)
    AS cold_paired_minus15f,
  COUNTIF(has_valid_tmin AND has_valid_snow
    AND snow_mm > 0 AND trace_snow = 0) AS measurable_snow_days,
  COUNTIF(has_valid_tmin AND has_valid_snow
    AND snow_mm > 0 AND trace_snow = 0 AND tmin_f <= -20)
    AS cold_and_snow_days,
  COUNT(DISTINCT IF(has_valid_tmin AND has_valid_snow
    AND tmin_f > -20 AND tmin_f <= -15, id, NULL))
    AS stations_affected_by_change
FROM weather;
