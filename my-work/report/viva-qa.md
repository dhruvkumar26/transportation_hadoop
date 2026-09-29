# Viva Q&A Bank

**Course:** CC ZG522 · Big Data Systems · Assignment 1
**Format:** 2–3 minutes viva after the 5-min presentation. Faculty may cold-call any member.

**Rule of thumb:** every member should be able to answer any question in the "Common" section. Section-specific questions may go to the phase owner but every member should have ~60 % of a good answer.

---

## Common — everyone must know these cold

### Q1. Why did you pick the Transportation domain, and specifically NYC taxi data?

Because the NYC TLC public dataset is one of the largest continuously-published transportation datasets in the world — 4+ billion trips since 2009 — and it's a canonical Big Data workload used by ride-hail firms, city planners, and academic researchers. It's structured, well-documented, has a real veracity story (dirty rows, edge cases), and drives concrete real-world decisions (dispatch, pricing, congestion policy).

### Q2. What is "Big Data" in this project? Why can't a normal database do it?

Big Data here isn't about the row count alone — it's about the *combination* of: ~10 M rows per month growing to billions, analytical scans (not point queries) over the full history, high-cardinality group-by (PU zone × DO zone × hour = 1.7 M groups), multi-source enrichment, and needing to support batch analytics AND millisecond serving simultaneously. A single-node RDBMS could do any one of these; the combination requires distributed storage + distributed processing, which is what Hadoop provides.

### Q3. Walk me through the 5 Vs for this dataset.

- **Volume**: 9.55 M rows / 985 MB for 3 months; scales linearly to 40 M/year, billions lifetime.
- **Velocity**: monthly batch drops from the TLC portal; our HDFS is partitioned by year/month to mirror that cadence.
- **Variety**: structured trip fact + zone dimension + optional weather; joined via Pig.
- **Veracity**: real messy data — Pig ETL dropped 11.25 % of rows (bad fares, zero distance, missing zones).
- **Value**: five distinct business decisions the pipeline informs (dispatch, pricing, congestion, airport strategy, fintech).

### Q4. Draw or describe the architecture in one minute.

TLC portal → `curl` download → parquet-to-CSV → `hdfs dfs -put` into `/raw/`. Pig ETL cleans + enriches into `/clean/trips_enriched/`. In parallel, a native Streaming MR job computes `(zone, hour) → count`. Hive external table on the enriched data runs 5 analytical queries into `/results/hive/`. HBase stores the zone dimension for random-access lookup. `hdfs dfs -getmerge` pulls CSVs to local disk; Streamlit renders 5 interactive charts.

### Q5. What are the seven Hadoop daemons your `jps` shows, and what does each do?

- **NameNode** — filesystem metadata (which blocks make up which file, permissions, inode-like tree).
- **DataNode** — stores the actual 128 MB blocks on disk, replies to read/write requests.
- **SecondaryNameNode** — periodically merges edit logs into the fsimage; **NOT** a hot failover.
- **ResourceManager** — YARN's central scheduler; decides which app gets which container.
- **NodeManager** — YARN's per-node worker; runs containers on behalf of the RM.
- **JobHistoryServer** — post-mortem MR job counter storage (port 10020 IPC, 19888 web).
- **HMaster** (only when HBase is running) — HBase's coordinator; hosts the meta table.

---

## HDFS / Storage

### Q6. Why replication factor 1?

Because we're on a single-node pseudo-cluster — there's only one DataNode, so multiple replicas of the same block would sit on the same disk (useless for fault tolerance) and waste space. In real production with N nodes, replication ≥ 3 is the norm.

### Q7. What is the block size and why does it matter?

Default 128 MB. Two reasons: (1) minimizes NameNode metadata overhead — a 1 TB file at 128 MB blocks is 8000 metadata entries, at 4 KB blocks it's 250 million; (2) maximizes throughput per map task — each mapper processes one block, so bigger blocks mean less scheduling overhead per byte of data.

### Q8. What is `fs.defaultFS` and where is it configured?

It's the URI of the default filesystem (`hdfs://127.0.0.1:9000` for us), set in `core-site.xml`. Every Hadoop tool defaults to this filesystem when you give a relative path.

### Q9. What did `hdfs fsck /raw` tell you?

Status HEALTHY, replication factor 1, 0 under-replicated or missing blocks, average block size around 128 MB. That's the health check for HDFS storage.

---

## Processing — Pig

### Q10. What does Pig give you over raw MapReduce?

A declarative dataflow language (Pig Latin) that compiles to MR jobs. `01_clean_trips.pig` is 45 lines of Pig; the equivalent raw MR Java job would be 300+ lines (mapper class, reducer class, driver, custom writables). Pig also does multi-query optimization — our Phase 3.1 collapsed 3 logical steps into 1 MR job.

### Q11. Show me where in the log Pig proves it's running MR.

`Stage-Stage-1: Map: N Reduce: M` and `HadoopJobId: job_1790615823781_XXXX` — both come straight from the YARN Resource Manager. Also `PigLatin:02_enrich_trips.pig` shows up as a MAPREDUCE application in the RM UI.

### Q12. What was your drop rate in cleansing and why did rows get dropped?

**11.25 %** — from 9,554,778 raw rows to 8,479,421 clean. Rules: `passenger_count >= 1`, `trip_distance > 0 AND < 100`, `fare_amount > 0 AND < 500`, non-null zone IDs, `total_amount > 0`. These filter data-entry errors, refund records, and impossible trips (100 mile taxi in NYC = GPS glitch).

### Q13. Why did you do the zone JOIN in Pig and not Hive?

Two reasons: (1) the JOIN produces the *enriched* dataset that becomes the single source of truth for Hive's external table — we did it once in Pig instead of in every Hive query. (2) Pig's `HASH_JOIN` is explicit — you can see it in the MR plan — while Hive's optimizer sometimes rewrites joins in ways that hide the mechanism.

---

## Processing — Native MapReduce

### Q14. Walk me through the map, shuffle, and reduce phases of your streaming job.

- **Map**: mapper.py reads each cleaned trip row (comma-separated), extracts `PULocationID` at column 7 and hour at chars 11–13 of the pickup timestamp, and emits `<pu_loc_id>\t<hour>\t1` to stdout. Custom counters increment `Rows OK` or `Rows BAD` via `reporter:counter:…` on stderr.
- **Shuffle**: Hadoop partitions rows across reducers by the composite key `(pu_loc_id, hour)` — we configured this with `stream.num.map.output.key.fields=2` and `KeyFieldBasedPartitioner`. Rows sharing that key land on the same reducer, sorted contiguously.
- **Reduce**: reducer.py detects key boundaries via `current_key` tracking. Within each boundary, sums the 1's. Emits `<pu_loc_id>\t<hour>\t<count>`.

### Q15. Why did you set `stream.num.map.output.key.fields=2`?

Because Hadoop Streaming defaults to using only the first tab-separated field as the shuffle key. Our mapper emits three fields (pu_loc_id, hour, 1) — with the default, shuffle would group by pu_loc_id alone, and rows within a reducer would not be sorted by hour. The reducer would emit partial groups every time hour changed. Setting `=2` makes the first two fields form the composite key, giving correct grouping. We hit this bug the first time; output had 6.7 M rows instead of 5,421. Fixed with a one-line config change and re-ran in 35 seconds.

### Q16. Why 2 reducers and not 1 or 100?

`mapreduce.job.reduces=2` — with 5,421 output groups and ~90 MB shuffle bytes, a single reducer would work but takes longer; 100 would spend more time in scheduling overhead than in real work. 2 balances parallelism with our 2 GB YARN memory budget.

### Q17. What are your custom counters for and how are they emitted?

`Rows OK` and `Rows BAD` in the `Custom` group. Hadoop Streaming reads lines from stderr starting with `reporter:counter:` — our mapper emits `reporter:counter:Custom,Rows OK,N` at end of processing. They show up in the YARN UI counters page as evidence that we understand Hadoop's out-of-band metric protocol.

---

## Analytics — Hive

### Q18. Why Hive over a real RDBMS like PostgreSQL for the 5 queries?

Same reason as Q2 but sharpened: our queries scan 8.48 M rows and produce results in 60–90 seconds *on a 4 GB VM*. On 40 M rows (1 year) a properly indexed Postgres would still work but each query would cost minutes. At 400 M / 4 B, Postgres falls off the cliff. Hive gets slower linearly because it fans out across YARN — add nodes to a real cluster and it stays fast.

### Q19. What's the difference between an external table and a managed table in Hive?

An **external table** points at an HDFS location Hive doesn't own — DROP TABLE removes the metadata only. We use this for `fact_trips` which points at Pig's `/clean/trips_enriched/`. A **managed table** puts data inside `/user/hive/warehouse/…`; DROP TABLE deletes the data too. We use this for `dim_zone` and the 5 ORC result tables.

### Q20. Why ORC for the result tables and TEXTFILE for the source?

ORC is columnar and heavily compressed — the 5 result tables total a few MB. TEXTFILE is what Pig writes (comma-separated); reading it into a fact_trips external table is zero-copy. If we were querying `fact_trips` many times, we'd convert it to ORC too — but each query only runs once.

### Q21. Show me your EXPLAIN plan. What are the stages?

The `EXPLAIN` from `02_analytics.sql` shows `STAGE DEPENDENCIES: Stage-1 is a root stage; Stage-0 depends on Stage-1`. Stage-1 is a MapReduce stage with a `TableScan` operator on `fact_trips`, then a `Group By` operator, then a `Reduce Output` operator. Stage-0 is the final `Fetch` back to the client.

### Q22. The Hive doc had a "duplicate ConnectionURL" trap that broke your metastore. What was the fix?

Root cause: our first `hive-site.xml` copied `hive-default.xml.template` and added properties on top. The template already declared `javax.jdo.option.ConnectionURL` with a relative-path Derby URL. Hadoop XML is *last-property-wins*, so the template's relative path silently overrode our absolute path, and Derby created empty `metastore_db/` folders in every cwd. `SHOW DATABASES` still worked because it auto-creates minimal tables, but real CREATE/INSERT hit `Required table missing: VERSION`. Fix: replace `hive-site.xml` with a minimal single-property file (only one `ConnectionURL`), nuke all stray `metastore_db/` dirs, re-run `schematool -dbType derby -initSchema`. The docs in `user-tasks/01-…md` were then hardened so no future member hits it.

---

## Serving — HBase

### Q23. Why HBase in addition to Hive?

Different access pattern. Hive is scan-based analytics — 60-second latency, batch. HBase is `get`-by-key random access — sub-millisecond. A live dispatch app querying "what's the busiest zone right now" hits HBase; the weekly executive dashboard hits Hive. Same data, two engines.

### Q24. What's your HBase row-key strategy?

`zone_lookup` uses the LocationID as the row key (stringified). `trip_by_zone` uses `<zone_name>_<hour_padded>` (e.g. `Midtown_Center_18`). Both are chosen for lookup efficiency — `get` by exact key is O(1), and lexicographic sorting means adjacent keys can be scanned together (e.g. all Midtown Center hours in a range scan).

### Q25. Column families — what are they and why did you split `stats` and `top_do`?

Column families are physically-separate stores in HBase (each has its own files under `/hbase/data/…`). Rows share row keys across families but the data on disk is separate. We split `stats` (numeric metrics like `trips`, `avg_fare`) from `top_do` (a JSON blob of top destinations) because they have different access patterns — a small metrics read doesn't need to load the larger JSON blob.

### Q26. How did the Python client (happybase) talk to HBase?

Through the **Thrift gateway** — we started `hbase-daemon.sh start thrift`, which opens a Thrift server on port 9090. happybase's `Connection('127.0.0.1', 9090)` speaks Thrift. HBase Java clients bypass Thrift and talk the native protocol directly, but for Python + demos, Thrift is standard.

---

## Presentation — Streamlit + KPIs

### Q27. Why Streamlit and not Tableau / Power BI?

Streamlit is Python-native, reads local CSVs, gives us interactive controls (sliders, radios) in < 200 lines of Python, and needs no license. Tableau/Power BI are stronger for corporate BI but overkill for this demo and would break the "everything in Python" story of the rest of the stack.

### Q28. Walk me through the dashboard KPIs.

- **Total Trips: 8,479,421** — matches the enriched fact table rowcount exactly (proves the pipeline is lossless from HDFS to display).
- **Total Revenue: $235.12 M** — Q2's revenue_usd summed.
- **Average Fare: $33.70** — Q2's avg_fare averaged across rows.
- **Average Tip: 4.7 %** — Q2's avg_tip_pct averaged (low because cash tips aren't recorded, and payment_type=2 rows show 0% tip).

### Q29. Is the dashboard reading Hive live?

No — it reads the CSV files we exported from Hive to `dashboard/data/` via `hdfs dfs -getmerge`. Rationale: the 4 GB VM can't run Hadoop + Hive + Streamlit + Firefox simultaneously. In production you'd use `pyhive` to hit HiveServer2 directly and skip the export.

### Q30. What did you learn from Q5 (payment share)?

Staten Island is a payment outlier — 31.1 % cash vs the ~15 % city average. That's a real fintech insight: POS-terminal deployment strategy, cash-handling policy, tax reporting all differ for Staten Island. The other boroughs cluster around 80–90 % card.

---

## Adversarial / harder questions

### Q31. Why not just use Spark for the whole pipeline?

Three reasons. (1) Spark's in-memory design would OOM the 4 GB VM — YARN's memory-safe MR fits better. (2) Spark hides the shuffle mental model behind Catalyst; the assignment explicitly targets demonstrating MR concepts. (3) We wanted to show the *classic* Hadoop stack (Pig, Hive, HBase, native MR) because that's what the syllabus grades on. In a real production project on bigger hardware, Spark would replace MR-Pig-Hive with a single engine.

### Q32. If you had 100 nodes instead of 1, what changes?

- HDFS `dfs.replication` goes from 1 to 3.
- YARN memory per node stays 2 GB in dev; a real prod node is 64+ GB and hosts hundreds of containers per job.
- Pig / Hive queries stay identical — the framework scales the same script.
- Streaming MR stays identical.
- HBase moves from standalone to distributed mode — split the RegionServer across all nodes, use HDFS for the WAL.

### Q33. What happens if the NameNode dies?

In our pseudo-cluster, everything stops — the SecondaryNameNode is *not* a hot failover, it just periodically merges the edit log with the fsimage to speed up NN restarts. In a real HA setup you'd run two NameNodes (active + standby) sharing state via QJM (a JournalNode quorum) and a ZooKeeper-based failover controller.

### Q34. Explain the 11.25 % drop rate — could you have kept more?

Possibly. Our filters are conservative:
- Some negative `fare_amount` rows are legitimate refund records; we drop them because they'd skew revenue queries. A better design would tag them and let each query decide.
- `passenger_count = 0` is often the meter defaulting; some legitimate solo trips get dropped.
- We could have gained ~2 percentage points back by keeping "zero-distance but non-zero-fare" rows (probably no-shows or cancellation fees). Not worth complicating the demo.

### Q35. What was the hardest bug you hit?

Three candidates:
1. **Arm64 vs amd64 Java paths** — the VM was ARM64 (Apple Silicon host), but `~/.bashrc` had amd64 in JAVA_HOME. Hadoop worked because `hadoop-env.sh` had the right arm64 path; HBase failed hard because it took JAVA_HOME literally. Fix: auto-detect via `dpkg --print-architecture`.
2. **Duplicate Hive ConnectionURL** — described above. Silent override → Derby side-databases in every cwd.
3. **Composite-key streaming shuffle** — described above. 6.7 M output rows instead of 5,421.

All three are documented in the `user-tasks/` MDs so future team members can't hit them.

### Q36. If a faculty member scales this to a full year (40 M rows), what breaks first?

- Local staging disk would need ~4 GB (currently 60 GB VM has 54 GB free — fine).
- Pig ETL runtime grows linearly, maybe 30 minutes total.
- Hive query runtimes grow linearly too, maybe 15 minutes each.
- **YARN memory-mb would be the pinch** — 2 GB budget starts to force more container spills. Bumping the VM to 6 GB RAM would keep the pipeline smooth.

### Q37. Everyone on this team is technical — how did you split the work?

Dhruv (Group Leader) — env setup + report compilation.
Manikandan (Presentation Coordinator) — HBase phase + deck + viva.
Sai Krishna Mohan — data ingestion + native MR.
Ramya — Pig ETL.
Sri Lalithya — Hive analytics.
Vishwa — Streamlit dashboard.
Each member owns one theory section of Part A too. Screenshots captured by phase owner but reproduced by all others on their own VMs for viva readiness.

### Q38. Show me one concrete business decision this pipeline enables.

"At 18:00 on weekdays, Midtown Center hits 38,756 trips per quarter. If we assume 90-day quarters and 5 work-days in 7, that's ~600 trips per weekday-6PM-hour in Midtown Center alone. A dispatch operator should hold ~10 % of the fleet within 5 blocks of Times Square between 17:00 and 20:00. That's a real, testable operational policy generated from one query on our Hive layer."

---

## Meta

### Q39. What would you do differently next time?

- Start with more RAM (8 GB would let Hive + HBase co-exist).
- Move to Spark for a 5-6× speedup on the ETL.
- Add live weather data as a second source to make Variety more visible.
- Use a shared cloud VM instead of 6 separate VMs — collaboration friction would go from N to 1.
- Automate the pipeline into a single `make pipeline` — currently each phase is manual.

### Q40. Is the pipeline reproducible?

Yes. Everything except the raw dataset is in the git repo (scripts, configs, docs). The dataset is public and re-downloadable in 20 minutes. A new team member can clone the repo and run through `user-tasks/00-…md` through `07-…md` end-to-end. That's the intent of every phase MD being reproducible.
