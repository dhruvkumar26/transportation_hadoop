# Phase 5 – Hive: Warehouse Tables + 5 Business Analytics Queries

**Phase owner:** M5
**Time:** 30–45 minutes (5 substantial queries against 8 M rows on a 4 GB VM).
**Prerequisites:** `/clean/trips_enriched` populated (Phase 3). Hive installed (Phase 1). **HBase stopped** (`stop-hbase.sh`) — Hive+HBase together will run out of memory.

## What we're doing

1. Register the Pig-enriched data as a Hive external table (no copy — Hive reads HDFS directly).
2. Load the zone lookup into an ORC-backed dim table.
3. Run 5 business queries, each materializing its result into an ORC table.
4. Capture `EXPLAIN` plans and query counters for the report.
5. Export results as CSV in `/results/hive/` for the Streamlit dashboard.

---

## Step 1 — Pull scripts

```bash
cd ~/bigdata-assignment && git pull
```

Scripts:
- `my-work/scripts/hive/01_ddl.sql`
- `my-work/scripts/hive/02_analytics.sql`
- `my-work/scripts/hive/03_export.sql`

---

## Step 2 — Sanity: HBase stopped, Hadoop up

```bash
jps
```

Expected: **no** `HMaster` / `HRegionServer` / `HQuorumPeer`. Only Hadoop daemons.

If HBase is up: `stop-hbase.sh`.

---

## Step 3 — Run DDL (`01_ddl.sql`)

```bash
cd ~/bigdata-assignment/my-work/scripts/hive
hive -f 01_ddl.sql 2>&1 | tee ~/hive_01_ddl.log
```

Expected at the bottom:

```
OK
Time taken: X.X seconds

+------------+
| trip_count |
+------------+
| 8400000+   |
+------------+

+------------+
| zone_count |
+------------+
|    265     |
+------------+
...
```

Screenshot: `05-hive-ddl-counts.png`.

---

## Step 4 — Run analytics (`02_analytics.sql`)

Warm up:

```bash
# In case a prior run left partial state
hive -e "USE taxi_analytics; DROP TABLE IF EXISTS q1_hotspots; DROP TABLE IF EXISTS q2_revenue_by_borough; DROP TABLE IF EXISTS q3_congestion; DROP TABLE IF EXISTS q4_airports; DROP TABLE IF EXISTS q5_payment_share;"
```

Then run:

```bash
hive -f 02_analytics.sql 2>&1 | tee ~/hive_02_analytics.log
```

Each query kicks off one or more MR jobs. Runtime for all 5: **20–30 minutes** on the 4 GB VM. You'll see multiple `map … reduce …` progress lines and each query's top-5 preview at the end.

Screenshots to take while queries run:
- YARN UI showing multiple Hive apps → `05-yarn-hive-apps.png`
- Terminal showing one query's result preview → `05-hive-q1-preview.png`, `05-hive-q4-preview.png`, etc.

---

## Step 5 — Screenshot the EXPLAIN plan

The tail of `02_analytics.sql` runs an `EXPLAIN`. Its output block will look like:

```
STAGE DEPENDENCIES:
  Stage-1 is a root stage
  Stage-0 depends on stages: Stage-1

STAGE PLANS:
  Stage: Stage-1
    Map Reduce
      Map Operator Tree:
          TableScan
            alias: fact_trips
            ...
```

Screenshot: `05-hive-explain.png`. This is your evidence in the viva that "Hive queries compile to MR jobs".

---

## Step 6 — Run export (`03_export.sql`)

```bash
hive -f 03_export.sql 2>&1 | tee ~/hive_03_export.log
```

Verify:

```bash
hdfs dfs -ls -R /results/hive
```

Expected:

```
drwxr-xr-x  - hdoop supergroup  0 ... /results/hive/q1_hotspots
-rw-r--r--  1 hdoop supergroup  ~ ...  /results/hive/q1_hotspots/000000_0
drwxr-xr-x  - hdoop supergroup  0 ... /results/hive/q2_revenue_by_borough
-rw-r--r--  1 hdoop supergroup  ~ ...  /results/hive/q2_revenue_by_borough/000000_0
... (same pattern for q3, q4, q5)
```

Quick peek:

```bash
for q in q1_hotspots q2_revenue_by_borough q3_congestion q4_airports q5_payment_share; do
  echo "=== $q ==="
  hdfs dfs -cat /results/hive/$q/* | head -5
done
```

---

## Step 7 — Pull results down to local FS for the dashboard

Prepare the local target directory the Streamlit app expects:

```bash
mkdir -p ~/bigdata-assignment/my-work/dashboard/data

for q in q1_hotspots q2_revenue_by_borough q3_congestion q4_airports q5_payment_share; do
  hdfs dfs -getmerge /results/hive/$q  ~/bigdata-assignment/my-work/dashboard/data/${q}.csv
done

ls -lh ~/bigdata-assignment/my-work/dashboard/data
```

Expected: 5 CSV files, sizes ranging from a few KB (q5) to a couple MB (q1, q3).

Screenshot: `05-exported-csvs.png`.

---

## What to send back to Claude

1. Last 30 lines of `~/hive_01_ddl.log` (trip + zone counts).
2. Row counts for each analytics table:

```bash
for t in q1_hotspots q2_revenue_by_borough q3_congestion q4_airports q5_payment_share; do
  hive -e "SELECT '$t', COUNT(*) FROM taxi_analytics.$t;"
done
```

3. `ls -lh ~/bigdata-assignment/my-work/dashboard/data/`
4. The full `EXPLAIN` block from `~/hive_02_analytics.log`.
5. Any errors.

Next: **`06-run-hbase.md`**.

---

## Reproduce checklist

- [ ] `hive` opens without SAXParseException / Guava errors.
- [ ] `fact_trips` count ≈ 8.4 M.
- [ ] `dim_zone` count = 265.
- [ ] All 5 Hive query tables created and non-empty.
- [ ] `EXPLAIN` output captured.
- [ ] 5 CSVs in `dashboard/data/`.
- [ ] Screenshots taken.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `hive` startup slow (60+ s) | Normal for Derby + first Hive session. Runs fine after warm-up. |
| `SemanticException Line X: Invalid path` | `LOCATION` in DDL points somewhere that doesn't exist — confirm `/clean/trips_enriched` and `/raw/zone_lookup` present |
| Zone JOIN returns 0 rows | Zone lookup didn't load — check `SELECT COUNT(*) FROM dim_zone;`; header-row filter in DDL may need adjusting |
| Query stuck at 0 % | YARN memory issue — check `yarn top`; run only one query at a time |
| `OutOfMemoryError` during query | Bump `hive.tez.container.size` or run with `set hive.execution.engine=mr;` (this is the default anyway on our setup) |
| `INSERT OVERWRITE DIRECTORY` fails | Check permissions: `hdfs dfs -chmod -R 777 /results` |
| Result CSVs contain `\N` for nulls | Hive's null representation — filter or replace in the dashboard code |
