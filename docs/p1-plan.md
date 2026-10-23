## 1. Establish the question and check the source

My audience is facilities operations managers who are responsible for multiple locations across Minnesota. In P0, I proposed a dashboard to help them compare winter weather conditions for seasonal planning. My main question is how often selected stations record extreme cold and how often it occurs with measurable snowfall.

To check the source, I queried NOAA GHCN-Daily tables (`bigquery-public-data.ghcn_d.ghcnd_2025` and `bigquery-public-data.ghcn_d.ghcnd_stations`) using my `data732` project. Since each source row represents one station, date, and weather element, I plan to combine TMIN and SNOW into one station-day fact.

| Source check | P0 | P1 |
|---|---:|---:|
| TMIN/SNOW rows | 331,368 | 331,435 |
| Station-day groups | 290,149 | 290,216 |
| Repeated station-day groups | 41,219 | 41,219 |
| Duplicate element days | 0 | 0 |
| Missing IDs / dates | Not checked | 0 |

The repeated station-day groups are expected because TMIN and SNOW are recorded separately. Compared with P0, the source has 67 more rows, although I have not confirmed why. In addition, I also checked the measurement rules. NOAA records TMIN in tenths of degrees Celsius and SNOW in millimeters. In the dataset of NOAA, I found 60 flagged TMIN and 51 flagged SNOW observations. Therefore, I will exclude flagged values, keep trace snowfall separate, and leave missing values as NULL.

For consistent comparisons, I defined extreme cold as **TMIN ≤ -20°F** and required at least 300 valid paired days, including 72 in January–March and 49 in November–December, which left 85 stations. Also, I found 534 extreme cold station-days out of 30,518 valid TMIN days. Among 30,285 paired days, 48 had both extreme cold and measurable snowfall. These results represent station observations, not actual facility conditions. The SQL checks are in [01_source_profile.sql](../sql/01_source_profile.sql).

## 2. Define the model and predict a history consequence

For my warehouse, I plan to use fact_station_daily_weather as a periodic snapshot, with one row per selected station per day. It connects to dim_station and dim_date through station_key and date_key. The fact stores minimum temperature, snowfall, and observation flags, while the dimensions provide station and calendar information. This allows me to compare extreme cold and snowfall using the same daily records.

The model is shown in [model.png](model.png).

To test the model, I created a daily row for each of the 85 stations in 2025, which produced 31,025 fact rows with no repeated keys. Since some days have missing observations, I will keep them as NULL instead of zero. At the station-day grain, I will count extreme cold using all days with valid TMIN, even if snowfall is missing. For the combined cold-and-snowfall question, I will only use days with both valid measurements.

One possible history issue is a change in the extreme-cold definition. I compared **-20°F (V1)** with **-15°F (V2)** using the same 30,285 paired days. The count increased from 531 to 976, a difference of 445. The V1 count here is 531 instead of 534 because this comparison only uses paired observations. Therefore, I plan to keep the original measurements in Raw and the threshold versions in Serving so past results can still be reproduced. For station information, I will use Type 1 for corrections. In P3, I will test that adding V2 does not change the V1 result.

## 3. Plan the build and its checks

I plan to build my warehouse in three layers: Raw, Curated, and Serving. Raw will keep the original NOAA records, while Curated will clean the data and build the daily fact and dimensions. Finally, Serving will provide the weather summaries and keep the different threshold definitions.

| Layer | Planned objects |
|---|---|
| Raw | `raw_weather_2025`, `raw_stations` |
| Curated | `curated_station_day`, `dim_station`, `dim_date`, `fact_station_daily_weather` |
| Serving | `ref_cold_definition`, `serving_station_cold_summary` |

I will first load the source data into Raw, then build the daily fact and dimensions in Curated, and finally create the Serving summaries.

To make sure the pipeline works correctly, I will compare source row counts and check for duplicate fact keys and unmatched dimension keys in Curated. I expect zero duplicates and unmatched keys. I will also compare extreme-cold counts between Curated and Serving by station and month, using the same V1 definition. I expect no differences between the results. For example, TMIN will move from its original NOAA value to fact_station_daily_weather.tmin_f and then to the cold-day summary. In addition, I will check that introducing V2 does not change the original V1 result.

The data are public, but the results only represent weather station observations rather than actual facility conditions. I will be the project owner and data steward for this course project. I will keep raw data exports and credentials out of GitHub. For P2, my first step will be to load the 2025 Minnesota data into Raw and verify the row counts.

## 4. Diagnose and revise the plan

### P1 change memo

- **Feedback that changed my plan:**

  My peer suggested that I clarify the metric definitions, make the quality checks more specific, and identify who owns the project.

- **What I changed and why:**

  I explained the different denominators for extreme cold and cold with snowfall. I also added planned checks for duplicate keys, unmatched keys, and Curated-to-Serving counts. Besides, I identified myself as the project owner and data steward.

- **Feedback I did not adopt and why:**

  I did not add detailed failure-handling procedures or separate metadata tables in P1. I plan to address them in P2 or P3 after building the pipeline.

- **Most important remaining uncertainty:**

  I still need to investigate the 67-row difference between P0 and P1 and how future NOAA updates could affect historical results.

### AI/tool accountability

I used ChatGPT to generate the model diagram.
