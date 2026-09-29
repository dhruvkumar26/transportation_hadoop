# Phase 2 – Download NYC Taxi Data + HDFS Ingestion

**Phase owner:** Sai Krishna Mohan
**Time:** 20–30 minutes (mostly network-bound).
**Prerequisites:** Hadoop up (`jps` shows NN, DN, SNN, RM, NM).

## What we're doing

1. Downloading 3 months of NYC TLC Yellow Taxi data (Jan/Feb/Mar 2024) and the taxi zone lookup.
2. Converting each monthly Parquet to a headerless CSV.
3. Uploading everything into HDFS with a `year=/month=` partition layout that Hive will pick up in Phase 5.

Expected sizes on completion:
- Local staging: **~1.1 GB** (Parquet + CSV)
- HDFS `/raw`: **~920 MB** (CSV only)

---

## Step 1 — Pull scripts from the shared repo

```bash
cd ~
git clone <YOUR-GIT-REPO-URL> bigdata-assignment    # first time only
# OR
cd ~/bigdata-assignment && git pull
```

The scripts we'll use live at:

- `my-work/scripts/ingest/download_and_ingest.sh`
- `my-work/scripts/ingest/parquet_to_csv.py`

Make the shell script executable:

```bash
chmod +x ~/bigdata-assignment/my-work/scripts/ingest/download_and_ingest.sh
```

---

## Step 2 — Confirm Hadoop is healthy

```bash
jps
hdfs dfs -ls /
```

Expected `jps`:

```
NameNode
DataNode
SecondaryNameNode
ResourceManager
NodeManager
Jps
```

If anything missing, `$HADOOP_HOME/sbin/start-dfs.sh && $HADOOP_HOME/sbin/start-yarn.sh`.

---

## Step 3 — Install pyarrow (one-time)

```bash
pip3 install --user pyarrow pandas
python3 -c "import pyarrow; print(pyarrow.__version__)"
```

Expected: version string (e.g. `21.0.0`). If `pip3` missing:

```bash
sudo apt install -y python3-pip
```

---

## Step 4 — Run the ingest script

```bash
cd ~/bigdata-assignment
./my-work/scripts/ingest/download_and_ingest.sh
```

The script:
1. Downloads `taxi_zone_lookup.csv` (~12 KB)
2. Downloads three monthly parquet files (~48 MB each)
3. Converts each parquet to headerless CSV (~305 MB each)
4. `hdfs dfs -put` everything to `/raw/...`

Watch for progress lines like:

```
→ Downloading yellow_tripdata_2024-01.parquet...
→ Converting … → CSV...
    200,000 / 2,964,624 rows  (  6.7%)
    400,000 / 2,964,624 rows  ( 13.5%)
    ...
```

Total runtime: **10–20 minutes** on a home broadband connection.

---

## Step 5 — Verify HDFS state

```bash
hdfs dfs -ls -R /raw | head -20
```

Expected:

```
drwxr-xr-x   - hdoop supergroup  0 ... /raw/trips
drwxr-xr-x   - hdoop supergroup  0 ... /raw/trips/year=2024
drwxr-xr-x   - hdoop supergroup  0 ... /raw/trips/year=2024/month=01
-rw-r--r--   1 hdoop supergroup  ~307MB ... /raw/trips/year=2024/month=01/yellow_tripdata_2024-01.csv
drwxr-xr-x   - hdoop supergroup  0 ... /raw/trips/year=2024/month=02
-rw-r--r--   1 hdoop supergroup  ~305MB ... /raw/trips/year=2024/month=02/yellow_tripdata_2024-02.csv
drwxr-xr-x   - hdoop supergroup  0 ... /raw/trips/year=2024/month=03
-rw-r--r--   1 hdoop supergroup  ~350MB ... /raw/trips/year=2024/month=03/yellow_tripdata_2024-03.csv
drwxr-xr-x   - hdoop supergroup  0 ... /raw/zone_lookup
-rw-r--r--   1 hdoop supergroup  ~12KB ... /raw/zone_lookup/taxi_zone_lookup.csv
```

```bash
hdfs dfs -du -h /raw
```

Expected (approx):

```
307.0 M  307.0 M  /raw/trips/year=2024/month=01
305.5 M  305.5 M  /raw/trips/year=2024/month=02
350.0 M  350.0 M  /raw/trips/year=2024/month=03
 12.1 K   12.1 K  /raw/zone_lookup
```

Note **replication = 1** (single-node cluster) → stored size == logical size.

---

## Step 6 — Inspect a row from HDFS (proof the data is real)

```bash
hdfs dfs -cat /raw/trips/year=2024/month=01/yellow_tripdata_2024-01.csv | head -3
```

Expected: three CSV lines with 19 comma-separated fields each, e.g.

```
2,2024-01-01 00:57:55,2024-01-01 01:17:43,1,1.72,1,N,186,79,2,17.7,1.0,0.5,0.00,0.0,1.0,22.70,2.5,0.0
1,2024-01-01 00:03:00,2024-01-01 00:09:36,1,1.80,1,N,140,236,1,10.0,3.5,0.5,3.75,0.0,1.0,18.75,2.5,0.0
1,2024-01-01 00:17:06,2024-01-01 00:35:01,1,4.70,1,N,236,79,1,23.3,3.5,0.5,3.00,0.0,1.0,31.30,2.5,0.0
```

Screenshot as `02-hdfs-head.png`.

---

## Step 7 — HDFS block report

```bash
hdfs fsck /raw -files -blocks | tail -25
```

Expected: `Status: HEALTHY`, `Total blocks (validated): N`, average block size ≈ 128 MB.

Screenshot as `02-hdfs-fsck.png`.

---

## Step 8 — NameNode Web UI screenshots

Open `http://localhost:9870` in the VM's Firefox.

- **Overview page** → screenshot: `02-namenode-overview.png`
- **Utilities → Browse the file system** → navigate to `/raw/trips/year=2024/month=01/` → screenshot: `02-namenode-browse.png`
- **Datanodes tab** → screenshot: `02-namenode-datanodes.png`

---

## What to send back to Claude

1. Output of `hdfs dfs -ls -R /raw` (Step 5)
2. Output of `hdfs dfs -du -h /raw` (Step 5)
3. First 3 lines from `hdfs dfs -cat` (Step 6)
4. Last 25 lines of the fsck output (Step 7)
5. Any error that stopped you

Once clean, we move to **`03-run-pig-etl.md`**.

---

## Reproduce checklist (for the other 5 members on their VMs)

- [ ] `git pull` gets latest scripts.
- [ ] `python3 -c "import pyarrow"` succeeds.
- [ ] `./download_and_ingest.sh` finishes with "✅ Ingestion complete."
- [ ] `hdfs dfs -ls -R /raw` shows all 4 files (3 CSVs + zone lookup).
- [ ] Total HDFS usage ~920 MB.
- [ ] `hdfs dfs -cat` shows real CSV rows.
- [ ] `fsck` says HEALTHY.
- [ ] Screenshots taken.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `curl: (6) Could not resolve host` | Check VM's internet. Firefox works? DNS: `cat /etc/resolv.conf` should have nameservers. |
| `curl: (35) OpenSSL SSL_connect` | Ubuntu 22.04 CA bundle stale → `sudo update-ca-certificates` |
| `pip3: command not found` | `sudo apt install -y python3-pip` |
| `ModuleNotFoundError: pyarrow` in the conversion step | `pip3 install --user pyarrow pandas` |
| `hdfs: put: File exists` | Script uses `-put -f`, so this shouldn't happen; if it does, `hdfs dfs -rm -r /raw/trips` first then re-run |
| Disk full (`No space left`) | `df -h /home/hdoop`; delete extracted parquet files after CSV conversion if tight: `rm ~/staging/*.parquet` |
| CSV files half-written | Kill script, delete partial `staging/*.csv`, re-run — safe to resume |
| `Permission denied` writing to `/user/hive/warehouse` | Only relevant after Phase 1 ran — HDFS perms turned off there via `dfs.permissions.enabled=false` |
