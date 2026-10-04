#!/usr/bin/env python3
"""
reducer.py
----------
Native Hadoop Streaming reducer for the TRIPS-PER-ZONE-PER-HOUR job.

Reads mapper output on STDIN. run.sh sets
    stream.num.map.output.key.fields=2
so Hadoop treats "<pu_loc_id>\t<hour>" as the composite key and guarantees
that all rows sharing that pair arrive contiguously and sorted at one
reducer.

Emits: <pu_loc_id>\t<hour>\t<count>
"""
import sys

current_key = None
current_count = 0

for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue
    try:
        pu_loc_id, hour, val = line.split("\t")
        val = int(val)
    except ValueError:
        continue

    key = f"{pu_loc_id}\t{hour}"

    if key == current_key:
        current_count += val
    else:
        if current_key is not None:
            print(f"{current_key}\t{current_count}")
        current_key = key
        current_count = val

# Emit last key
if current_key is not None:
    print(f"{current_key}\t{current_count}")
