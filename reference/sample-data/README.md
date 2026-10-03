# Sample trip data

Small (1000-row) sample of NYC Yellow Taxi Jan 2026 data.

**File:** `yellow_tripdata_2026-01_sample.csv`

**Source:** https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2026-01.parquet (first 1000 rows, 19 assignment columns, headerless — same layout as HDFS `/raw`)

**Note:** TLC Parquet files from 2026 onward include an extra `cbd_congestion_fee` field. `parquet_to_csv.py` drops it so Pig / MapReduce keep the original 19-field CSV schema.
