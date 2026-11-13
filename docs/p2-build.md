## 1. Establish the input and run ingestion

My project is for facilities operations managers who compare winter weather across Minnesota locations. I want to know how often selected stations record extreme cold (TMIN ≤ -20°F) and how often it occurs with measurable snowfall.

In P2, I built the Raw and Curated tables for these questions. I will build Serving in P3.

I used my BigQuery project `data732` in the `US` location, with the datasets `weather_raw` and `weather_curated`. My source was NOAA GHCN-Daily:

- `bigquery-public-data.ghcn_d.ghcnd_2025`, which includes TMIN and SNOW observations from January 1 to December 31, 2025.
- `bigquery-public-data.ghcn_d.ghcnd_stations`, which represents station information, filtered to `state = 'MN'`.

I ran [02_ingest.sql](../sql/02_ingest.sql) to create `raw_weather_2025` and `raw_stations`. One Raw weather row represents one station, date, and element. I kept the source values and quality flags, and added `loaded_at` to record when the data were copied.

| Raw result         | November 7, 2026 |
| ------------------ | ---------------: |
| Minnesota stations |            2,945 |
| TMIN rows          |           59,729 |
| SNOW rows          |          271,567 |
| Total weather rows |          331,296 |

I compared Raw with the current NOAA source and found zero row-count differences for TMIN and SNOW. All 2,945 station IDs were unique.

P0 had 331,368 weather rows, and P1 had 331,435, an increase of 67. P2 had 331,296 rows, which is 139 fewer than P1. I checked the earlier BigQuery job history and found source queries and temporary tables for P0 and P1, but no permanent source snapshot in the jobs I reviewed. I still cannot confirm which records changed. I saved a separate copy of the November 7 P2 Raw data as `data732.weather_raw.raw_weather_2025_p2_backup` for comparison in P3.

## 2. Build Curated at the intended grain

I ran [03_curate.sql](../sql/03_curate.sql) to combine TMIN and SNOW into station-day rows. Then, I excluded values with a nonblank `qflag`, a NULL value, or `-9999`. Missing readings remain NULL, not zero. I also converted TMIN from tenths of degrees Celsius to Fahrenheit, kept SNOW in millimeters, and recorded trace snowfall separately.

The 331,296 Raw weather rows became 290,077 station-day rows. I then used the P1 coverage rule: at least 300 valid paired days in 2025, including 72 in January–March and 49 in November–December. This selected 85 stations.

The fact grain is **one selected station per calendar day**, identified by `station_key` and `date_key`. The station dimension has 85 rows and the date dimension has 365 rows. I also kept calendar days without valid readings so missing data remain visible.

| Curated result      |   Rows |
| ------------------- | -----: |
| Fact station-days   | 31,025 |
| Valid TMIN and SNOW | 30,285 |
| TMIN only           |    233 |
| SNOW only           |    338 |
| Neither measurement |    169 |

These groups total 31,025 rows, or 85 stations × 365 days.

For the field trace, NOAA TMIN `value` and `qflag` were copied into Raw. Curated keeps valid TMIN and calculates `tmin_f = (value / 10) * 9 / 5 + 32`. The field is stored in `fact_station_daily_weather` and will support the P3 cold summary. For the selected stations, both Raw and Fact had 534 extreme-cold days.

## 3. Run and interpret two acceptance checks

I ran two acceptance checks using [04_acceptance.sql](../sql/04_acceptance.sql) after building Curated on November 7.

| Risk and affected result                                       | Check code                   | Expected result and why                                                                | Observed result                                                                | Interpretation or action                          |
| -------------------------------------------------------------- | ---------------------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------- |
| Duplicate or missing keys could affect daily counts and joins. | Query 1, `04_acceptance.sql` | No duplicate, missing, or unmatched keys; 31,025 fact rows for 85 stations × 365 days. | All key errors = 0; 31,025 fact rows.                                          | Passed. The fact grain and joins matched my plan. |
| Curation could change TMIN or extreme-cold counts.             | Query 2, `04_acceptance.sql` | Raw and Fact should match by station and month, with zero differences.                 | 1,020 groups; 0 mismatches. Both had 30,518 valid TMIN days and 534 cold days. | Passed. The main cold counts were preserved.      |

I also checked how missing SNOW affects the result. All valid TMIN days gave 534 extreme-cold days, but paired TMIN and SNOW days gave 531. Requiring both measurements would exclude 3 valid cold days. Therefore, I will use all valid TMIN days for the main cold question and paired days for the cold-and-snow question, which had 48 days.

Both checks passed, but they do not prove that every NOAA observation is correct. If a future check fails, I will investigate before using the results.

## 4. Make the run reproducible and record the next step

I ran the SQL in this order in BigQuery (`data732`, location `US`):

1. [02_ingest.sql](../sql/02_ingest.sql) — creates the datasets and replaces both Raw tables.
2. [03_curate.sql](../sql/03_curate.sql) — replaces the Curated tables, dimensions, and fact.
3. [04_acceptance.sql](../sql/04_acceptance.sql) — checks the results without changing data.

The scripts need access to the public NOAA tables and permission to create tables in `data732`. I saved the P2 weather Raw backup before any further reload, because `02_ingest.sql` replaces the Raw tables. I will keep that backup for the P3 source comparison.

These results describe weather stations, not individual facilities. In P3, I will build Serving, check its counts against Curated, and test reruns and the -20°F and -15°F cold definitions. I will also compare the P2 Raw backup with NOAA to see whether new source changes affect the selected stations and results.

I used ChatGPT to help draft the plan and the SQL. I ran the queries in BigQuery and checked the results myself.
