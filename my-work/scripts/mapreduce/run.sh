#!/usr/bin/env bash
# ============================================================================
# run.sh – Native Hadoop Streaming job
# Assignment 1, Big Data Systems, BITS ZG522
#
# Job: TRIPS-PER-ZONE-PER-HOUR
#
# Input : /clean/trips  (cleaned CSV from Pig phase)
# Output: /results/trips_per_zone_hour
#
# Purpose: explicitly show a mapper + reducer running on YARN — proves we
# understand the MR mental model beyond Pig/Hive's implicit compilation.
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STREAMING_JAR="$(find $HADOOP_HOME/share/hadoop/tools/lib -name 'hadoop-streaming-*.jar' | head -1)"

if [[ -z "$STREAMING_JAR" ]]; then
  echo "ERROR: hadoop-streaming jar not found under \$HADOOP_HOME/share/hadoop/tools/lib"
  exit 1
fi

INPUT="/clean/trips"
OUTPUT="/results/trips_per_zone_hour"

# Clean previous output if any (Hadoop refuses to overwrite an existing output dir)
hdfs dfs -rm -r -f "$OUTPUT" >/dev/null 2>&1 || true

echo "→ Submitting streaming job..."
echo "  jar    : $STREAMING_JAR"
echo "  mapper : $SCRIPT_DIR/mapper.py"
echo "  reducer: $SCRIPT_DIR/reducer.py"
echo "  input  : $INPUT"
echo "  output : $OUTPUT"
echo ""

hadoop jar "$STREAMING_JAR" \
    -D mapreduce.job.name="TripsPerZonePerHour" \
    -D mapreduce.job.reduces=2 \
    -D stream.num.map.output.key.fields=2 \
    -D mapreduce.partition.keypartitioner.options="-k1,2" \
    -files "$SCRIPT_DIR/mapper.py,$SCRIPT_DIR/reducer.py" \
    -mapper    "python3 mapper.py"  \
    -reducer   "python3 reducer.py" \
    -partitioner org.apache.hadoop.mapred.lib.KeyFieldBasedPartitioner \
    -input   "$INPUT" \
    -output  "$OUTPUT"

echo ""
echo "→ First 10 lines of output:"
echo $(hdfs dfs -cat "$OUTPUT/part-*" 2>/dev/null | head -10)
echo ""
echo "→ Line count in output:"
echo $(hdfs dfs -cat "$OUTPUT/part-*" | wc -l)
echo ""
echo "✅ Streaming job done. Open http://localhost:8088."
