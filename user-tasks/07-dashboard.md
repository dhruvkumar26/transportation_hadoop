# Phase 7 – Streamlit Dashboard

**Phase owner:** M6
**Time:** 15–20 minutes.
**Prerequisites:** 5 CSVs in `~/bigdata-assignment/my-work/dashboard/data/` (produced at end of Phase 5).

## What we're building

An interactive dashboard that reads the Hive-exported CSVs and renders the 5 business insights with Plotly charts. Runs locally inside the VM; access from Firefox at `http://localhost:8501`.

**Charts:**
1. Top-10 pickup zones by hour (slider control)
2. Revenue by borough × payment method
3. Congestion trend – min/mile by hour + slowest PU→DO pairs
4. Airport profile (JFK/LGA/EWR) – top destinations
5. Card vs cash share by borough

The dashboard runs entirely on local CSVs — Hadoop/Hive/HBase can be stopped before this phase to free RAM.

---

## Step 1 — Free RAM (optional but recommended)

```bash
stop-hbase.sh          # if running
$HADOOP_HOME/sbin/stop-yarn.sh
$HADOOP_HOME/sbin/stop-dfs.sh
jps                    # only "Jps" should remain
```

---

## Step 2 — Pull latest code

```bash
cd ~/bigdata-assignment && git pull
ls -lh my-work/dashboard/data
```

Expected: 5 CSVs from Phase 5.

If missing, restart Hadoop and re-run:

```bash
mkdir -p ~/bigdata-assignment/my-work/dashboard/data
for q in q1_hotspots q2_revenue_by_borough q3_congestion q4_airports q5_payment_share; do
  hdfs dfs -getmerge /results/hive/$q ~/bigdata-assignment/my-work/dashboard/data/${q}.csv
done
```

---

## Step 3 — Install Streamlit + Plotly

```bash
pip3 install --user -r ~/bigdata-assignment/my-work/dashboard/requirements.txt
```

Verify:

```bash
python3 -c "import streamlit, plotly, pandas; print(streamlit.__version__, plotly.__version__, pandas.__version__)"
```

Expected: three version strings.

The `streamlit` binary lands in `~/.local/bin`. Make sure it's on `$PATH`:

```bash
echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc
source ~/.bashrc
which streamlit
```

---

## Step 4 — Launch the app

```bash
cd ~/bigdata-assignment/my-work/dashboard
streamlit run app.py --server.headless true --server.port 8501
```

You'll see:

```
  You can now view your Streamlit app in your browser.

  Local URL: http://localhost:8501
  Network URL: http://x.x.x.x:8501
```

Open **`http://localhost:8501`** in the VM's Firefox.

---

## Step 5 — Capture dashboard screenshots

Take **one full-page screenshot per chart** — these go straight into the report.

| Screenshot file | What to capture |
|---|---|
| `07-dashboard-home.png` | Top of the app: title + KPI row |
| `07-dashboard-q1.png` | Q1 demand hotspots at hour = 18 |
| `07-dashboard-q1-morning.png` | Same but hour = 8 (compare) |
| `07-dashboard-q2.png` | Q2 revenue by borough × payment |
| `07-dashboard-q3.png` | Q3 congestion line + top-slow pairs table |
| `07-dashboard-q4-jfk.png` | Q4 with airport = JFK |
| `07-dashboard-q4-lga.png` | Q4 with airport = LGA |
| `07-dashboard-q5.png` | Q5 payment share bars |

Use Firefox's **full-page screenshot** (F12 → screenshot icon in device toolbar, or `Ctrl+Shift+M` then screenshot).

---

## Step 6 — Stop the app

`Ctrl+C` in the terminal running Streamlit.

---

## Explaining the dashboard in the viva (M6's angle)

- **Why Streamlit?** It reads flat files and gives us interactive controls (sliders, radio buttons) in <200 lines of Python. No JS, no build step. Perfect for demoing analytics.
- **Data path recap** — HDFS raw CSV → Pig ETL → HDFS `/clean/trips_enriched` → Hive `fact_trips` external table → 5 analytics queries → Hive `INSERT OVERWRITE DIRECTORY` writes CSV to HDFS `/results/hive/*` → `hdfs dfs -getmerge` pulls to local disk → Streamlit reads from local disk.
- **Why go through Hive at all?** Because the queries are complex aggregations over 8 M rows. Doing them in Python would either OOM the 4 GB VM or run for hours; Hive parallelises them via MapReduce.
- **Real-world evolution** — In production you'd swap "Streamlit reads local CSV" for "Streamlit hits Hive JDBC directly" or "Streamlit hits Presto/Trino over the same tables." Same pipeline, faster interactivity.

---

## What to send back to Claude

1. Screenshot of `07-dashboard-home.png` (KPI row).
2. Screenshot of at least Q1 (hour = 18) and Q4 (JFK).
3. Any error message that killed the app.

Next artifact: **`08-screenshot-checklist.md`** — the master list of every screenshot the report needs.

---

## Reproduce checklist

- [ ] All 5 CSVs present.
- [ ] `streamlit` command on `$PATH`.
- [ ] `streamlit run app.py` opens at :8501.
- [ ] KPI row shows non-zero numbers.
- [ ] Q1 slider changes the chart.
- [ ] Q4 radio switches airports.
- [ ] All 8 screenshots taken.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `streamlit: command not found` | `~/.local/bin` not on PATH — see Step 3 |
| Streamlit shows all zeros | CSVs are empty; re-run Phase 5 export |
| Charts say "Missing file:" | Path mismatch — CSVs must be under `my-work/dashboard/data/` |
| ValueError on load | Hive wrote `\N` for nulls — either replace in CSVs (`sed -i 's/\\N//g' data/*.csv`) or add `na_values="\\N"` to the pandas load |
| Port 8501 already in use | `streamlit run app.py --server.port 8502` |
| Firefox can't reach localhost:8501 | Streamlit binds to localhost by default → good. If VM has restricted networking, add `--server.address 0.0.0.0` and open the "Network URL" |
