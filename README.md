# BITS CC ZG522 · Big Data Systems · Assignment 1

**Team domain:** Transportation
**Dataset:** NYC TLC Yellow Taxi Trip Records (Jan–Mar 2026, ~11.1M records, ~1.17 GB CSV)
**Stack:** HDFS · Pig · Hive · HBase · Hadoop Streaming (Python) · Streamlit

## Start here

| Doc | Purpose |
|---|---|
| [PLAN.md](PLAN.md) | Master plan, phases, RAM budget |
| [TEAM-ASSIGNMENTS.md](TEAM-ASSIGNMENTS.md) | Who owns what (Dhruv–Vishwa) |
| [user-tasks/](user-tasks/) | Step-by-step guides your team runs in the VM |
| [my-work/](my-work/) | Scripts, configs, dashboard, report |
| [reference/](reference/) | Dataset schema + small sample data |

## How the team works with this repo

Per the collaboration policy: **6 individual VMs**. Each phase has an owner who executes it first, then writes the exact reproducible steps into their `user-tasks/*.md`. The other 5 members reproduce the phase on their own VMs for learning + viva readiness.

- The phase owner is the "reference implementer" for that phase.
- All 6 members' final results are equivalent because they all followed the same guide.
- Screenshots go into `screenshots/phase-N/<memberID>/` (created inside the repo when needed).

## Repo layout

```
Assignment/
├── PLAN.md
├── TEAM-ASSIGNMENTS.md
├── README.md                       ← this file
├── .gitignore
│
├── user-tasks/                     ← reproducible step-by-step guides
│   ├── 00-env-verification-and-config-fix.md
│   ├── 01-install-pig-hive-hbase.md
│   ├── 02-download-and-ingest.md
│   ├── 03-run-pig-etl.md
│   ├── 04-run-mapreduce.md
│   ├── 05-run-hive.md
│   ├── 06-run-hbase.md
│   ├── 07-dashboard.md
│   └── 08-screenshot-checklist.md
│
├── my-work/
│   ├── report/                     ← Part A theory, presentation, viva Q&A
│   ├── scripts/
│   │   ├── hadoop-conf/            ← corrected core/hdfs/mapred/yarn xml
│   │   ├── ingest/                 ← download + parquet→csv + hdfs put
│   │   ├── pig/                    ← Pig Latin scripts
│   │   ├── mapreduce/              ← native Hadoop Streaming (Python)
│   │   ├── hive/                   ← DDL + analytics + export SQL
│   │   └── hbase/                  ← HBase shell + zone loader
│   ├── dashboard/                  ← Streamlit app
│   └── diagrams/                   ← architecture diagram (mermaid + svg)
│
└── reference/
    ├── dataset-schema.md           ← 19-column data dictionary
    ├── taxi_zone_lookup.csv        ← 265 NYC taxi zones (downloaded 27 Sep 2026)
    └── sample-data/
        └── yellow_tripdata_2026-01_sample.csv  (first 1000 rows, for eyeballing)
```

## Quick usage

Team members on their VM:

```bash
cd ~
git clone <repo-url> bigdata-assignment
cd bigdata-assignment
# Follow user-tasks in numerical order
```

Data files themselves are NOT stored in the repo (see `.gitignore`). Only scripts, configs, docs and small samples are versioned.
