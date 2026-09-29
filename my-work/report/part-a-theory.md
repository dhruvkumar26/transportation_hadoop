# Part A — Theory Report

**Course:** CC ZG522 · Big Data Systems · First Semester 2026-27
**Assignment:** #1 · Big Data Systems Implementation & Analytics
**Domain:** Transportation
**Team:** Dhruv Kumar (Leader) · Manikandan B (Presenter) · Sai Krishna Mohan · Ramya K · Sri Lalithya · Vishwa Vajendra

---

## §1 · Introduction

### 1.1 Selected domain

**Transportation** — specifically urban ride-hail / taxi mobility in a dense metropolitan environment. Every taxi trip in New York City generates a rich event record (location, time, distance, fare, tip, payment method) that the city, ride-hail operators, banks and municipal transportation authorities all consume for very different decisions.

### 1.2 Background

New York City runs the world's oldest and one of the most heavily-instrumented taxi markets. The NYC Taxi & Limousine Commission (TLC) regulates ~13,500 medallion Yellow Taxis, ~4,000 Green Boro Taxis and ~80,000 For-Hire Vehicles (Uber/Lyft). Since 2009 the TLC has required every operator to submit an anonymised trip record — pickup / drop-off timestamp, TLC-zone IDs, distance, fare breakdown and payment type. The full archive now spans **17+ years and ~4 billion trips**, released monthly as columnar Parquet files.

This dataset is a canonical Big Data workload:

- **Real** — every row is an actual paid trip, not synthetic.
- **Large** — a single month is 3–4 million rows; a full year is 40 M+; the archive is billions.
- **Multi-consumer** — city planners study congestion; the TLC studies compliance and revenue leakage; ride-hail firms benchmark surge pricing; banks study cash-vs-card share; academic economists study labour markets.
- **Growing** — the same schema keeps producing new rows every day.

### 1.3 Business problem

Our team focuses on five concrete questions a mobility operator would ask its data platform every week:

| # | Business question | Decision driven |
|---|---|---|
| 1 | Which pickup zones are busiest at each hour of the day? | Driver-allocation / dispatch — where to position the fleet. |
| 2 | How does revenue (fare + tip) break down by borough and payment method? | Pricing strategy, cash-handling policy, operator revenue forecasting. |
| 3 | Which pickup → drop-off zone pairs are systematically slow (min per mile)? | Route optimisation, congestion-charge zone design, urban planning. |
| 4 | For each of the three airports (JFK, LGA, EWR), what is the trip profile — top destinations, average fare, tip percentage? | Airport partnership deals, targeted marketing, driver incentives. |
| 5 | What is the card-vs-cash split by borough? | Financial-services (POS terminal deployment), tax reporting, fraud detection. |

Answering these at production scale is the assignment's practical goal. Answering them **in a way that scales to billions of rows** is the assignment's *pedagogical* goal — this is why Big Data infrastructure exists.

---

## §2 · Big Data Need Analysis

### 2.1 Why Big Data — and why not a traditional RDBMS?

If the volume were 100,000 rows we would use Postgres, run a few `GROUP BY` queries and ship. The five questions above are *conceptually* simple. What makes this a Big Data problem is not the *complexity* of the queries but the interaction of the following properties:

| Property | Numbers we hit | Consequence |
|---|---|---|
| Bulk write, monthly | ~9 million rows / month (Jan+Feb+Mar 2024 = **9.55 M rows**, ~985 MB raw CSV) | Row-by-row INSERT into an RDBMS becomes I/O-bound; a bulk COPY works but locks the table. Batch pipelines with parallel writers are the natural fit. |
| Analytical scans, not point queries | Every business question scans **≥ 8.4 M rows** per run | An RDBMS optimises for OLTP index seeks; a scan over 8 M rows is a full-table scan. It works, but scaling up to 40 M/year or 4 B lifetime makes the same scan proportionally slower. |
| Aggregation with high-cardinality grouping | Q3 groups by (PU zone × DO zone × hour) = up to 265 × 265 × 24 ≈ 1.7 M distinct groups | Group cardinality is what saturates single-node sort buffers. Distributed shuffle across a cluster fans this out to N workers. |
| Denormalised, wide schema | Fact row has 19 fields; joining to zone dim = 19+4 fields | RDBMS row storage becomes disk-inefficient. Columnar stores (Parquet, ORC) skip unused columns and compress each column independently — often 5–10× less I/O. |
| Multi-tenant analytical workload | The same dataset feeds five different business questions | An RDBMS materialises full-scan results into memory; each query pays the full cost. Hive + HDFS lets multiple concurrent queries share the same underlying blocks, and each query runs on the same distributed workers. |
| Multi-source enrichment | Trip fact + zone dimension + (optional) weather feed | Traditional ETL tools stall as sources multiply; Hadoop's schema-on-read approach lets us keep raw files as-is and enrich in-place with Pig. |

**Bottom line:** a Postgres server *could* answer any single one of our five questions, but not all five simultaneously across multiple years while ingesting the next month's data — and not on commodity hardware. Big Data infrastructure is the fit.

### 2.2 The 5 Vs applied to our dataset

| V | Manifestation in this project | Concrete evidence |
|---|---|---|
| **Volume** | 3 months = **9.55 M records / 985 MB CSV / ~150 MB Parquet**. Extrapolated: 1 year ≈ 40 M rows / 4 GB CSV; 5 years ≈ 200 M rows / 20 GB. Real production archive: billions. | `hdfs dfs -du -h /raw` shows 984.9 MB across three monthly partitions. |
| **Velocity** | Data arrives as **monthly batches** in the public TLC portal. Our HDFS layout mirrors this — `/raw/trips/year=YYYY/month=MM/…`. In production, sub-hourly Kafka topics carry live meter events; our batch pipeline is a simplification of that pattern. | Partitioned HDFS directory tree; each new month adds a new directory without re-processing prior data. |
| **Variety** | Two structured sources with different granularities: trip **fact** (row-per-event, 19 columns) + zone **dimension** (row-per-lookup-key, 4 columns) + (optional) weather JSON. All joined in Pig / Hive. | Distinct HDFS paths for `/raw/trips/…` and `/raw/zone_lookup/…`; Pig `JOIN … BY` produces enriched `/clean/trips_enriched/`. |
| **Veracity** | Real messy data. Pig ETL dropped **11.25 %** of raw rows (9.55 M → 8.48 M) for data-quality violations: passenger_count = 0, zero-distance / >100 mile trips, negative fares, missing zone IDs. | `_counts/raw` = 9,554,778; `_counts/clean` = 8,479,421. Recorded in `03-run-pig-etl.md`. |
| **Value** | Five distinct business questions, each producing a queryable Hive table + interactive Streamlit visualization. Top-20 hotspots align with real NYC geography (Midtown Center zones 161/162 at 5–6 PM rush, JFK at 4 PM afternoon flights). | Streamlit dashboard at `:8501` renders all five as interactive charts. |

*(The extended-Vs schools of thought add **Variability** — same "trip" concept means different things across TLC/Uber/for-hire — and **Visualization** — the dashboard turns raw counts into decision-ready plots. Both are demonstrated in our pipeline.)*

### 2.3 Existing challenges we specifically addressed

- **Data quality at scale**: naïve `SELECT * FROM trips WHERE fare > 0` doesn't scale. Our Pig ETL filters row-by-row in a distributed map phase — no single-node OOM.
- **Schema drift**: TLC changes their schema every few years. Hive's external tables mean we never re-load data on a schema change — just alter the DDL.
- **Multi-source join complexity**: joining fact-to-dim in Postgres is trivial for millions of rows but painful past ~100 M. Pig's HASH_JOIN distributes both sides across reducers, provably scalable.
- **Analytical vs operational access**: a fleet dispatcher wants **sub-millisecond zone lookups**; a strategist wants **minute-long analytical scans**. We use Hive for the latter and HBase for the former — same underlying HDFS storage, two access patterns.

---

## §3 · Dataset Description

### 3.1 Source

| Attribute | Value |
|---|---|
| Publisher | New York City Taxi & Limousine Commission (TLC) |
| Portal | https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page |
| Base URL | `https://d37ci6vzurychx.cloudfront.net/trip-data/` |
| File pattern | `yellow_tripdata_YYYY-MM.parquet` |
| Format | Apache Parquet (columnar, snappy-compressed) |
| Licence | Public domain (NYC Open Data) |
| Zone lookup | `https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv` |

We selected **Yellow Taxi 2024 Jan / Feb / Mar** as the target window because:

1. It fits comfortably inside the 4 GB RAM constraint of our pseudo-cluster while staying credibly "big" (985 MB).
2. It's post-COVID normal, so counts reflect a mature ride-hail-dominated market.
3. Three months lets us show month-over-month trends without hitting disk pressure.

### 3.2 Volumes

| File | Rows | Parquet size | CSV size (after conversion) |
|---|---:|---:|---:|
| `yellow_tripdata_2024-01.parquet` | 2,964,624 | 48 MB | 307 MB |
| `yellow_tripdata_2024-02.parquet` | ~2,900,000 | 48 MB | 305 MB |
| `yellow_tripdata_2024-03.parquet` | ~3,690,154 | 55 MB | 373 MB |
| **Total (raw)** | **9,554,778** | **~150 MB** | **~985 MB** |
| After Pig cleansing | 8,479,421 | — | ~700 MB (2 part files) |
| After Pig enrichment | 8,479,421 | — | 1,054 MB across 2 part files |
| Zone lookup | 265 | 12 KB | 12 KB |

*Verified 27 Sep 2026 by direct download and row-count query.*

### 3.3 Data characteristics

**Trip fact — 19 columns**, all populated per row (some nullable):

| # | Column | Type | Meaning |
|---:|---|---|---|
| 1 | `VendorID` | INT | 1 CMT · 2 Curb Mobility · 6 Myle · 7 Helix |
| 2 | `tpep_pickup_datetime` | TIMESTAMP(µs) | Trip start (local NYC time) |
| 3 | `tpep_dropoff_datetime` | TIMESTAMP(µs) | Trip end |
| 4 | `passenger_count` | BIGINT | Driver-reported |
| 5 | `trip_distance` | DOUBLE | Miles |
| 6 | `RatecodeID` | BIGINT | 1 Standard · 2 JFK · 3 Newark · 4 Nassau/Westchester · 5 Negotiated · 6 Group · 99 Unknown |
| 7 | `store_and_fwd_flag` | CHAR(1) | Y = cached before upload |
| 8 | `PULocationID` | INT | Pickup TLC zone (JOINs to zone lookup) |
| 9 | `DOLocationID` | INT | Drop-off TLC zone |
| 10 | `payment_type` | BIGINT | 1 Card · 2 Cash · 3 No charge · 4 Dispute · 5 Unknown · 6 Voided |
| 11 | `fare_amount` | DOUBLE | Metered fare (USD) |
| 12 | `extra` | DOUBLE | Rush-hour / night surcharges |
| 13 | `mta_tax` | DOUBLE | $0.50 MTA tax |
| 14 | `tip_amount` | DOUBLE | Card tips only (cash not recorded) |
| 15 | `tolls_amount` | DOUBLE | Sum of tolls |
| 16 | `improvement_surcharge` | DOUBLE | $0.30 flat |
| 17 | `total_amount` | DOUBLE | Grand total (excl. cash tip) |
| 18 | `congestion_surcharge` | DOUBLE | $2.50 Manhattan below 96 St |
| 19 | `Airport_fee` | DOUBLE | $1.75 pickup at LGA / JFK |

**Zone dimension — 4 columns × 265 rows**: `LocationID` (PK), `Borough`, `Zone`, `service_zone`.

**Structuredness:** fully **structured** (fixed schema across all rows). *Not* semi-structured — no nested arrays, no schema evolution within a month. Parquet imposes a strict schema per file.

### 3.4 Known data-quality issues (from the veracity story)

Filtered out during Pig ETL Phase 3.1:

| Issue | Filter rule | Approx impact |
|---|---|---|
| `passenger_count` null or 0 | `passenger_count >= 1` | small |
| Long trips with zero distance | `trip_distance > 0 AND < 100` | ~2–3 % |
| Negative / bogus fares | `fare_amount > 0 AND < 500` | ~1 % |
| Missing PU/DO zone IDs | `pu_loc_id IS NOT NULL AND do_loc_id IS NOT NULL` | small |
| Total refund rows | `total_amount > 0` | small |

**Total drop: 11.25 %**, confirmed against the `_counts` counter files Pig writes.

---

## §4 · Proposed Big Data Architecture

### 4.1 Pipeline overview

```
┌──────────────────┐     ┌────────────────┐     ┌────────────────────────┐
│ NYC TLC portal   │ ──► │ curl download  │ ──► │ Local staging          │
│ Parquet files    │     │ + parquet→CSV  │     │ ~/staging (VM disk)    │
└──────────────────┘     └────────────────┘     └───────────┬────────────┘
                                                             │  hdfs dfs -put
                                                             ▼
                    ┌────────────────────────────────────────────────────┐
                    │  HDFS (single-node pseudo-cluster)                 │
                    │    NameNode :9870   DataNode :9864   SNN           │
                    │    Block size 128 MB   Replication 1               │
                    │    /raw/trips/year=YYYY/month=MM/…                 │
                    │    /raw/zone_lookup/taxi_zone_lookup.csv           │
                    └───────────┬────────────────────┬───────────────────┘
                                │                    │
                                ▼                    ▼
                    ┌───────────────────┐   ┌──────────────────────┐
                    │ Pig ETL (MR)      │   │ Native Streaming MR  │
                    │  01_clean_trips   │   │  mapper.py           │
                    │  02_enrich_trips  │   │  reducer.py          │
                    └────────┬──────────┘   └──────────┬───────────┘
                             │                          │
                             ▼                          ▼
                 /clean/trips_enriched         /results/trips_per_zone_hour
                             │
                             ▼
              ┌──────────────────────────────┐
              │ Hive external tables         │      YARN Resource Manager :8088
              │   fact_trips  (external)     │      Job History Server    :19888
              │   dim_zone    (ORC)          │
              │   Q1..Q5 result tables (ORC) │
              └────────┬─────────────────────┘
                       │ INSERT OVERWRITE DIRECTORY
                       ▼
                 /results/hive/{q1_hotspots, q2_revenue_by_borough, q3_congestion,
                                q4_airports, q5_payment_share}
                       │  hdfs dfs -getmerge
                       ▼
              ┌──────────────────────────────┐   ┌───────────────────────────┐
              │ Streamlit dashboard (:8501)  │   │ HBase                     │
              │  Plotly charts × 5 queries   │   │   zone_lookup   (265 rows)│
              │  Interactive filters         │   │   trip_by_zone  (5,410)   │
              └──────────────────────────────┘   │   HMaster :16010          │
                                                 └───────────────────────────┘
```

Full-quality Mermaid source: [`my-work/diagrams/architecture.md`](../diagrams/architecture.md).

### 4.2 Data-source layer

- **Primary source**: NYC TLC public S3 bucket via CloudFront (`d37ci6vzurychx.cloudfront.net`), no auth.
- **Reference source**: TLC taxi zone lookup CSV (12 KB, 265 zones).
- **Ingestion cadence**: monthly batch (mirrors TLC's release cadence). Automated by `download_and_ingest.sh`.

### 4.3 Ingestion layer

`download_and_ingest.sh` performs three steps:

1. `curl` each monthly Parquet file to local staging.
2. Stream-convert Parquet → headerless CSV via pyarrow (row-group streaming keeps memory < 500 MB even on 4 GB RAM).
3. `hdfs dfs -put -f` into partitioned HDFS layout (`/raw/trips/year=YYYY/month=MM/`).

The partition layout is intentional — Hive can prune partitions in Section 4.6 by hitting only the relevant year/month directories.

### 4.4 Storage layer — HDFS pseudo-cluster

Ubuntu 22.04 VM, 4 GB RAM, 60 GB disk.

- **Version**: Hadoop 3.2.1 vanilla Apache.
- **Config** (four XML files, checked into `my-work/scripts/hadoop-conf/`):
  - `core-site.xml`: `fs.defaultFS = hdfs://127.0.0.1:9000`.
  - `hdfs-site.xml`: `dfs.replication = 1` (single-node), permission checks off.
  - `mapred-site.xml`: 512 MB container memory, MR framework = YARN.
  - `yarn-site.xml`: 2 GB total YARN memory, vmem/pmem checks off.
- **Directory contract**:
  - `/raw/` — read-only ingested data
  - `/clean/` — Pig-produced cleaned + enriched data
  - `/results/hive/` — Hive query outputs
  - `/results/trips_per_zone_hour/` — Native MR job output
  - `/user/hive/warehouse/` — Hive-managed ORC tables
  - `/tmp/` — scratch, world-writable
- **Web UIs**: NameNode `:9870`, DataNode `:9864`, YARN RM `:8088`, JHS `:19888`, HBase Master `:16010`, Streamlit `:8501`.

### 4.5 Processing layer

Two complementary compute paths, both running on YARN:

- **Apache Pig 0.17.0** for the heavy ETL — `01_clean_trips.pig` (cleansing) and `02_enrich_trips.pig` (derived-features + zone JOIN). Runtime measured: 3 min 36 s + 1 min 36 s.
- **Native Hadoop Streaming MR (Python)** for one worked example — `mapper.py` + `reducer.py` computing trips-per-zone-per-hour. Runtime: 35 s. Uses `stream.num.map.output.key.fields=2` + `KeyFieldBasedPartitioner` to shuffle on a composite key.

Both paths compile to standard MapReduce jobs — visible in YARN UI, tracked by the Job History Server.

### 4.6 Analytics layer

**Apache Hive 3.1.3** with an embedded Derby metastore (`/home/hdoop/hive_metastore_db`), executing on MR:

- `fact_trips` — external table on `/clean/trips_enriched/`, 8,479,421 rows.
- `dim_zone` — managed ORC table, 265 rows.
- 5 analytical result tables: `q1_hotspots`, `q2_revenue_by_borough`, `q3_congestion`, `q4_airports`, `q5_payment_share`. Total wall time for all 5 queries: ~7 minutes.

**Apache HBase 2.4.18** (standalone mode) for random-access serving of the same zone metadata that Hive scans:

- `zone_lookup` — 265 rows, single column family `info`.
- `trip_by_zone` — 5,410 rows (from Q1 results), two column families `stats` + `top_do`.
- Thrift gateway on `:9090` for Python (happybase) client access.

### 4.7 Presentation layer

**Streamlit 1.30+** app that reads the five CSVs (already `getmerge`ed from HDFS) and renders 5 interactive Plotly charts:

1. Slider-controlled Q1 hotspots
2. Grouped-bar Q2 revenue split
3. Line + table Q3 congestion
4. Radio-selected Q4 airport profile
5. Stacked-bar Q5 payment share

KPI row at top shows total trips, revenue, avg fare, avg tip%. Runs on port `8501`, no Hadoop needed at demo time (frees RAM).

---

## §5 · Technology Selection

For each tool we chose, we answer: *what does it uniquely provide that its alternative doesn't?*

### 5.1 HDFS — why not a NAS / a single-node disk / S3?

HDFS was chosen because it's the concrete implementation of the "distributed storage" concept the syllabus targets. Even in single-node pseudo-cluster mode, it demonstrates:

- **NameNode / DataNode separation** — metadata (fsimage + edit log) lives on the NameNode, actual 128 MB blocks live on the DataNode. `fsck` confirms this at run time.
- **Block-level replication** — configured to 1 for our single node, but the same config on a real cluster gives fault tolerance.
- **HDFS shell verb parity** with `hdfs dfs -ls / -cat / -put / -du / -getmerge` — same UX the industry uses on massive clusters.
- **Ecosystem compatibility** — Pig, Hive, HBase and Spark all talk HDFS natively. A NAS would require every tool to speak its own protocol.

We considered S3 (via Hadoop's `s3a://` connector). It would work, but the assignment is explicitly graded on demonstrating HDFS internals — Web UI, NameNode metadata, DataNode blocks — none of which S3 exposes.

### 5.2 Apache Pig — why not raw MapReduce or Hive for ETL?

Pig sits at the sweet spot for ETL on this size dataset:

- **Higher-level than raw Java MR** — 45 lines of Pig Latin replaces 300+ lines of Java (mapper class, reducer class, driver, custom key/value writables).
- **More flexible than Hive** — Hive requires a table schema upfront; Pig accepts headerless CSV with an inline `AS (…)` schema declaration and handles messy real-world CSV with more forgiving type coercion.
- **Compiles to MapReduce** — demonstrates the same distributed-processing story as raw MR (visible as YARN applications named `PigLatin:01_clean_trips.pig`, etc.) while being faster to author.
- **Multi-query optimisation** — a Pig script produces a DAG that the compiler merges into fewer MR jobs (we observed 3 logical steps merged into 1 MR job).

**Why not Spark instead?** Spark would be faster (in-memory RDDs vs disk-shuffling MR) but:
- Spark on our 4 GB VM is memory-starved by design.
- The assignment explicitly asks us to demonstrate MapReduce concepts. Pig makes them concrete without hiding them (Spark's Catalyst optimiser tends to hide the shuffle mental model).

### 5.3 Native Hadoop Streaming MR — why keep it if Pig already runs MR?

Because Pig *hides* the map/reduce split. A viva question like "explain the shuffle phase" is much easier to answer after you've written `mapper.py` and `reducer.py` by hand:

- The mapper emits `<key>\tHOUR\t1` — one output per input row.
- Hadoop's shuffle groups by the composite key `(pu_loc_id, hour)` — configured explicitly via `stream.num.map.output.key.fields=2` and `KeyFieldBasedPartitioner`.
- The reducer receives contiguous, sorted key-groups and sums values within each.
- Custom counters (`Rows OK` / `Rows BAD`) reported via `stderr` prove we understand Hadoop's counter-reporter protocol.

Result: **8,479,421 rows** collapsed to **5,421 unique (zone, hour) aggregates** in 35 seconds — with the top hotspots (Midtown zones 161/162 at 6 PM rush) matching real NYC traffic patterns.

### 5.4 Apache Hive — why not straight MapReduce?

Hive answers the "SQL over Big Data" story:

- The 5 analytical queries are naturally expressed in SQL (`GROUP BY`, `JOIN`, `CASE WHEN`, window-like patterns). Writing them in raw MR would be a weekend of Java.
- **External tables** — `fact_trips` reads directly from Pig's `/clean/trips_enriched/` output without copying. Schema-on-read: change the DDL, don't re-load 1 GB.
- **ORC-backed intermediate tables** — Q1..Q5 result tables use ORC for its columnar compression, so the Streamlit CSV export is a linear scan of a few compressed MB rather than gigabytes.
- **Compiles to MR** — every Hive query becomes YARN applications; the `EXPLAIN` output shows the exact map/reduce stages, which we screenshot for the report.
- **Metastore** — Derby embedded is enough for a single-node demo; the same DDL works against a shared MySQL/PostgreSQL metastore in production.

**Why not Impala / Presto?** Both are faster but skip the MR execution engine, so they don't advance the syllabus goal of demonstrating Hadoop's distributed-processing model. Hive on MR is the pedagogically-correct choice.

### 5.5 Apache HBase — why add a NoSQL layer at all?

The 5 Hive queries are **batch analytical** — 60-second latencies. But a live driver-dispatch app needs **millisecond zone lookups**. HBase demonstrates the pattern:

- The same zone data lives in `dim_zone` (Hive, batch-scan) AND `zone_lookup` (HBase, random-access `get` by key). Two engines, one dataset, two workloads.
- Row key = `LocationID` stringified → sub-millisecond `get`s (< 1 ms observed).
- Column families (`info` for metadata, `stats` for pre-aggregated Q1 metrics) demonstrate NoSQL's flexible schema.
- Filter scans (`SingleColumnValueFilter('info','borough',=,'EWR')`) show HBase can do targeted range work when the key structure permits.

**Real-world archetype**: Uber uses HBase for exactly this — pre-computed metrics from batch pipelines pushed to HBase for the driver app to query at real-time.

### 5.6 Streamlit — why not Power BI / Tableau?

- **Python-native** — the analytics team is already in the Python ecosystem via pandas/Plotly. Streamlit is < 200 lines of Python for a full multi-page interactive dashboard.
- **File-based inputs** — reads the 5 CSVs we already exported. No enterprise BI licensing.
- **Interactive filters** — hour slider (Q1), airport radio (Q4), etc. Faculty can drive the demo live.
- **Runs entirely offline** — after Hadoop shuts down. Frees RAM for a smooth demo.

Power BI / Tableau are stronger for corporate BI, but the assignment specifies Streamlit-class deliverables and our stack is Python end-to-end.

### 5.7 Everything else — why NOT chosen

| Rejected | Reason |
|---|---|
| Spark (MLlib / Spark SQL) | Would work but assignment targets Hadoop MR concepts; 4 GB VM would OOM under Spark's memory-first design; adds another JVM to manage. |
| Kafka streaming | Would answer the "velocity" V better, but complicates the pseudo-cluster and adds no marks — the syllabus already accepts monthly batches. |
| AWS EMR / GCP Dataproc | Cost, and duplicates the same conceptual demo more expensively. Local VM proves we can build the stack ourselves. |
| MongoDB | Alternative to HBase, but HBase integrates more tightly with HDFS (same DataNode, same block replication), which advances the Hadoop-ecosystem story better. |
| Ambari | Web UI convenience only — doesn't add any technical demo. Manual install (which we did) is a better learning artifact. |

---

## §6 · Summary metrics

### Pipeline stats

| Layer | Metric | Value |
|---|---|---:|
| Storage | Raw HDFS data | 985 MB |
| Storage | Cleaned + enriched | 1.05 GB |
| Processing | Rows through Pig | 9.55 M → 8.48 M |
| Processing | Streaming MR wall time | 35 s |
| Processing | Total Hive wall time (5 queries) | ~7 min |
| Serving | HBase `zone_lookup` rows | 265 |
| Serving | HBase `trip_by_zone` rows | 5,410 |
| Presentation | Streamlit charts | 5 (KPIs + drill-downs) |

### Business KPIs (from dashboard)

| KPI | Value |
|---|---:|
| Total trips analyzed (Jan–Mar 2024) | **8,479,421** |
| Total taxi revenue | **$235.12 M** |
| Average fare per trip | **$33.70** |
| Average tip % | **4.7 %** |

### Headline analytical findings

- **Q1 · Demand hotspots at 18:00**: Midtown Center leads (~38 k trips), followed by Upper East Side South, Midtown East, Upper East Side North, and JFK Airport — all confirming Manhattan-CBD dominance during evening rush.
- **Q2 · Revenue by borough × payment**: Manhattan card revenue (~$150 M) dwarfs all other combinations. Queens is a distant second (~$50 M), driven by JFK/LGA airport trips.
- **Q3 · Congestion signal**: Slowest PU→DO pair in the top-15 is zone 186 (Penn Station) → zone 230 (Times Sq) at **17.16 min/mile** at 10 AM — a ~1 mile trip taking ~17 minutes. Confirms known Midtown-CBD gridlock.
- **Q4 · JFK trip profile**: Top destinations are Times Sq/Theatre District (18,696 trips), Outside NYC (16,343), JFK ↔ JFK round-trips (10,876), Midtown South (10,034). Airport→CBD is the dominant flow.
- **Q5 · Payment behaviour**: Card share is 79–91 % across most boroughs. **Staten Island is the outlier at 60.2 % card / 31.1 % cash** — meaningful for POS-terminal deployment strategy.

---

## §7 · References

1. **NYC TLC Trip Record Data** — https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
2. **TLC Yellow Trip Data Dictionary (PDF)** — https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_yellow.pdf
3. **Taxi Zone Map & Lookup** — https://www.nyc.gov/assets/tlc/downloads/pdf/taxi_zone_map_manhattan.pdf
4. **Apache Hadoop 3.2.1** — https://hadoop.apache.org/docs/r3.2.1/
5. **Apache Pig 0.17.0** — https://pig.apache.org/docs/r0.17.0/
6. **Apache Hive 3.1.3** — https://hive.apache.org/
7. **Apache HBase 2.4.18** — https://hbase.apache.org/2.4/book.html
8. **Streamlit** — https://docs.streamlit.io/
9. **Hadoop Streaming Guide** — https://hadoop.apache.org/docs/r3.2.1/hadoop-streaming/HadoopStreaming.html
10. **NoSQL vs SQL comparative context** — https://hbase.apache.org/book.html#arch.overview
