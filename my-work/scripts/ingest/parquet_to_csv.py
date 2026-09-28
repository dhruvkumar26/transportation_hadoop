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
"""
import sys
import pyarrow.parquet as pq
import pyarrow.csv as pv


def convert(src: str, dst: str, batch_size: int = 200_000) -> int:
    pf = pq.ParquetFile(src)
    total = pf.metadata.num_rows
    opts = pv.WriteOptions(include_header=False)
    writer = pv.CSVWriter(dst, pf.schema_arrow, write_options=opts)
    written = 0
    for batch in pf.iter_batches(batch_size=batch_size):
        writer.write_batch(batch)
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
