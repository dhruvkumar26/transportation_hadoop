# Phase 8 – Screenshot Checklist (master list)

**Owner:** Manikandan (Presentation Coordinator — you'll need every one of these for the deck).
**Purpose:** consolidate every screenshot the report + presentation needs, organized by phase, so nothing is missed.

Store all under `screenshots/phase-N/<memberID>/` in the repo. Since every member reproduces every phase for learning, the phase owner's screenshots go into the final report; the others' are personal evidence for the viva.

---

## Phase 0.5 – Env verification

| # | File | What it shows | Where to capture |
|---|---|---|---|
| 1 | `00-stopped.png` | `jps` after `stop-yarn.sh` + `stop-dfs.sh` — only "Jps" listed | VM terminal |
| 2 | `00-jps-healthy.png` | `jps` after `start-dfs.sh` + `start-yarn.sh` — NN, DN, SNN, RM, NM, Jps all listed | VM terminal |
| 3 | `00-hdfs-layout.png` | `hdfs dfs -ls /` showing `/raw /clean /results /tmp /user` | VM terminal |
| 4 | `00-namenode-ui.png` | `http://localhost:9870` overview page | VM Firefox |
| 5 | `00-wordcount-counters.png` | Wordcount job counters (54 counter block) | VM terminal or YARN UI |

## Phase 1 – Pig/Hive/HBase install

| # | File | What it shows |
|---|---|---|
| 6 | `01-pig-version.png` | `pig -version` = 0.17.0 |
| 7 | `01-hive-show-databases.png` | `hive -e "SHOW DATABASES;"` returning `default` |
| 8 | `01-hbase-master-ui.png` | `http://localhost:16010` Master UI |

## Phase 2 – Ingest

| # | File | What it shows |
|---|---|---|
| 9 | `02-hdfs-head.png` | `hdfs dfs -cat` first 3 rows of Jan CSV |
| 10 | `02-hdfs-fsck.png` | fsck output: HEALTHY, blocks per file, avg block size |
| 11 | `02-namenode-overview.png` | NameNode UI overview after data load |
| 12 | `02-namenode-browse.png` | Utilities → Browse `/raw/trips/year=2024/month=01/` |
| 13 | `02-namenode-datanodes.png` | Datanodes tab with block distribution |

## Phase 3 – Pig ETL

| # | File | What it shows |
|---|---|---|
| 14 | `03-pig-clean-summary.png` | Bottom of `pig_01.log` + drop-rate |
| 15 | `03-yarn-pig-app.png` | YARN UI showing Pig apps SUCCEEDED |
| 16 | `03-yarn-pig-counters.png` | One Pig job's counters page |

## Phase 4 – Native MR

| # | File | What it shows |
|---|---|---|
| 17 | `04-yarn-mr-app-list.png` | YARN UI with `TripsPerZonePerHour` |
| 18 | `04-yarn-mr-counters.png` | Custom counters `Rows OK` / `Rows BAD` visible |
| 19 | `04-top-hotspots.png` | Terminal showing top-20 busiest zone-hours from MR output |

## Phase 5 – Hive

| # | File | What it shows |
|---|---|---|
| 20 | `05-hive-ddl-counts.png` | `SELECT COUNT(*)` from fact_trips + dim_zone |
| 21 | `05-yarn-hive-apps.png` | YARN UI with multiple Hive apps |
| 22 | `05-hive-q1-preview.png` | Q1 top-5 zones at hour 18 |
| 23 | `05-hive-q4-preview.png` | Q4 JFK destinations preview |
| 24 | `05-hive-explain.png` | EXPLAIN plan (Map Reduce stages) |
| 25 | `05-exported-csvs.png` | `ls -lh dashboard/data/` |

## Phase 6 – HBase

| # | File | What it shows |
|---|---|---|
| 26 | `06-hbase-master.png` | `http://localhost:16010` Master UI |
| 27 | `06-hbase-list.png` | `list` in shell showing 2 tables |
| 28 | `06-hbase-load.png` | Loader output: `Inserted 265 zones...` |
| 29 | `06-hbase-gets.png` | Three `get` commands for zones 132, 138, 1 |
| 30 | `06-hbase-filter.png` | Scan with EWR filter returning Newark row |
| 31 | `06-hbase-trip-by-zone.png` | (optional) `scan 'trip_by_zone', {LIMIT=>5}` |

## Phase 7 – Dashboard

| # | File | What it shows |
|---|---|---|
| 32 | `07-dashboard-home.png` | Title + KPI row |
| 33 | `07-dashboard-q1.png` | Q1 at hour 18 |
| 34 | `07-dashboard-q1-morning.png` | Q1 at hour 8 (compare) |
| 35 | `07-dashboard-q2.png` | Q2 revenue by borough × payment |
| 36 | `07-dashboard-q3.png` | Q3 congestion line + slow-pairs table |
| 37 | `07-dashboard-q4-jfk.png` | Q4 with JFK selected |
| 38 | `07-dashboard-q4-lga.png` | Q4 with LGA selected |
| 39 | `07-dashboard-q5.png` | Q5 payment share |

## Total

**39 screenshots.** Faculty explicitly want these — "Demonstration of the working system carries higher weightage than theoretical explanations" (assignment PDF, "Important Notes").

---

## How to organise them in the report

Put screenshots inline in Part B of the report, grouped by phase. Each screenshot gets:
- A caption ("Figure N — YARN Resource Manager UI showing 4 Pig applications SUCCEEDED").
- A one-line explanation of what it proves.

The deck (Manikandan) uses ~10 of these for the 5-minute presentation:
- 1 architecture diagram (from `my-work/diagrams/`)
- 1 NameNode overview (proves HDFS is up)
- 1 YARN UI with Pig apps (proves distributed processing)
- 1 MR counters (proves native MR understanding)
- 1 Hive EXPLAIN (proves Hive→MR compilation)
- 1 HBase Master UI or `get` output (proves NoSQL awareness)
- 3–4 dashboard shots (the actual analytical insights)

---

## Reproduce checklist (for all 6 members)

- [ ] Every screenshot listed above exists in your `screenshots/phase-N/<yourID>/` folder.
- [ ] Screenshots are readable (text ≥ 10 pt after any resizing).
- [ ] URLs/timestamps visible where relevant (proves it's your VM).
