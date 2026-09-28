# Phase 3 – Pig ETL: Clean & Enrich Trips

**Phase owner:** M4
**Time:** 15–25 minutes (two MR jobs).
**Prerequisites:** Data in `/raw/` (Phase 2 complete). Hadoop up.

## What we're doing

Two Pig Latin scripts, run one after the other:

| Script | Role | HDFS output |
|---|---|---|
| `01_clean_trips.pig` | Read 9M raw CSV rows, drop bad data, project to same 19 cols | `/clean/trips/` |
| `02_enrich_trips.pig` | Add derived columns (hour/day/duration/tip%) + JOIN zone lookup for pickup borough/zone | `/clean/trips_enriched/` |

Both scripts compile to MapReduce jobs. **You'll see them appear in the YARN UI at `http://localhost:8088` — screenshot them for evidence.**

---

## Step 1 — Pull scripts

```bash
cd ~/bigdata-assignment
git pull
```

Scripts live at:
- `my-work/scripts/pig/01_clean_trips.pig`
- `my-work/scripts/pig/02_enrich_trips.pig`

---

## Step 2 — Confirm Pig can talk to HDFS

```bash
pig -x mapreduce -e "ls /raw"
```

Expected: lists `hdfs://127.0.0.1:9000/raw/trips` and `.../raw/zone_lookup`.

If you get `Could not resolve LzoCodec`, ignore — Pig warns but continues.

---

## Step 3 — Run `01_clean_trips.pig`

```bash
cd ~/bigdata-assignment/my-work/scripts/pig
# Clear any prior clean output (Pig refuses to overwrite)
hdfs dfs -rm -r -f /clean

pig -x mapreduce -f 01_clean_trips.pig 2>&1 | tee ~/pig_01.log
```

You'll see output like:

```
Pig Stack Trace ... (nothing scary at start)
Connecting to cluster
...
JobId  Alias   Feature   Records ...
job_1234567890_0001   raw,clean   HASH_JOIN   ...
Successfully stored 8,900,000+ records in: "hdfs://127.0.0.1:9000/clean/trips"
```

Runtime: **8–12 minutes** on the 4 GB VM.

### Verify

```bash
hdfs dfs -du -h /clean
hdfs dfs -ls /clean/_counts/raw     /clean/_counts/clean
hdfs dfs -cat /clean/_counts/raw/part-*     ; echo
hdfs dfs -cat /clean/_counts/clean/part-*   ; echo
```

Expected:
- `/clean/trips` has 2–3 part files, total ~700 MB.
- `_counts/raw` shows total raw rows (~9.3 M).
- `_counts/clean` shows survivors (typically ~90 % → ~8.4 M).

Compute drop rate for the report:

```bash
raw=$(hdfs dfs -cat /clean/_counts/raw/part-*   | tr -d ,)
cln=$(hdfs dfs -cat /clean/_counts/clean/part-* | tr -d ,)
awk -v r=$raw -v c=$cln 'BEGIN { printf "Rows kept: %d / %d  (%.2f%%)\n", c, r, c*100.0/r }'
```

Screenshot: `03-pig-clean-summary.png` (the last ~15 lines of `pig_01.log` + drop-rate).

---

## Step 4 — Run `02_enrich_trips.pig`

```bash
pig -x mapreduce -f 02_enrich_trips.pig 2>&1 | tee ~/pig_02.log
```

Runtime: **6–10 minutes**. Multiple MR jobs will run (a chain: parse → JOIN with zone lookup → project → store).

### Verify

```bash
hdfs dfs -du -h /clean/trips_enriched
hdfs dfs -cat /clean/trips_enriched/part-* | head -3
```

Expected head row (18 comma-separated fields):

```
2,2024-01-01 00:57:55,0,1,1,2024,19.8,1.0,1.72,186,Manhattan,Penn Station/Madison Sq West,79,2,17.7,0.0,22.70,0.0
1,2024-01-01 00:03:00,0,1,1,2024,6.6,1.0,1.80,140,Manhattan,Lenox Hill East,236,1,10.0,3.75,18.75,37.5
...
```

Fields (in order): `vendor_id, pickup_dt, pickup_hour, pickup_day, pickup_month, pickup_year, duration_min, passenger_count, trip_distance, pu_loc_id, pu_borough, pu_zone, do_loc_id, payment_type, fare_amount, tip_amount, total_amount, tip_pct`.

---

## Step 5 — Capture YARN evidence

Open `http://localhost:8088` (Firefox in the VM).

- **All Applications** → you should see 4–6 SUCCEEDED entries for `PigLatin:01_clean_trips.pig` and `PigLatin:02_enrich_trips.pig`.
- Click one → screenshot the **Counters** page:
  - `03-yarn-pig-app.png` — the app list
  - `03-yarn-pig-counters.png` — one job's counters showing `Launched map tasks` / `Launched reduce tasks`

---

## Step 6 — Explain in your own words (for the viva)

Read this once so you can defend it:

- **Pig Latin is a dataflow language**. Each `LOAD`, `FILTER`, `FOREACH`, `JOIN`, `STORE` is a step in a DAG.
- **The Pig runtime turns this DAG into MapReduce jobs**. Filters and projections become map-side operations; JOINs become shuffle+reduce operations.
- You can see this by asking Pig: `pig -x mapreduce -e "explain -script 02_enrich_trips.pig;"` — outputs the physical MR plan.
- Because of this compilation, running one Pig script triggers **multiple MR jobs**. That's what you see in the YARN UI.

---

## What to send back to Claude

1. Last 20 lines of `~/pig_01.log` (final "Successfully stored ... records").
2. Last 20 lines of `~/pig_02.log`.
3. Output of the drop-rate awk in Step 3.
4. `hdfs dfs -cat /clean/trips_enriched/part-* | head -3`
5. Any error stack trace.

Once clean, next up: **`04-run-mapreduce.md`** (native Streaming MR).

---

## Reproduce checklist

- [ ] `01_clean_trips.pig` succeeded; `/clean/trips` populated.
- [ ] `_counts/raw` and `_counts/clean` both non-empty.
- [ ] Drop rate is 5–15 % (higher means our filters are too aggressive — investigate before proceeding).
- [ ] `02_enrich_trips.pig` succeeded; `/clean/trips_enriched` populated.
- [ ] `head` of enriched output shows readable borough/zone names.
- [ ] YARN UI shows Pig applications SUCCEEDED.
- [ ] Screenshots captured.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Output directory ... already exists` | `hdfs dfs -rm -r -f /clean` and re-run |
| Pig hangs at 0 % progress | YARN might be starved — check `yarn node -list`; RAM should be 2048 MB per Phase 0.5 config |
| `ToDate error` in enrich phase | A row has an unparseable timestamp — should be rare after Phase 1's filter; check `pig_02.log` for the offending row and add its condition to `01_clean_trips.pig` filter |
| Zone JOIN produces `Unknown` for many rows | Header row of zone lookup was not filtered — inspect `head -1` of `/raw/zone_lookup/*.csv`; the MATCHES regex in `02_enrich_trips.pig` should skip it |
| `Container killed by ResourceManager. Exit code 143` | Container memory too small — bump `mapreduce.map.memory.mb` from 512 → 768 in `mapred-site.xml`, then restart YARN |
| `java.io.IOException: Not a file: ... _counts` | You ran the second Pig script before the first finished writing `_counts` dirs — wait for job to fully complete |
