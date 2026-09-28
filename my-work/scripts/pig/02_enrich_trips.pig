-- =============================================================================
-- 02_enrich_trips.pig
-- Assignment 1, Big Data Systems, BITS ZG522
--
-- PURPOSE
--   Take the cleaned trips from Phase 1, derive time features + trip duration,
--   join zone lookup for pickup borough/zone, and store as an enriched dataset
--   suitable for Hive external tables.
--
-- HOW TO RUN:
--   pig -x mapreduce -f 02_enrich_trips.pig
--
-- INPUT  : /clean/trips           (from 01_clean_trips.pig)
--          /raw/zone_lookup/*.csv (265 taxi zones)
-- OUTPUT : /clean/trips_enriched  (final enriched fact table for Hive)
-- =============================================================================

SET default_parallel 2;

clean = LOAD '/clean/trips' USING PigStorage(',') AS (
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

-- Derive time features + duration in minutes.
--   pickup_dt comes through as 'yyyy-MM-dd HH:mm:ss.SSSSSS' (microseconds).
--   SimpleDateFormat only handles milliseconds, so we trim to 19 chars first.
enriched = FOREACH clean {
    pu_ts  = ToDate(SUBSTRING(pickup_dt,  0, 19), 'yyyy-MM-dd HH:mm:ss');
    do_ts  = ToDate(SUBSTRING(dropoff_dt, 0, 19), 'yyyy-MM-dd HH:mm:ss');
    dur_ms = MilliSecondsBetween(do_ts, pu_ts);
    GENERATE
        vendor_id                                    AS vendor_id,
        pickup_dt                                    AS pickup_dt,
        dropoff_dt                                   AS dropoff_dt,
        (int)GetHour(pu_ts)                          AS pickup_hour,
        (int)GetDay(pu_ts)                           AS pickup_day,
        (int)GetMonth(pu_ts)                         AS pickup_month,
        (int)GetYear(pu_ts)                          AS pickup_year,
        (double)(dur_ms / 60000.0)                   AS duration_min,
        passenger_count                              AS passenger_count,
        trip_distance                                AS trip_distance,
        pu_loc_id                                    AS pu_loc_id,
        do_loc_id                                    AS do_loc_id,
        payment_type                                 AS payment_type,
        fare_amount                                  AS fare_amount,
        tip_amount                                   AS tip_amount,
        total_amount                                 AS total_amount,
        (fare_amount > 0 ? (tip_amount * 100.0 / fare_amount) : 0.0) AS tip_pct;
};

-- Zone lookup (has a header row we must skip; header has non-numeric LocationID)
zones_raw = LOAD '/raw/zone_lookup/taxi_zone_lookup.csv'
            USING PigStorage(',') AS (
                location_id_str:chararray,
                borough:chararray,
                zone:chararray,
                service_zone:chararray
            );

zones = FOREACH (FILTER zones_raw BY location_id_str MATCHES '"?\\d+"?') GENERATE
        (int)REPLACE(location_id_str, '"', '')  AS location_id,
        REPLACE(borough, '"', '')                AS borough,
        REPLACE(zone, '"', '')                   AS zone,
        REPLACE(service_zone, '"', '')           AS service_zone;

-- Left outer join so trips with unknown zone still survive
joined = JOIN enriched BY pu_loc_id LEFT OUTER, zones BY location_id;

final = FOREACH joined GENERATE
        enriched::vendor_id            AS vendor_id,
        enriched::pickup_dt            AS pickup_dt,
        enriched::pickup_hour          AS pickup_hour,
        enriched::pickup_day           AS pickup_day,
        enriched::pickup_month         AS pickup_month,
        enriched::pickup_year          AS pickup_year,
        enriched::duration_min         AS duration_min,
        enriched::passenger_count      AS passenger_count,
        enriched::trip_distance        AS trip_distance,
        enriched::pu_loc_id            AS pu_loc_id,
        (zones::borough IS NULL ? 'Unknown' : zones::borough) AS pu_borough,
        (zones::zone    IS NULL ? 'Unknown' : zones::zone   ) AS pu_zone,
        enriched::do_loc_id            AS do_loc_id,
        enriched::payment_type         AS payment_type,
        enriched::fare_amount          AS fare_amount,
        enriched::tip_amount           AS tip_amount,
        enriched::total_amount         AS total_amount,
        enriched::tip_pct              AS tip_pct;

STORE final INTO '/clean/trips_enriched' USING PigStorage(',');
