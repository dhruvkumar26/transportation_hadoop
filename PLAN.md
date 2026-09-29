# BITS Pilani – CC ZG522 Big Data Systems – Assignment 1

**Course:** CC ZG522 Big Data Systems, First Semester 2026-27
**Assignment:** #1 – Big Data Systems Implementation & Analytics
**Domain:** Transportation
**Marks:** 20 | **Deadline:** 18 Sep 2026 | **Group Size:** 6

---

## 1. Topic (final pick)

### **NYC Taxi Trip Analytics – Demand, Revenue & Congestion Insights**

Dataset: **NYC Taxi & Limousine Commission (TLC) Yellow Taxi Trip Records**, 2024 data (public, no auth). One of the largest public transportation datasets in the world.

**Volume plan (tuned for 4 GB RAM):** 3 months of Yellow Taxi data (Jan–Mar 2024) ≈ **9–10 million trip records**, **~750 MB Parquet / ~3 GB expanded CSV**. Genuinely "big" for a pseudo-cluster demo; single-machine SQLite/pandas struggles here.

Data dictionary + monthly Parquet files: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page

**Business problems answered:**

1. **Demand hotspots** – Busiest pickup zones by hour-of-day / day-of-week (driver dispatch).
2. **Revenue analytics** – Fare + tip distribution per zone / distance bucket / payment type.
3. **Congestion signal** – Average trip duration per PU→DO zone pair by hour (identifies choke points).
4. **Airport trip profile** – JFK/LGA/EWR trips: ADR, tip %, top destinations.
5. **Payment behaviour** – Cash vs card share by zone (fintech policy signal).

**Why this dataset is defensible in the viva:**
| V | Evidence |
| --- | --- |
| Volume | 9–10M records; scales to 100M+ in real deployment. |
| Variety | Trip fact table (structured) + zone lookup (structured ref) + optional weather (semi-structured JSON). |
| Velocity | Monthly batch drops in production; we ingest as batches with year/month partitions. |
| Veracity | Real messy data — negative fares, zero-distance long trips, missing PU/DO IDs → cleansing story for Pig ETL. |
| Value | NYC city planners, ride-hail firms, banks (payment share) — all real customers. |

---

## 2. Tech stack (locked)

| Layer | Tool | Why |
| --- | --- | --- |
| Distributed storage | **HDFS** (single-node pseudo-cluster, already up) | Assignment requirement; demos NameNode + DataNode + block replication. |
| Ingestion | `hdfs dfs -put` + shell script | Standard batch ingestion. |
| ETL | **Apache Pig** | Pig Latin compiles to MR — YARN counters prove MR ran. Good for cleansing + joins. |
| Native MR (once) | **Hadoop Streaming with Python** | Explicit MR demo (trips-per-zone). Confirms we understand the map/reduce split for the viva. |
| Warehouse | **Hive** | SQL analytics on HDFS. Answers all 5 business queries. |
| Random-access lookup | **HBase** | Stores zone lookup (265 zones) as a NoSQL demo — random `get` by zone_id vs Hive's scan-based JOIN. |
| Dashboard | **Streamlit** | Reads exported CSVs from Hive results; interactive plots (Plotly). |

**On MapReduce:** Pig and Hive both compile to MR jobs — the assignment's MR requirement is already covered. The extra native Streaming job is insurance for the viva: it shows we can define a mapper + reducer manually.

---

## 3. Current environment (status)

Verified done via Dr. Venkat's setup guide:

| Component | Status | Path/Version |
| --- | --- | --- |
| VirtualBox | ✅ | 7.0.8, Windows host |
| VM | ✅ | `bigdata` — Ubuntu 22.04, 4 GB RAM, 60 GB disk |
| Java | ✅ | OpenJDK 8 @ `/usr/lib/jvm/java-8-openjdk-amd64` |
| SSH passwordless | ✅ | for user `hdoop` |
| Hadoop | ✅ | 3.2.1 @ `/home/hdoop/hadoop-3.2.1` |
| Namenode metadata | ⚠️ | Config had bug — see fix in `user-tasks/00-...md` |
| DataNode dir | ✅ | `/home/hdoop/dfsdata/datanode` |
| YARN RM | ✅ | `127.0.0.1:8088` |
| WordCount test | ✅ | Ran to completion — MR pipeline works |
| Web UIs | ✅ | `:9870` NameNode, `:8088` YARN, `:9864` DataNode |
| Pig | ❌ | To install |
| Hive | ❌ | To install |
| HBase | ❌ | To install |

**Config bugs to fix before loading real data** (small MD provided):
- `hdfs-site.xml`: first `dfs.data.dir` should be `dfs.name.dir`; `dfs.replication` should be `1` (not `3`).
- `.bashrc`: `HADOOP_OPTS` has typo `lib/nativ` → `lib/native`.

---

## 4. RAM budget (4 GB constraint)

We cannot keep every service running at once. Strategy:

| Phase | Running services | Approx RAM |
| --- | --- | --- |
| Baseline (idle Ubuntu + Hadoop) | NN, DN, SNN, RM, NM | ~2 GB |
| Pig ETL | + Pig client | ~2.3 GB |
| MR job | + MR AM + containers (tuned to 512 MB) | ~3 GB |
| Hive queries | + HiveServer2 + Metastore | ~3.2 GB — **stop HBase first** |
| HBase demo | + HMaster + RS + ZK | ~3.5 GB — **stop Hive first** |
| Streamlit dashboard | Runs after data is exported to local CSVs → **all Hadoop services can be stopped** | ~1 GB |

YARN container tuning: `mapreduce.map.memory.mb=512`, `mapreduce.reduce.memory.mb=512`, `yarn.nodemanager.resource.memory-mb=2048`. Baked into config fix.

---

## 5. Task split – **who does what**

Legend: **[ME]** = I produce the file. **[T]** = your team runs it in the VM. **[BOTH]** = I write, you execute, we iterate.

### Phase 0 – ✅ Environment (done by team)
### Phase 0.5 – Config fixes + env sanity check
- [ME] `user-tasks/00-env-verification-and-config-fix.md` ✓ (this turn)
- [T] Apply fixes, re-format NN, verify daemons.

### Phase 1 – Install Pig, Hive, HBase
- [ME] `user-tasks/01-install-pig-hive-hbase.md`
- [T] Install & verify each.

### Phase 2 – Dataset download & HDFS ingestion
- [ME] `user-tasks/02-download-and-ingest.md` + `scripts/ingest.sh`
- [T] Run in VM, screenshot NameNode UI.

### Phase 3 – Pig ETL
- [ME] `scripts/pig/01_clean_trips.pig`, `02_enrich_trips.pig`, doc `user-tasks/03-run-pig-etl.md`
- [T] Run, screenshot YARN UI showing MR jobs.

### Phase 4 – Native Hadoop Streaming MR
- [ME] `scripts/mapreduce/mapper.py`, `reducer.py`, `run.sh`, doc `user-tasks/04-run-mapreduce.md`
- [T] Run, screenshot counters.

### Phase 5 – Hive analytics
- [ME] `scripts/hive/01_ddl.sql`, `02_analytics.sql`, `03_export.sql`, doc `user-tasks/05-run-hive.md`
- [T] Run in Beeline, screenshot query output + `EXPLAIN`.

### Phase 6 – HBase demo
- [ME] `scripts/hbase/create_tables.hbase`, `load_zones.py`, doc `user-tasks/06-run-hbase.md`
- [T] Run, screenshot scans/gets.

### Phase 7 – Dashboard
- [ME] `dashboard/app.py` (Streamlit), doc `user-tasks/07-dashboard.md`
- [T] Export CSVs to local FS, run Streamlit, screenshots.

### Phase 8 – Part A report
- [ME] `report/part-a-theory.md` + architecture SVG
- [T] Review, export to PDF.

### Phase 9 – Screenshots, deck, viva prep
- [ME] `report/presentation-outline.md`, `report/viva-qa.md`, `user-tasks/08-screenshot-checklist.md`
- [T] Capture screenshots, build deck, rehearse.

---

## 6. Directory layout

```
Assignment/
├── PLAN.md                              ← this
├── TEAM-ASSIGNMENTS.md                  ← who owns what (see below)
├── user-tasks/                          ← team's execution guides
│   ├── 00-env-verification-and-config-fix.md
│   ├── 01-install-pig-hive-hbase.md
│   └── … (created as we reach each phase)
├── my-work/
│   ├── report/                          ← theory + presentation + viva
│   ├── scripts/                         ← pig / hive / hbase / mapreduce / hadoop-conf
│   ├── dashboard/                       ← Streamlit app
│   └── diagrams/                        ← architecture SVG
└── reference/                           ← data dictionary, notes
```

See `TEAM-ASSIGNMENTS.md` for the 6-person split.

---

## 7. Timeline (working back from Sep 18)

| Week | Milestone |
| --- | --- |
| 1 | Env verified + Pig/Hive/HBase installed |
| 2 | Dataset in HDFS, Pig ETL done |
| 3 | Native MR + Hive analytics done |
| 4 | HBase + Dashboard + Report draft |
| 5 | Screenshots, polish, deck rehearsal |
| 6 | Buffer + faculty demo |

---

## 8. Open follow-ups

- If team members' real names are shared, I'll swap "Dhruv…Vishwa" placeholders in `TEAM-ASSIGNMENTS.md`.
- Confirm which member acts as **Group Leader** and **Presentation Coordinator** (assignment requires both nominations).
