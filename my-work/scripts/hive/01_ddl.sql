-- =============================================================================
-- 01_ddl.sql
-- Assignment 1, Big Data Systems, BITS ZG522
--
-- PURPOSE
--   Create the Hive external tables sitting on top of Pig's enriched output.
--   Nothing is copied — Hive reads directly from HDFS.
--
-- HOW TO RUN:
--   hive -f 01_ddl.sql        # or from beeline:
--   beeline -u jdbc:hive2://localhost:10000 -n hdoop -f 01_ddl.sql
-- =============================================================================

CREATE DATABASE IF NOT EXISTS taxi_analytics
    COMMENT 'NYC TLC Yellow Taxi analytics – BITS ZG522 Assignment 1'
    LOCATION '/user/hive/warehouse/taxi_analytics.db';

USE taxi_analytics;

-- =============================================================================
-- Fact table: enriched trips  (populated by Pig 02_enrich_trips.pig)
-- =============================================================================
DROP TABLE IF EXISTS fact_trips;
CREATE EXTERNAL TABLE fact_trips (
    vendor_id        INT,
    pickup_dt        STRING,
    pickup_hour      INT,
    pickup_day       INT,
    pickup_month     INT,
    pickup_year      INT,
    duration_min     DOUBLE,
    passenger_count  DOUBLE,
    trip_distance    DOUBLE,
    pu_loc_id        INT,
    pu_borough       STRING,
    pu_zone          STRING,
    do_loc_id        INT,
    payment_type     INT,
    fare_amount      DOUBLE,
    tip_amount       DOUBLE,
    total_amount     DOUBLE,
    tip_pct          DOUBLE
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/clean/trips_enriched';

-- =============================================================================
-- Dimension: zone lookup  (raw CSV with header)
-- We read it as an intermediate table then materialize the clean version.
-- =============================================================================
DROP TABLE IF EXISTS zone_raw;
CREATE EXTERNAL TABLE zone_raw (
    location_id_str STRING,
    borough_q       STRING,
    zone_q          STRING,
    service_zone_q  STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    "separatorChar" = ",",
    "quoteChar"     = "\""
)
STORED AS TEXTFILE
LOCATION '/raw/zone_lookup'
TBLPROPERTIES ("skip.header.line.count"="1");

DROP TABLE IF EXISTS dim_zone;
CREATE TABLE dim_zone
STORED AS ORC
AS
SELECT
    CAST(location_id_str AS INT) AS location_id,
    borough_q       AS borough,
    zone_q          AS zone,
    service_zone_q  AS service_zone
FROM zone_raw
WHERE location_id_str RLIKE '^[0-9]+$';

-- =============================================================================
-- Sanity checks
-- =============================================================================
SELECT COUNT(*) AS trip_count   FROM fact_trips;
SELECT COUNT(*) AS zone_count   FROM dim_zone;
SELECT * FROM dim_zone LIMIT 5;
SELECT vendor_id, pickup_dt, pu_zone, fare_amount, tip_amount, total_amount
FROM fact_trips LIMIT 5;
