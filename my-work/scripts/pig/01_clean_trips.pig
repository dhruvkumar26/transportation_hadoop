-- =============================================================================
-- 01_clean_trips.pig
-- Assignment 1, Big Data Systems, BITS ZG522
--
-- PURPOSE
--   Read raw NYC Yellow Taxi CSV files from HDFS, filter out data-quality
--   violations, and write a "clean" dataset back to HDFS.
--
-- HOW TO RUN (inside VM as hdoop):
--   pig -x mapreduce -f 01_clean_trips.pig
--
-- INPUT   : /raw/trips/year=2026/month={01,02,03}/yellow_tripdata_*.csv
-- OUTPUT  : /clean/trips/     (partition-flat comma-separated files)
--
-- Filters applied (documented for the report):
--   trip_distance > 0 AND < 100
--   fare_amount > 0 AND < 500
--   passenger_count >= 1 AND <= 6
--   pu_loc_id NOT NULL, do_loc_id NOT NULL
--   total_amount > 0
-- =============================================================================

SET default_parallel 2;
SET pig.exec.reducers.bytes.per.reducer 128000000;

-- Load raw records from all three months at once (Pig globs work over HDFS)
raw = LOAD '/raw/trips/*/*/yellow_tripdata_*.csv'
      USING PigStorage(',') AS (
          vendor_id:int,
          pickup_dt:chararray,
          dropoff_dt:chararray,
          passenger_count:double,
          trip_distance:double,
          rate_code:double,
          store_fwd:chararray,
          pu_loc_id:int,
          do_loc_id:int,
          payment_type:int,
          fare_amount:double,
          extra:double,
          mta_tax:double,
          tip_amount:double,
          tolls_amount:double,
          improvement_surcharge:double,
          total_amount:double,
          congestion_surcharge:double,
          airport_fee:double
      );

-- Quick sanity: count what we loaded
raw_ct = FOREACH (GROUP raw ALL) GENERATE COUNT(raw) AS n;
STORE raw_ct INTO '/clean/_counts/raw' USING PigStorage(',');

-- Apply cleansing filters
clean = FILTER raw BY
        vendor_id IS NOT NULL
    AND pu_loc_id IS NOT NULL
    AND do_loc_id IS NOT NULL
    AND passenger_count >= 1.0 AND passenger_count <= 6.0
    AND trip_distance > 0.0    AND trip_distance < 100.0
    AND fare_amount   > 0.0    AND fare_amount   < 500.0
    AND total_amount  > 0.0;

-- Persist cleaned records
STORE clean INTO '/clean/trips' USING PigStorage(',');

-- Count clean records too so we can report the drop rate
clean_ct = FOREACH (GROUP clean ALL) GENERATE COUNT(clean) AS n;
STORE clean_ct INTO '/clean/_counts/clean' USING PigStorage(',');
