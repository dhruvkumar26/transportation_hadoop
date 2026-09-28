#!/usr/bin/env python3
"""
load_zones.py
-------------
Loads the 265 NYC taxi zones into HBase table `zone_lookup` via the HBase Thrift
gateway (default port 9090).

Prerequisite (start-up steps for the VM):
    hbase-daemon.sh start thrift
    pip3 install --user happybase

HOW TO RUN:
    python3 load_zones.py /home/hdoop/staging/taxi_zone_lookup.csv
"""
import csv
import sys

try:
    import happybase
except ImportError:
    sys.stderr.write("happybase not installed. Run:  pip3 install --user happybase\n")
    sys.exit(2)


def main(csv_path: str) -> None:
    conn = happybase.Connection(host="127.0.0.1", port=9090)
    table = conn.table("zone_lookup")

    inserted = 0
    with open(csv_path, newline="") as f:
        reader = csv.reader(f)
        next(reader)  # skip header
        with table.batch(batch_size=64) as b:
            for row in reader:
                if len(row) < 4:
                    continue
                loc_id, borough, zone, service_zone = row[0], row[1], row[2], row[3]
                # Row key = LocationID (stringified — HBase keys are bytes)
                key = str(loc_id).encode("utf-8")
                b.put(key, {
                    b"info:borough":      borough.encode("utf-8"),
                    b"info:zone_name":    zone.encode("utf-8"),
                    b"info:service_zone": service_zone.encode("utf-8"),
                })
                inserted += 1

    print(f"Inserted {inserted} zones into HBase table `zone_lookup`.")

    # Verify with a get
    print("\nGET zone_lookup, '132':")
    for k, v in table.row(b"132").items():
        print(f"  {k.decode()} = {v.decode()}")

    conn.close()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 load_zones.py <path-to-taxi_zone_lookup.csv>", file=sys.stderr)
        sys.exit(2)
    main(sys.argv[1])
