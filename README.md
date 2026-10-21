# Minnesota Winter Weather Operations Analytics

SEIS 732 — Data Warehousing

This project uses NOAA historical weather data to analyze extreme cold and snowfall across selected Minnesota weather stations. The goal is to develop a BigQuery data warehouse and dashboard to support winter preparation and maintenance planning for facilities operations managers responsible for multiple locations across Minnesota.

P0 checked whether the source could support the project. In P1, I define the daily weather model, check the observations, and plan the warehouse build.

## P0 Files

- [Feasibility Report](docs/p0-feasibility.md)
- [BigQuery SQL](sql/00_feasibility.sql)
- [Query Results](evidence/p0-feasibility-results.md)

## P1 Files

- [P1 Plan](docs/p1-plan.md)
- [Model Diagram](docs/model.png)
- [BigQuery SQL](sql/01_source_profile.sql)

P1 is a draft for M07 peer review. I will add the feedback to the plan after the discussion.

## Data Source

NOAA GHCN-Daily (`bigquery-public-data.ghcn_d`)
Candidate tables: `ghcnd_2025`, `ghcnd_stations`

Source: [NOAA GHCN-Daily Documentation](https://www.ncei.noaa.gov/pub/data/ghcn/daily/readme.txt)
