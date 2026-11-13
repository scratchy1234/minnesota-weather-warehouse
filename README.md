# Minnesota Winter Weather Operations Analytics

SEIS 732 — Data Warehousing

This project uses NOAA weather data to compare extreme cold and snowfall across selected Minnesota stations. I plan to use a BigQuery data warehouse and dashboard to support winter preparation and maintenance planning for facilities operations managers.

P0 checked the source and project feasibility. P1 defined the daily weather model and planned the warehouse. In P2, I built the Raw and Curated tables and checked the results. I will build Serving in P3.

## P0 Files

- [Feasibility Report](docs/p0-feasibility.md)
- [BigQuery SQL](sql/00_feasibility.sql)
- [Query Results](evidence/p0-feasibility-results.md)

## P1 Files

- [P1 Plan](docs/p1-plan.md)
- [Model Diagram](docs/model.png)
- [BigQuery SQL](sql/01_source_profile.sql)

## P2 Files

- [P2 Build](docs/p2-build.md)
- [Ingestion SQL](sql/02_ingest.sql)
- [Curation SQL](sql/03_curate.sql)
- [Acceptance SQL](sql/04_acceptance.sql)

## Data Source

NOAA GHCN-Daily (`bigquery-public-data.ghcn_d`)

Source tables: `ghcnd_2025`, `ghcnd_stations`

[NOAA GHCN-Daily Documentation](https://www.ncei.noaa.gov/pub/data/ghcn/daily/readme.txt)
