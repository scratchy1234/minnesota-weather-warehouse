# Minnesota Winter Weather Operations Analytics

SEIS 732 — Data Warehousing

This project uses NOAA historical weather data to analyze extreme cold and snowfall across selected Minnesota weather stations. The goal is to develop a BigQuery data warehouse and dashboard to support winter preparation and maintenance planning for facilities operations managers responsible for multiple locations across Minnesota.

The P0 milestone focuses on evaluating the feasibility of the proposed project.

## P0 Files

- [Feasibility Report](docs/p0-feasibility.md)
- [BigQuery SQL](sql/00_feasibility.sql)
- [Query Results](evidence/p0-feasibility-results.md)

## Data Source

NOAA GHCN-Daily (`bigquery-public-data.ghcn_d`)
Candidate tables: `ghcnd_2025`, `ghcnd_stations`

Source: [NOAA GHCN-Daily Documentation](https://www.ncei.noaa.gov/pub/data/ghcn/daily/readme.txt)