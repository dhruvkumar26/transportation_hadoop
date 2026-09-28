#!/usr/bin/env python3
"""
mapper.py
---------
Native Hadoop Streaming mapper for the TRIPS-PER-ZONE-PER-HOUR job.

Reads cleaned trip records (CSV, comma-separated) from STDIN.
Emits: <pu_loc_id>\t<hour>\t1     (one row per trip)

Handles bad rows silently (counts them so we can see in job counters).
"""
import sys

BAD = 0
OK = 0

for raw in sys.stdin:
    raw = raw.rstrip("\n")
    if not raw:
        continue
    parts = raw.split(",")
    if len(parts) < 19:
        BAD += 1
        continue
    try:
        pickup_dt = parts[1]           # 'yyyy-MM-dd HH:mm:ss'
        pu_loc_id = parts[7]           # PULocationID
        if not pu_loc_id or not pickup_dt or len(pickup_dt) < 13:
            BAD += 1
            continue
        hour = pickup_dt[11:13]        # 'HH'
        # Sanity check
        int(hour)
        int(pu_loc_id)
    except (ValueError, IndexError):
        BAD += 1
        continue

    print(f"{pu_loc_id}\t{hour}\t1")
    OK += 1

# Report to job counters via stderr (Hadoop Streaming picks these up)
sys.stderr.write(f"reporter:counter:Custom,Rows OK,{OK}\n")
sys.stderr.write(f"reporter:counter:Custom,Rows BAD,{BAD}\n")
