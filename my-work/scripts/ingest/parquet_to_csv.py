#!/usr/bin/env python3
"""
parquet_to_csv.py
-----------------
Converts a NYC TLC Yellow Taxi parquet file into a headerless comma-separated CSV,
streaming in row groups so it works on low-RAM VMs (4 GB is enough).

Usage: python3 parquet_to_csv.py <src.parquet> <dst.csv>

The output has NO header row (simpler for Pig / Hive LOAD).
The 19 columns are, in order:
    VendorID, tpep_pickup_datetime, tpep_dropoff_datetime, passenger_count,
    trip_distance, RatecodeID, store_and_fwd_flag, PULocationID, DOLocationID,
    payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount,
    improvement_surcharge, total_amount, congestion_surcharge, Airport_fee

TLC added extra fields in newer releases (e.g. cbd_congestion_fee in 2026+).
Those are dropped here so Pig / MapReduce scripts keep the same 19-field layout.
"""
import sys

import pyarrow as pa
import pyarrow.csv as pv
import pyarrow.parquet as pq

CSV_COLUMNS = [
    "VendorID",
    "tpep_pickup_datetime",
    "tpep_dropoff_datetime",
    "passenger_count",
    "trip_distance",
    "RatecodeID",
    "store_and_fwd_flag",
    "PULocationID",
    "DOLocationID",
    "payment_type",
    "fare_amount",
    "extra",
    "mta_tax",
    "tip_amount",
    "tolls_amount",
    "improvement_surcharge",
    "total_amount",
    "congestion_surcharge",
    "Airport_fee",
]


def convert(src: str, dst: str, batch_size: int = 200_000) -> int:
    pf = pq.ParquetFile(src)
    total = pf.metadata.num_rows
    available = set(pf.schema_arrow.names)
    missing = [c for c in CSV_COLUMNS if c not in available]
    if missing:
        raise SystemExit(f"{src}: missing expected column(s): {', '.join(missing)}")

    out_schema = pa.schema([(name, pf.schema_arrow.field(name).type) for name in CSV_COLUMNS])
    opts = pv.WriteOptions(include_header=False)
    writer = pv.CSVWriter(dst, out_schema, write_options=opts)
    written = 0
    for batch in pf.iter_batches(batch_size=batch_size):
        table = pa.Table.from_batches([batch]).select(CSV_COLUMNS)
        writer.write_table(table)
        written += batch.num_rows
        pct = 100.0 * written / total
        print(f"  {written:>10,} / {total:,} rows  ({pct:5.1f}%)", flush=True)
    writer.close()
    return written


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 parquet_to_csv.py <src.parquet> <dst.csv>", file=sys.stderr)
        sys.exit(2)
    n = convert(sys.argv[1], sys.argv[2])
    print(f"Done. {n:,} rows written to {sys.argv[2]}")
