# Phase 4 – Native MapReduce (Hadoop Streaming, Python)

**Phase owner:** M3
**Time:** 5–10 minutes.
**Prerequisites:** `/clean/trips` populated by Phase 3.

## Why this phase exists

Pig and Hive both compile to MapReduce internally — so technically every previous MR job you saw in the YARN UI *is* MapReduce. But the assignment specifically calls out demonstrating **understanding of MapReduce workflow**. Writing a mapper + reducer by hand makes that concrete: it forces us to specify exactly what the map phase emits, what the shuffle phase groups by, and what the reduce phase aggregates.

**Job we run:** *Trips-per-zone-per-hour.*
- Mapper reads each cleaned trip and emits `(PULocationID, hour_of_day) → 1`
- Shuffle groups all identical keys together
- Reducer sums the 1s per key → total trips at that zone during that hour

This is the taxi-industry equivalent of WordCount but with a real business question ("when is each zone busy?").

---

## Step 1 — Pull scripts

```bash
cd ~/bigdata-assignment && git pull
```

Files:
- `my-work/scripts/mapreduce/mapper.py`
- `my-work/scripts/mapreduce/reducer.py`
- `my-work/scripts/mapreduce/run.sh`

Make executable:

```bash
chmod +x my-work/scripts/mapreduce/*.py my-work/scripts/mapreduce/run.sh
```

---

## Step 2 — Dry-run locally (fast sanity check, no cluster)

Run the mapper + reducer on a small local sample to prove they work before submitting to YARN:

```bash
cd ~/bigdata-assignment/my-work/scripts/mapreduce
hdfs dfs -cat /clean/trips/part-* 2>/dev/null | head -100 \
    | python3 mapper.py \
    | sort \
    | python3 reducer.py \
    | head -20
```

Expected: tab-separated rows like

```
132	09	4
132	10	7
132	11	6
138	14	3
...
```

If this works, the cluster run will too.

---

## Step 3 — Submit the streaming job

```bash
cd ~/bigdata-assignment/my-work/scripts/mapreduce
./run.sh 2>&1 | tee ~/mr_run.log
```

Watch for:

```
→ Submitting streaming job...
  jar    : /home/hdoop/hadoop-3.2.1/share/hadoop/tools/lib/hadoop-streaming-3.2.1.jar
  mapper : .../mapper.py
  reducer: .../reducer.py
  input  : /clean/trips
  output : /results/trips_per_zone_hour

packageJobJar: [...] [...] /tmp/streamjob....jar
...
map 0% reduce 0%
map 21% reduce 0%
...
map 100% reduce 100%
Job job_1234567890_0007 completed successfully
```

At the end you'll see:

```
→ First 10 lines of output:
1	00	312
1	01	145
1	02	87
...
→ Line count in output:
6360
✅ Streaming job done.
```

The **6360** count = 265 zones × 24 hours (with some sparse combos missing).

---

## Step 4 — Screenshot YARN counters

`http://localhost:8088` → the `TripsPerZonePerHour` app → **Counters**.

- Important counters to capture: `Launched map tasks`, `Launched reduce tasks`, `Map input records`, `Reduce output records`, and our custom `Custom.Rows OK` / `Custom.Rows BAD` (from `mapper.py`'s `reporter:counter:` lines).

Screenshots:
- `04-yarn-mr-app-list.png`
- `04-yarn-mr-counters.png`

---

## Step 5 — Read a few rows from HDFS

```bash
hdfs dfs -cat /results/trips_per_zone_hour/part-* | sort -t $'\t' -k3 -nr | head -20
```

Top rush-hour hotspots. Screenshot: `04-top-hotspots.png`.

---

## Step 6 — Explain in your own words (viva)

For the viva Q&A:

- **Why `PULocationID`+hour as the key?** Because we want the count at exactly that granularity. Anything you group by in aggregation *is* the key.
- **What does shuffle do?** It routes all values sharing the same key to the same reducer. Guarantees the reducer sees each key contiguously.
- **Why does the reducer track `current_key`?** Because Streaming feeds lines sequentially; the reducer must detect key boundaries itself (unlike Java MR which gets an `Iterable<Value>` per key).
- **Why did we set `-D mapreduce.job.reduces=2`?** With 8 M input records and small output volume, 2 reducers is enough. 1 would work; more would just add overhead.

---

## What to send back to Claude

1. Last 30 lines of `~/mr_run.log` (should include the Counters block).
2. Output of Step 5 (top 20 busiest zone-hours).
3. Screenshot of the YARN counters page (attach or paste OCR).

Once clean, next: **`05-run-hive.md`**.

---

## Reproduce checklist

- [ ] Dry-run pipeline works locally (Step 2).
- [ ] Streaming job SUCCEEDED in YARN.
- [ ] `/results/trips_per_zone_hour` has non-empty part files.
- [ ] Custom counters `Rows OK` and `Rows BAD` visible.
- [ ] Top-20 hotspots reasonable (Manhattan zones dominate; JFK/LGA also high).
- [ ] Screenshots captured.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `hadoop-streaming.jar not found` | `find $HADOOP_HOME -name 'hadoop-streaming-*.jar'` — path in the `run.sh` should be correct for 3.2.1 |
| `Error: java.io.IOException: Broken pipe` | Usually harmless — a mapper emitted more than the reducer read; unrelated to correctness |
| `Permission denied: python3: /home/…mapper.py` | The `-files` argument copied the file but shebang line is missing. `run.sh` invokes with explicit `python3 mapper.py`, so this shouldn't happen. |
| Reducer emits `_SUCCESS` only, no data | Mapper filtered everything as BAD — check `Custom.Rows OK` counter, likely field count issue |
| Job stuck at `map 0 % reduce 0 %` for >2 min | YARN memory pressure — `yarn node -list -showDetails` should show `2048 MB` available |
