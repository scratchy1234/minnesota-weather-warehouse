## 1. Working title

Minnesota Winter Weather Operations Analytics

## 2. Audience and need

My target audience is facilities operations managers who are responsible for multiple locations across Minnesota. Snowfall and very cold temperatures can create different maintenance problems across regions. So I want to use historical weather data to help them understand which areas experience more frequent winter weather conditions. If the product is useful, managers could compare weather patterns across locations and use the results to support their seasonal preparation and maintenance planning.

## 3. Proposed analytical product and questions

I plan to build a BigQuery data warehouse and a dashboard using NOAA weather observations. The analysis will focus on selected Minnesota weather stations with sufficient temperature and snowfall records in 2025.

The dashboard will answer three questions:

1. How often do selected Minnesota stations experience extreme cold days?
2. How do snowfall frequency and recorded snowfall amounts differ across these stations?
3. How often are extreme cold and snowfall recorded on the same day at the same station?

I will use a consistent set of stations where possible and account for differences in data coverage. I also need to define an extreme cold threshold and check how missing or flagged weather records should be handled before making comparisons.

## 4. Source identification and access

My data source is NOAA's Global Historical Climatology Network Daily (GHCN-Daily), which is available in BigQuery as bigquery-public-data.ghcn_d. I plan to use two tables: ghcnd_2025 for weather observations and ghcnd_stations for station information.

I confirmed that the dataset is located in the US region and that I can access both tables through my course project, data732. I also found yearly tables from 2020 to 2026, but I am starting with 2025 data to keep the project manageable. The dataset is publicly available under the linked source terms.

Source references:

- [NOAA GHCN-Daily technical documentation](https://www.ncei.noaa.gov/pub/data/ghcn/daily/readme.txt)
- [NOAA dataset metadata](https://www.ncei.noaa.gov/access/metadata/landing-page/bin/iso?id=gov.noaa.ncdc:C00861)
- [BigQuery dataset listing](https://console.cloud.google.com/marketplace/details/noaa-public/ghcn-d)

## 5. Quick source profile

The `ghcnd_stations` table contains station information, while `ghcnd_2025` contains daily weather observations by station, date, and element. The main fields are `id` (STRING), `date` (DATE), `element` (STRING), and `value` (FLOAT64). The station table also provides location information. A possible observation key is the combination of `id`, `date`, and `element`.

Based on BigQuery metadata checked on October 8, 2026, `ghcnd_2025` contains 36,350,184 rows, and `ghcnd_stations` contains 133,039 rows. I found 2,945 distinct Minnesota stations with no missing coordinates.

For Minnesota in 2025:

| Element | Observations | Reporting Stations |
|---|---:|---:|
| TMIN (Minimum Temperature) | 59,807 | 176 |
| SNOW (Snowfall) | 271,561 | 1,698 |
| SNWD (Snow Depth) | 81,483 | 748 |

All three elements have records spanning January 1 to December 31, 2025. I also found 41,219 station-days with both TMIN and SNOW observations across 129 stations.

I found no SQL NULL values in the `value` field for the three tested elements, and no duplicate TMIN/SNOW station-day records in the tested data. However, 220 observations had quality flags, so some data coverage and measurement details still need to be checked later.

The dataset description states that it is updated daily. Since these are weather station observations, they cannot directly measure conditions at individual facilities.

The SQL and results are documented in [00_feasibility.sql](../sql/00_feasibility.sql) and [p0-feasibility-results.md](../evidence/p0-feasibility-results.md).

## 6. Need-to-source fit

| Proposed Question | Needed Fields | Source Objects | Why It Is Sufficient | What to Check in P1 |
|---|---|---|---|---|
| 1. How often do selected Minnesota stations experience extreme cold days? | `id`, `date`, `element`, `value`, station location | `ghcnd_2025`, `ghcnd_stations` | 59,807 TMIN observations from 176 Minnesota stations | Cold threshold, temperature units, and data coverage |
| 2. How do snowfall frequency and recorded snowfall amounts differ across these stations? | `id`, `date`, `element`, `value`, station location | `ghcnd_2025`, `ghcnd_stations` | 271,561 SNOW observations from 1,698 Minnesota stations | Missing records, quality flags, and valid snowfall values |
| 3. How often are extreme cold and snowfall recorded on the same day at the same station? | `id`, `date`, `element`, `value` | `ghcnd_2025` | 41,219 paired station-days across 129 stations | Paired data coverage after cleaning |

## 7. Feasibility risks and response

1. **Uneven data coverage:** Some stations have more observations than others. So, I will set a minimum data coverage requirement before comparing stations.

2. **Data quality:** I found 220 observations with quality flags in the tested data. So, I will check the flag meanings, measurement units, and missing-value rules before calculating the final results.

If the temperature and snowfall data cannot support reliable comparisons, I will narrow the project to snowfall patterns at selected Minnesota stations.

## 8. First P1 decision

My first decision in P1 will be the grain of the main weather fact table. I plan to evaluate whether one row per station per day, with temperature and snowfall as separate fields, can support all three analytical questions.

## 9. AI/tool accountability

I used ChatGPT to help develop the project idea, prepare BigQuery queries, and revise the report. I ran the queries myself in BigQuery and checked the results before including them in the report. I also referred to NOAA documentation to better understand the data fields and their limitations.
