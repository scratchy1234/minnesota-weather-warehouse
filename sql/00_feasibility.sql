-- 01. Basic table schemas
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable
FROM `bigquery-public-data.ghcn_d.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name IN ('ghcnd_stations', 'ghcnd_2025')
ORDER BY table_name, ordinal_position;

-- 02. Full-table metadata counts
SELECT
  table_id AS table_name,
  row_count,
  TIMESTAMP_MILLIS(last_modified_time) AS last_modified_time
FROM `bigquery-public-data.ghcn_d.__TABLES__`
WHERE table_id IN ('ghcnd_stations', 'ghcnd_2025')
ORDER BY table_id;

-- 03. Minnesota station count and missing coordinates
SELECT
  COUNT(*) AS station_rows,
  COUNT(DISTINCT id) AS distinct_stations,
  COUNTIF(latitude IS NULL OR longitude IS NULL) AS missing_coordinates
FROM `bigquery-public-data.ghcn_d.ghcnd_stations`
WHERE state = 'MN';

-- 04. Minnesota weather observation counts, dates, and value quality
SELECT
  w.element,
  COUNT(*) AS observation_count,
  COUNT(DISTINCT w.id) AS reporting_stations,
  MIN(w.date) AS earliest_date,
  MAX(w.date) AS latest_date,
  COUNTIF(w.value IS NULL) AS missing_values,
  COUNTIF(NULLIF(TRIM(w.qflag), '') IS NOT NULL) AS quality_flagged_rows
FROM `bigquery-public-data.ghcn_d.ghcnd_2025` AS w
JOIN `bigquery-public-data.ghcn_d.ghcnd_stations` AS s
  ON w.id = s.id
WHERE s.state = 'MN'
  AND w.date >= DATE '2025-01-01'
  AND w.date < DATE '2026-01-01'
  AND w.element IN ('TMIN', 'SNOW', 'SNWD')
GROUP BY w.element
ORDER BY w.element;

-- 05. Paired TMIN and SNOW observations
WITH station_days AS (
  SELECT
    w.id,
    w.date,
    COUNTIF(w.element = 'TMIN') AS tmin_rows,
    COUNTIF(w.element = 'SNOW') AS snow_rows
  FROM `bigquery-public-data.ghcn_d.ghcnd_2025` AS w
  JOIN `bigquery-public-data.ghcn_d.ghcnd_stations` AS s
    ON w.id = s.id
  WHERE s.state = 'MN'
    AND w.date >= DATE '2025-01-01'
    AND w.date < DATE '2026-01-01'
    AND w.element IN ('TMIN', 'SNOW')
  GROUP BY w.id, w.date
)
SELECT
  COUNTIF(tmin_rows > 0 AND snow_rows > 0) AS paired_station_days,
  COUNT(DISTINCT IF(tmin_rows > 0 AND snow_rows > 0, id, NULL))
    AS stations_with_paired_days,
  COUNTIF(tmin_rows > 1 OR snow_rows > 1) AS station_days_with_duplicates
FROM station_days;
