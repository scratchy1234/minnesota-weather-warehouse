-- 01. Check fact keys and dimension relationships
WITH fact_keys AS (
  SELECT station_key, date_key, COUNT(*) AS row_count
  FROM `data732.weather_curated.fact_station_daily_weather`
  GROUP BY station_key, date_key
),
relationships AS (
  SELECT
    COUNTIF(s.station_key IS NULL) AS unmatched_station_keys,
    COUNTIF(d.date_key IS NULL) AS unmatched_date_keys
  FROM `data732.weather_curated.fact_station_daily_weather` AS f
  LEFT JOIN `data732.weather_curated.dim_station` AS s
    ON f.station_key = s.station_key
  LEFT JOIN `data732.weather_curated.dim_date` AS d
    ON f.date_key = d.date_key
)
SELECT
  (SELECT COUNTIF(row_count > 1) FROM fact_keys)
    AS duplicate_fact_keys,
  (SELECT COUNTIF(station_key IS NULL OR date_key IS NULL)
   FROM `data732.weather_curated.fact_station_daily_weather`)
    AS missing_fact_keys,
  (SELECT COUNT(*) - COUNT(DISTINCT station_key)
   FROM `data732.weather_curated.dim_station`)
    AS duplicate_station_dimension_keys,
  (SELECT COUNT(*) - COUNT(DISTINCT date_key)
   FROM `data732.weather_curated.dim_date`)
    AS duplicate_date_dimension_keys,
  (SELECT COUNT(*) FROM `data732.weather_curated.fact_station_daily_weather`)
    AS fact_rows,
  (SELECT COUNT(*) FROM `data732.weather_curated.dim_station`)
    * (SELECT COUNT(*) FROM `data732.weather_curated.dim_date`)
    AS expected_fact_rows,
  unmatched_station_keys,
  unmatched_date_keys
FROM relationships;

-- 02. Compare Raw and Fact counts by station and month
WITH raw_daily_tmin AS (
  SELECT
    id,
    date,
    MAX(IF(NULLIF(TRIM(qflag), '') IS NULL
      AND value IS NOT NULL AND value != -9999,
      (value / 10.0) * 9.0 / 5.0 + 32.0, NULL)) AS tmin_f
  FROM `data732.weather_raw.raw_weather_2025`
  WHERE element = 'TMIN'
  GROUP BY id, date
),
raw_monthly AS (
  SELECT
    s.station_key,
    DATE_TRUNC(r.date, MONTH) AS month_start,
    COUNTIF(r.tmin_f IS NOT NULL) AS valid_tmin_days,
    COUNTIF(r.tmin_f <= -20) AS extreme_cold_days
  FROM raw_daily_tmin AS r
  JOIN `data732.weather_curated.dim_station` AS s
    ON r.id = s.station_id
  GROUP BY s.station_key, month_start
),
fact_monthly AS (
  SELECT
    station_key,
    DATE_TRUNC(calendar_date, MONTH) AS month_start,
    COUNTIF(has_valid_tmin) AS valid_tmin_days,
    COUNTIF(has_valid_tmin AND tmin_f <= -20) AS extreme_cold_days
  FROM `data732.weather_curated.fact_station_daily_weather`
  GROUP BY station_key, month_start
)
SELECT
  COUNT(*) AS station_month_groups_compared,
  COUNTIF(COALESCE(r.valid_tmin_days, 0) != COALESCE(f.valid_tmin_days, 0)
    OR COALESCE(r.extreme_cold_days, 0) != COALESCE(f.extreme_cold_days, 0))
    AS mismatched_station_month_groups,
  SUM(COALESCE(r.valid_tmin_days, 0)) AS raw_valid_tmin_days,
  SUM(COALESCE(f.valid_tmin_days, 0)) AS fact_valid_tmin_days,
  SUM(COALESCE(r.extreme_cold_days, 0)) AS raw_cold_days,
  SUM(COALESCE(f.extreme_cold_days, 0)) AS fact_cold_days
FROM raw_monthly AS r
FULL OUTER JOIN fact_monthly AS f
  USING (station_key, month_start);

-- 03. Check cold days lost when SNOW is required
SELECT
  COUNTIF(has_valid_tmin) AS all_valid_tmin_days,
  COUNTIF(has_valid_tmin AND tmin_f <= -20) AS cold_all_tmin_days,
  COUNTIF(has_valid_tmin AND has_valid_snow) AS paired_days,
  COUNTIF(has_valid_tmin AND has_valid_snow AND tmin_f <= -20)
    AS cold_paired_days,
  COUNTIF(has_valid_tmin AND NOT has_valid_snow AND tmin_f <= -20)
    AS cold_days_lost_with_paired_filter,
  COUNTIF(has_valid_tmin AND has_valid_snow
    AND snow_mm > 0 AND trace_snow = 0 AND tmin_f <= -20)
    AS cold_and_measurable_snow_days
FROM `data732.weather_curated.fact_station_daily_weather`;
