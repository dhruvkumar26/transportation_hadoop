#!/usr/bin/env bash
# ============================================================================
#  download_and_ingest.sh
#  Assignment 1, Big Data Systems, BITS ZG522
#
#  Downloads 3 months of NYC TLC Yellow Taxi trip data + zone lookup,
#  converts parquet -> headerless CSV, uploads to HDFS with year/month
#  partition layout ready for Hive.
#
#  Run this INSIDE the VM as user `hdoop`.
#  Prerequisites: Hadoop up (start-dfs.sh + start-yarn.sh), python3 + pyarrow.
# ============================================================================
set -euo pipefail

BASE_URL="https://d37ci6vzurychx.cloudfront.net"
STAGING="/home/hdoop/staging"
MONTHS=("2026-01" "2026-02" "2026-03")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$STAGING"

echo "========================================================================"
echo " Phase 2 – Download + HDFS Ingestion"
echo " Target : 3 months of NYC Yellow Taxi trip data (Jan/Feb/Mar 2026)"
echo " Staging: $STAGING"
echo "========================================================================"

# ----------------------------------------------------------------------------
# 0. Sanity: is Hadoop up?
# ----------------------------------------------------------------------------
if ! hdfs dfs -ls / >/dev/null 2>&1; then
  echo "ERROR: HDFS is not reachable. Start Hadoop first:"
  echo "       \$HADOOP_HOME/sbin/start-dfs.sh"
  echo "       \$HADOOP_HOME/sbin/start-yarn.sh"
  exit 1
fi

# ----------------------------------------------------------------------------
# 1. pyarrow (for the parquet->csv step)
# ----------------------------------------------------------------------------
if ! python3 -c "import pyarrow" 2>/dev/null; then
  echo "→ Installing pyarrow + pandas (user site)..."
  pip3 install --user --quiet pyarrow pandas
fi

# ----------------------------------------------------------------------------
# 2. Zone lookup (tiny, ~12 KB)
# ----------------------------------------------------------------------------
if [[ ! -f "$STAGING/taxi_zone_lookup.csv" ]]; then
  echo "→ Downloading taxi_zone_lookup.csv..."
  curl -fL --progress-bar "$BASE_URL/misc/taxi_zone_lookup.csv" \
       -o "$STAGING/taxi_zone_lookup.csv"
else
  echo "✓ taxi_zone_lookup.csv already staged"
fi

# ----------------------------------------------------------------------------
# 3. Monthly parquet files (~56–64 MB each, x3 = ~190 MB)
# ----------------------------------------------------------------------------
for M in "${MONTHS[@]}"; do
  F="yellow_tripdata_${M}.parquet"
  if [[ ! -f "$STAGING/$F" ]]; then
    echo "→ Downloading $F..."
    curl -fL --progress-bar "$BASE_URL/trip-data/$F" -o "$STAGING/$F"
  else
    echo "✓ $F already staged"
  fi
done

# ----------------------------------------------------------------------------
# 4. Convert parquet -> headerless CSV (19 cols; ~360–415 MB each, x3 = ~1.1 GB)
# ----------------------------------------------------------------------------
for M in "${MONTHS[@]}"; do
  P="$STAGING/yellow_tripdata_${M}.parquet"
  C="$STAGING/yellow_tripdata_${M}.csv"
  if [[ ! -f "$C" ]]; then
    echo "→ Converting $P → CSV..."
    python3 "$SCRIPT_DIR/parquet_to_csv.py" "$P" "$C"
  else
    echo "✓ CSV for $M already exists"
  fi
done

# ----------------------------------------------------------------------------
# 5. HDFS layout
#     /raw/zone_lookup/taxi_zone_lookup.csv
#     /raw/trips/year=2026/month=01/yellow_tripdata_2026-01.csv
#     /raw/trips/year=2026/month=02/yellow_tripdata_2026-02.csv
#     /raw/trips/year=2026/month=03/yellow_tripdata_2026-03.csv
# ----------------------------------------------------------------------------
echo ""
echo "→ Uploading to HDFS..."

hdfs dfs -mkdir -p /raw/zone_lookup
hdfs dfs -put -f "$STAGING/taxi_zone_lookup.csv" /raw/zone_lookup/

for M in "${MONTHS[@]}"; do
  YEAR=${M%-*}
  MONTH=${M#*-}
  hdfs dfs -mkdir -p "/raw/trips/year=${YEAR}/month=${MONTH}"
  hdfs dfs -put -f "$STAGING/yellow_tripdata_${M}.csv" \
                  "/raw/trips/year=${YEAR}/month=${MONTH}/"
done

# ----------------------------------------------------------------------------
# 6. Verify
# ----------------------------------------------------------------------------
echo ""
echo "========================================================================"
echo " HDFS contents:"
echo "========================================================================"
hdfs dfs -ls -R /raw | head -20
echo ""
echo "Disk usage (HDFS):"
hdfs dfs -du -h /raw
echo ""
echo "Block report (single-node, expect replication = 1):"
hdfs fsck /raw -files -blocks | tail -15
echo ""
echo "✅ Ingestion complete."
echo "   Now open http://localhost:9870 → Utilities → Browse the file system"
echo "   and take screenshots of /raw/trips/..."
