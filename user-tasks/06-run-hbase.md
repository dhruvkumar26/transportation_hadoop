# Phase 6 – HBase: NoSQL Zone Lookup Demo

**Phase owner:** Manikandan
**Time:** 15–20 minutes.
**Prerequisites:** HBase installed (Phase 1). **Hive stopped** (memory).

## What we're doing

Show HBase as a **random-access NoSQL wide-column store**, complementing Hive's scan-based analytics.

- **Table 1 – `zone_lookup`**: 265 NYC taxi zones, keyed by `LocationID`. Demonstrates fast `get`-by-key that a Hive table can't match at low latency.
- **Table 2 – `trip_by_zone`** (optional bonus): rollup metrics per zone+hour keyed as `<pu_loc_id>_<hour>` (e.g. `132_18` = JFK at 6 PM).

---

## Step 1 — Free RAM first

```bash
jps
```

If Hive is still around (from prior `hive` session leaving the JVM up), open a new terminal and don't run `hive`. Only Hadoop should be running.

Also make sure Hadoop is up:

```bash
$HADOOP_HOME/sbin/start-dfs.sh
$HADOOP_HOME/sbin/start-yarn.sh
jps
```

---

## Step 2 — Start HBase

```bash
start-hbase.sh
sleep 15                # give master time to come up
jps
```

Expected additions:

```
HMaster
HRegionServer
HQuorumPeer
```

Verify with the shell:

```bash
echo "status" | hbase shell 2>/dev/null | tail -5
```

Expected: `1 active master, 0 backup masters, 1 servers, 0 dead, ...`.

Screenshot the HBase Master UI at `http://localhost:16010`: `06-hbase-master.png`.

---

## Step 3 — Create tables

```bash
cd ~/bigdata-assignment/my-work/scripts/hbase
hbase shell create_tables.hbase 2>&1 | tee ~/hbase_create.log
```

Expected end:

```
TABLE
trip_by_zone
zone_lookup
2 row(s) in ... seconds

=> ["trip_by_zone", "zone_lookup"]
```

Screenshot: `06-hbase-list.png`.

---

## Step 4 — Load zones into `zone_lookup`

### 4a. Start the Thrift gateway (needed by happybase)

```bash
hbase-daemon.sh start thrift
```

Check it's listening:

```bash
netstat -tln | grep 9090     # or: ss -tln | grep 9090
```

Should show `LISTEN … 0.0.0.0:9090`.

### 4b. Install happybase

```bash
pip3 install --user happybase
```

### 4c. Run the loader

```bash
python3 load_zones.py /home/hdoop/staging/taxi_zone_lookup.csv
```

Expected:

```
Inserted 265 zones into HBase table `zone_lookup`.

GET zone_lookup, '132':
  info:borough = Queens
  info:zone_name = JFK Airport
  info:service_zone = Airports
```

Screenshot: `06-hbase-load.png`.

---

## Step 5 — Show off HBase reads (viva ammo)

### 5a. Point get — the fast case

```bash
hbase shell <<'EOF'
get 'zone_lookup', '132'
get 'zone_lookup', '138'
get 'zone_lookup', '1'
EOF
```

Manhattan CBD hotspot vs airports vs Newark. Screenshot: `06-hbase-gets.png`.

### 5b. Scan with a filter

```bash
hbase shell <<'EOF'
scan 'zone_lookup', { COLUMNS => 'info:borough', FILTER => "SingleColumnValueFilter('info','borough',=,'binary:EWR')" }
EOF
```

Should return exactly the Newark row. Screenshot: `06-hbase-filter.png`.

### 5c. Table count

```bash
echo "count 'zone_lookup'" | hbase shell 2>/dev/null | tail -3
```

Expected: `265 row(s)`.

---

## Step 6 — Load top-hour stats into `trip_by_zone` (optional but recommended)

This demonstrates how you'd store precomputed analytics keyed for real-time serving.

```bash
cat > /tmp/load_trip_by_zone.py <<'PY'
import csv, happybase, sys

conn  = happybase.Connection("127.0.0.1", 9090)
table = conn.table("trip_by_zone")

# The exported Hive q1_hotspots.csv has: pickup_hour, pu_borough, pu_zone, trips
with open("/home/hdoop/bigdata-assignment/my-work/dashboard/data/q1_hotspots.csv") as f:
    r = csv.reader(f)
    n = 0
    with table.batch(batch_size=200) as b:
        for row in r:
            if len(row) < 4: continue
            hour, borough, zone, trips = row
            key = f"{zone.replace(' ','_')}_{int(hour):02d}".encode()
            b.put(key, {
                b"stats:trips":   trips.encode(),
                b"stats:borough": borough.encode(),
                b"stats:zone":    zone.encode(),
            })
            n += 1
    print(f"Wrote {n} rows to trip_by_zone")
conn.close()
PY

python3 /tmp/load_trip_by_zone.py
```

Then in HBase shell:

```bash
hbase shell <<'EOF'
scan 'trip_by_zone', {LIMIT => 5}
EOF
```

Screenshot: `06-hbase-trip-by-zone.png`.

---

## Step 7 — Stop the Thrift gateway (optional, tidy)

```bash
hbase-daemon.sh stop thrift
```

Keep HBase itself running only if the next demo needs it; otherwise `stop-hbase.sh`.

---

## Explaining HBase in the viva (Manikandan's angle)

- **HBase = distributed sorted map**. Keys are lexicographically ordered → range scans are cheap on adjacent keys.
- **Column families** are physically separate stores; that's why we defined `info` and `stats` separately.
- **Rows have no fixed schema** beyond family names — different rows can have different columns.
- **When would you use HBase over Hive?** When you need **milliseconds-per-key lookup** for a live service — a rider app querying "what's the busiest zone right now near me?" HBase is designed for that. Hive is for batch analytics.
- **When would you use both?** In the same architecture, Hive runs the heavy periodic aggregation → results loaded into HBase for the front-end to serve — which is exactly what our optional Step 6 demonstrated.

---

## What to send back to Claude

1. Output of `list` in HBase shell.
2. Output of one `get 'zone_lookup', '132'`.
3. `count 'zone_lookup'` output.
4. Screenshot of Master UI (or its text: `http://localhost:16010/master-status`).

Once clean, next: **`07-dashboard.md`**.

---

## Reproduce checklist

- [ ] `start-hbase.sh` brings up HMaster, HRegionServer, HQuorumPeer.
- [ ] `list` shows `zone_lookup` and `trip_by_zone`.
- [ ] Thrift gateway on 9090 reachable.
- [ ] happybase installed.
- [ ] 265 rows inserted into `zone_lookup`.
- [ ] `get 'zone_lookup','132'` returns JFK data.
- [ ] Optional: trip_by_zone loaded from q1 export.
- [ ] Screenshots captured.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| HMaster not in `jps` after 30 s | Check `$HBASE_HOME/logs/hbase-hdoop-master-*.log` — usually port already in use or HDFS not up |
| `KeeperException$ConnectionLossException` | ZooKeeper crashed — try `stop-hbase.sh && start-hbase.sh` |
| `TTransportException: Could not connect to 127.0.0.1:9090` | Thrift gateway not started — `hbase-daemon.sh start thrift` |
| `ImportError: No module named happybase` | `pip3 install --user happybase` |
| Insert throws `RegionTooBusyException` | 4 GB VM under memory pressure — stop other daemons (Hive, extra terminals) |
| `PleaseHoldException: Master is initializing` | Wait ~30 s after `start-hbase.sh` before running commands |
