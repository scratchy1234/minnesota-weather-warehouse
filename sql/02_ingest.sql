-- P2 source to Raw. Rerunning replaces the Raw snapshot.

-- 01. Create datasets
CREATE SCHEMA IF NOT EXISTS `data732.weather_raw`
OPTIONS(location = 'US');

CREATE SCHEMA IF NOT EXISTS `data732.weather_curated`
OPTIONS(location = 'US');

-- 02. Load Minnesota stations
CREATE OR REPLACE TABLE `data732.weather_raw.raw_stations` AS
SELECT
  id,
  state,
  name,
  latitude,
  longitude,
  elevation,
  CURRENT_TIMESTAMP() AS loaded_at
FROM `bigquery-public-data.ghcn_d.ghcnd_stations`
WHERE state = 'MN';

-- 03. Load 2025 TMIN and SNOW
CREATE OR REPLACE TABLE `data732.weather_raw.raw_weather_2025`
PARTITION BY date
CLUSTER BY id, element AS
SELECT
  id,
  date,
  element,
  value,
  mflag,
  qflag,
  CURRENT_TIMESTAMP() AS loaded_at
FROM `bigquery-public-data.ghcn_d.ghcnd_2025`
WHERE date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
  AND element IN ('TMIN', 'SNOW')
  AND id IN (
    SELECT id
    FROM `data732.weather_raw.raw_stations`
  );

-- 04. Check Raw counts and load time
SELECT
  (SELECT COUNT(*) FROM `data732.weather_raw.raw_stations`) AS raw_stations,
  (SELECT COUNT(*) FROM `data732.weather_raw.raw_weather_2025`) AS raw_weather_rows,
  (SELECT COUNTIF(element = 'TMIN')
   FROM `data732.weather_raw.raw_weather_2025`) AS tmin_rows,
  (SELECT COUNTIF(element = 'SNOW')
   FROM `data732.weather_raw.raw_weather_2025`) AS snow_rows,
  (SELECT MIN(loaded_at)
   FROM `data732.weather_raw.raw_weather_2025`) AS snapshot_loaded_at;
