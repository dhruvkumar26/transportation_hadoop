# 5-Minute Presentation Outline

**Course:** CC ZG522 · Big Data Systems · Assignment 1
**Domain:** Transportation — NYC Yellow Taxi Analytics
**Total duration:** 5 min presentation + 2–3 min viva
**Owner:** M2 (Presentation Coordinator)

---

## Time budget

| Slide | Duration | Owner voice |
|---|---:|---|
| 1 · Title | 15 s | M1 |
| 2 · Problem & business questions | 45 s | M1 |
| 3 · Why Big Data (5 Vs applied) | 45 s | M2 |
| 4 · Architecture diagram | 45 s | M4 |
| 5 · Storage — HDFS pseudo-cluster | 30 s | M1 |
| 6 · Processing — Pig ETL + Native MR | 45 s | M3 + M4 |
| 7 · Analytics — Hive results | 45 s | M5 |
| 8 · Serving — HBase & Streamlit dashboard | 45 s | M2 + M6 |
| 9 · Key insights & closing | 15 s | M1 |
| **Total** | **~5 min** | |

Every member speaks. Faculty may cold-call anyone in viva regardless of slide ownership.

---

## Slide 1 · Title

- **Title:** NYC Yellow Taxi Analytics on a Hadoop Pseudo-Cluster
- **Subtitle:** BITS ZG522 · Big Data Systems · Assignment 1
- **Team:** M1 (Group Leader), M2 (Presentation Coordinator), M3, M4, M5, M6
- **Domain:** Transportation
- One-line hook: *"9.5 million real NYC taxi trips, end-to-end from raw Parquet to interactive dashboard, on a 4 GB VM."*

## Slide 2 · Problem & business questions (M1)

- Ride-hail industry generates billions of trip records; five business questions we set out to answer:
  1. **Demand hotspots** — where should drivers wait?
  2. **Revenue analytics** — which borough × payment method makes the most money?
  3. **Congestion signal** — which zone pairs are systematically slow?
  4. **Airport trip profile** — JFK, LGA, EWR patterns.
  5. **Payment behaviour** — card vs cash split.
- Dataset: NYC TLC Yellow Taxi Records, **Jan–Mar 2024, 9.55 M raw rows, 985 MB CSV**.

## Slide 3 · Why Big Data — the 5 Vs (M2)

Compact table:

| V | Manifestation |
|---|---|
| Volume | 9.55 M rows / 985 MB / scales to billions |
| Velocity | Monthly batch drops, partitioned by year/month |
| Variety | Trip fact + zone dim + optional weather |
| Veracity | Pig ETL dropped 11.25 % dirty rows |
| Value | 5 distinct business decisions driven |

Punchline: *"A single-node RDBMS could answer one of these; not all five simultaneously across years while ingesting new data."*

## Slide 4 · Architecture (M4)

**One image** — the full pipeline diagram (from `my-work/diagrams/architecture.md`):

```
TLC portal → curl → CSV → HDFS /raw/
              ↓
  Pig ETL      +  Native MR (Python Streaming)
              ↓
  HDFS /clean/trips_enriched
              ↓
  Hive (5 queries)     +   HBase (zone + rollups)
              ↓
  /results/hive → getmerge → Streamlit dashboard
```

Verbal: *"Every layer runs on YARN; every result is in HDFS; the dashboard reads a local export."*

## Slide 5 · HDFS — distributed storage (M1)

- Hadoop 3.2.1 pseudo-cluster on Ubuntu 22.04, 4 GB RAM.
- `jps` shows the 7 daemons: NameNode, DataNode, SNN, ResourceManager, NodeManager, JobHistoryServer, (HMaster when running HBase).
- **Screenshot: NameNode Web UI (`:9870`) showing `/raw/trips/year=2024/month=01/…`**
- Point out block size (128 MB), replication factor 1 (single-node), `fsck` reports HEALTHY.

## Slide 6 · Processing — Pig ETL + native MR (M3 + M4)

**Two mini-panels:**

- **M4 · Pig** — `01_clean_trips.pig` (drop 11.25 % bad rows) + `02_enrich_trips.pig` (derive hour/day/duration, JOIN zone lookup). 9.55 M → 8.48 M rows in 5 min 12 s across 2 MR jobs.
  - *Screenshot: YARN UI showing `PigLatin:02_enrich_trips.pig` SUCCEEDED with 9 mappers, 2 reducers.*
- **M3 · Native Streaming MR** — mapper.py emits `(pu_loc_id, hour) → 1`; reducer sums. Uses `stream.num.map.output.key.fields=2` for composite-key shuffle. 8.48 M input → **5,421 unique (zone, hour) aggregates** in 35 s.
  - *Screenshot: YARN counters page showing `Rows OK=8,479,421` custom counter.*
- Punchline: *"Pig proves the pipeline scales; native MR proves we understand the shuffle."*

## Slide 7 · Analytics — Hive (M5)

- Hive 3.1.3 with embedded Derby metastore. `fact_trips` external table over Pig output (8,479,421 rows), `dim_zone` ORC (265 rows).
- 5 analytical queries → 5 ORC result tables → 5 CSV exports.
- **Screenshot: `EXPLAIN` plan showing the Map/Reduce stages Hive generates.**
- Wall time: ~7 min for all 5 queries on 4 GB.
- Punchline: *"SQL over 8 million rows in 60–90 seconds per query — same syntax as an RDBMS, distributed underneath."*

## Slide 8 · Serving — HBase + Streamlit (M2 + M6)

- **M2 · HBase** — random-access companion to Hive. `zone_lookup` (265 rows, `info` family) + `trip_by_zone` (5,410 rows from Q1 rollup, `stats` family). `get 'zone_lookup','132'` returns JFK in <1 ms.
  - *Screenshot: HBase Master UI at `:16010`.*
- **M6 · Streamlit dashboard** — 5 interactive Plotly charts, KPI row up top.
  - **KPIs:** 8.48 M trips · **$235.12 M** revenue · **$33.70** avg fare · **4.7 %** avg tip.
  - *Screenshot: dashboard home + one drill-down (e.g. Q4 JFK).*
- Punchline: *"Hive for batch analytics, HBase for real-time lookups, Streamlit for humans — three access patterns on one HDFS."*

## Slide 9 · Key insights & closing (M1)

- **Where is the money?** Manhattan card revenue (~$150 M / 3 mo) — 3× Queens (~$50 M), 30× everything else.
- **Where is the demand?** Midtown Center at 6 PM: **38,756 trips** in Jan-Mar 2024.
- **Where does the pipeline break down first?** Zone 186 (Penn Station) → 230 (Times Sq): **17.16 min/mile** at 10 AM — a 1-mile trip taking 17 minutes.
- **Where should banks deploy more POS terminals?** Staten Island — **31 % cash share** (2× the city average).
- Closing: *"Every line of this pipeline is checked into git — the report has the exact numbers, run this weekend on a $0 pseudo-cluster."*

---

## Delivery notes for M2

- Rehearse with a stopwatch. First run always overruns.
- Every screenshot on a slide needs a one-sentence caption when speaking (*"This is the NameNode Web UI showing our three monthly partitions"*).
- Do NOT read bullets verbatim. Bullets are your prompts, not your script.
- Rehearse hand-offs — **the transition line** between speakers matters more than the content ("Now M3 will walk through the native MR job").
- Have the dashboard PDF open in a second window; if a screenshot in the deck is unclear, faculty may ask to see it live.

## Backup slides (not counted in 5 min)

- Slide B1 — Full 4 GB RAM budget table (per phase)
- Slide B2 — Data-quality drop-rate breakdown
- Slide B3 — Config bug story (arm64 java, duplicate ConnectionURL, streaming composite key) → shows problem-solving depth
- Slide B4 — Extended architecture: what would change moving from pseudo-cluster to real 20-node cluster

Only bring these up if asked or if you have time.
