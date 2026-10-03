# NYC TLC Yellow Taxi Trip Records – Data Dictionary

**Source:** NYC Taxi & Limousine Commission (TLC)
**Portal:** https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
**File pattern:** `yellow_tripdata_YYYY-MM.parquet` (monthly, Parquet)
**Direct base URL:** `https://d37ci6vzurychx.cloudfront.net/trip-data/`
**Licence:** Public domain (NYC Open Data)

## Volume for this assignment

| Month | Rows | Parquet | CSV (uncompressed, 19 cols) |
|---|---:|---:|---:|
| 2026-01 | 3,724,889 | ~61 MB | ~392 MB |
| 2026-02 | 3,399,866 | ~56 MB | ~358 MB |
| 2026-03 | 3,952,451 | ~65 MB | ~416 MB |
| **Total** | **11,077,206** | **~190 MB** | **~1.17 GB** |

Confirmed by downloading all three 2026 files (3 Oct 2026). CSV sizes estimated from Jan conversion ratio; re-run `download_and_ingest.sh` on your VM for exact `hdfs dfs -du` numbers.

## Trip records – 19 columns (ingest layout)

Our HDFS CSV files use these 19 columns (headerless). TLC may ship additional Parquet fields in newer years; see ingest note below.

| # | Column | Type | Notes |
|---:|---|---|---|
| 1 | `VendorID` | int32 | 1 = Creative Mobile Technologies · 2 = Curb Mobility · 6 = Myle · 7 = Helix |
| 2 | `tpep_pickup_datetime` | timestamp (us) | Trip start (local NYC time) |
| 3 | `tpep_dropoff_datetime` | timestamp (us) | Trip end |
| 4 | `passenger_count` | int64 | Reported by driver; can be null or 0 (bad data) |
| 5 | `trip_distance` | double | Miles |
| 6 | `RatecodeID` | int64 | 1 Standard · 2 JFK · 3 Newark · 4 Nassau/Westchester · 5 Negotiated · 6 Group ride · 99 Null/unknown |
| 7 | `store_and_fwd_flag` | string(1) | Y = trip cached before upload (no meter connection); N = normal |
| 8 | `PULocationID` | int32 | Pickup TLC taxi zone (joins to zone lookup) |
| 9 | `DOLocationID` | int32 | Drop-off TLC taxi zone |
| 10 | `payment_type` | int64 | 1 Credit card · 2 Cash · 3 No charge · 4 Dispute · 5 Unknown · 6 Voided |
| 11 | `fare_amount` | double | Metered fare (USD) |
| 12 | `extra` | double | Surcharges (rush hour, night) |
| 13 | `mta_tax` | double | $0.50 MTA tax |
| 14 | `tip_amount` | double | Card tips only (cash tips not recorded) |
| 15 | `tolls_amount` | double | Sum of tolls |
| 16 | `improvement_surcharge` | double | $0.30 flat |
| 17 | `total_amount` | double | Grand total (excludes cash tip) |
| 18 | `congestion_surcharge` | double | $2.50 for trips inside Manhattan below 96th St |
| 19 | `Airport_fee` | double | $1.75 for pickups at LGA/JFK |

### TLC-only field (not in our CSV)

| Column | Notes |
|---|---|
| `cbd_congestion_fee` | Present in 2026+ Yellow Parquet; omitted by `parquet_to_csv.py` so Pig/Hive/MapReduce scripts stay on the 19-column contract. |

## Zone lookup – 265 zones × 4 columns

File: `taxi_zone_lookup.csv` (12 KB) at `https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv`

| # | Column | Type | Notes |
|---:|---|---|---|
| 1 | `LocationID` | int | 1–265 (matches PULocationID / DOLocationID above) |
| 2 | `Borough` | string | Manhattan · Brooklyn · Queens · Bronx · Staten Island · EWR (Newark) · Unknown |
| 3 | `Zone` | string | Zone name (e.g. "JFK Airport", "Times Sq/Theatre District") |
| 4 | `service_zone` | string | Yellow Zone (Manhattan CBD) · Boro Zone · Airports · EWR |

**Airport zones we call out specially:**
- `LocationID = 132` → JFK Airport
- `LocationID = 138` → LaGuardia Airport
- `LocationID = 1`   → Newark (EWR)

## Known data-quality issues (documented for the report)

Real-world messiness — this is our "Veracity" story:

| Issue | Frequency | Handling in Pig ETL |
|---|---|---|
| `passenger_count = 0` or null | ~1–2% | Filter out |
| `trip_distance = 0` with non-zero fare | small | Filter out |
| `trip_distance > 100` miles (bogus long trip in NYC) | rare | Filter out |
| Negative `fare_amount` (refund records) | small | Filter out |
| `total_amount < 0` | small | Filter out |
| `RatecodeID = 99` (unknown) | small | Keep, flag as `unknown_rate` |
| Timestamps outside the file's month (data-entry error) | rare | Keep in raw, filter in Hive |
| Duplicate rows across months | very rare | Not treated (safe to leave) |

## Business questions we answer with this data

1. **Demand hotspots** — top-10 pickup zones × hour-of-day.
2. **Revenue analytics** — mean fare, mean tip %, revenue by borough and payment type.
3. **Congestion signal** — mean trip duration per PU→DO zone pair, by hour bucket.
4. **Airport trip profile** — JFK/LGA/EWR: trip volume, avg fare, avg tip %, top destinations.
5. **Payment behaviour** — card vs cash share by borough.

## References

- NYC TLC data page: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
- Trip record user guide (PDF): https://www.nyc.gov/assets/tlc/downloads/pdf/trip_record_user_guide.pdf
- Data dictionary (PDF): https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_yellow.pdf
- Zone map (PDF): https://www.nyc.gov/assets/tlc/downloads/pdf/taxi_zone_map_manhattan.pdf
