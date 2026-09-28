-- =============================================================================
-- 02_analytics.sql
-- Assignment 1, Big Data Systems, BITS ZG522
--
-- The 5 business questions we promised in Part A.  Each query:
--   • has an EXPLAIN target you can screenshot (execution plan)
--   • materialises its result as a Hive-managed table so 03_export.sql
--     can dump it to CSV for the Streamlit dashboard.
--
-- HOW TO RUN:  hive -f 02_analytics.sql
-- =============================================================================

USE taxi_analytics;

SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;

-- -----------------------------------------------------------------------------
-- Q1. Demand hotspots – top pickup zones per hour-of-day
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS q1_hotspots;
CREATE TABLE q1_hotspots STORED AS ORC AS
SELECT
    pickup_hour,
    pu_borough,
    pu_zone,
    COUNT(*) AS trips
FROM fact_trips
GROUP BY pickup_hour, pu_borough, pu_zone
ORDER BY pickup_hour, trips DESC;

-- Show top 5 zones for a representative rush hour (18:00)
SELECT * FROM q1_hotspots WHERE pickup_hour = 18 LIMIT 5;


-- -----------------------------------------------------------------------------
-- Q2. Revenue analytics – by borough & payment_type
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS q2_revenue_by_borough;
CREATE TABLE q2_revenue_by_borough STORED AS ORC AS
SELECT
    pu_borough,
    CASE payment_type
        WHEN 1 THEN 'Card'
        WHEN 2 THEN 'Cash'
        WHEN 3 THEN 'NoCharge'
        WHEN 4 THEN 'Dispute'
        ELSE        'Other'
    END                                                 AS payment_method,
    COUNT(*)                                            AS trips,
    ROUND(SUM(total_amount), 2)                         AS revenue_usd,
    ROUND(AVG(fare_amount),  2)                         AS avg_fare,
    ROUND(AVG(tip_pct),      2)                         AS avg_tip_pct
FROM fact_trips
GROUP BY pu_borough,
         CASE payment_type WHEN 1 THEN 'Card' WHEN 2 THEN 'Cash'
                           WHEN 3 THEN 'NoCharge' WHEN 4 THEN 'Dispute'
                           ELSE 'Other' END
ORDER BY revenue_usd DESC;

SELECT * FROM q2_revenue_by_borough LIMIT 10;


-- -----------------------------------------------------------------------------
-- Q3. Congestion signal – avg duration per PU→DO pair, by hour
--     (limit output to the 500 heaviest pairs to keep dashboard responsive)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS q3_congestion;
CREATE TABLE q3_congestion STORED AS ORC AS
SELECT
    pickup_hour,
    pu_loc_id,
    do_loc_id,
    COUNT(*)                          AS trips,
    ROUND(AVG(duration_min), 2)       AS avg_duration_min,
    ROUND(AVG(trip_distance),2)       AS avg_distance_mi,
    ROUND(AVG(duration_min / NULLIF(trip_distance,0)), 2) AS min_per_mile
FROM fact_trips
WHERE trip_distance > 0.1
  AND duration_min BETWEEN 1 AND 120
GROUP BY pickup_hour, pu_loc_id, do_loc_id
HAVING COUNT(*) >= 20
ORDER BY trips DESC
LIMIT 500;

SELECT * FROM q3_congestion LIMIT 10;


-- -----------------------------------------------------------------------------
-- Q4. Airport trip profile – JFK (132), LGA (138), EWR (1)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS q4_airports;
CREATE TABLE q4_airports STORED AS ORC AS
SELECT
    CASE t.pu_loc_id
        WHEN 132 THEN 'JFK'
        WHEN 138 THEN 'LGA'
        WHEN 1   THEN 'EWR'
    END                             AS airport,
    z.zone                          AS destination_zone,
    z.borough                       AS destination_borough,
    COUNT(*)                        AS trips,
    ROUND(AVG(t.trip_distance), 2)  AS avg_distance_mi,
    ROUND(AVG(t.fare_amount),   2)  AS avg_fare,
    ROUND(AVG(t.tip_pct),       2)  AS avg_tip_pct,
    ROUND(AVG(t.duration_min),  1)  AS avg_duration_min
FROM fact_trips t
JOIN dim_zone   z ON z.location_id = t.do_loc_id
WHERE t.pu_loc_id IN (132, 138, 1)
GROUP BY t.pu_loc_id, z.zone, z.borough
ORDER BY airport, trips DESC;

SELECT * FROM q4_airports WHERE airport = 'JFK' LIMIT 10;


-- -----------------------------------------------------------------------------
-- Q5. Payment behaviour – card vs cash share by borough
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS q5_payment_share;
CREATE TABLE q5_payment_share STORED AS ORC AS
SELECT
    pu_borough,
    ROUND(SUM(CASE WHEN payment_type = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS pct_card,
    ROUND(SUM(CASE WHEN payment_type = 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS pct_cash,
    ROUND(SUM(CASE WHEN payment_type NOT IN (1,2) THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS pct_other,
    COUNT(*) AS trips
FROM fact_trips
GROUP BY pu_borough
ORDER BY trips DESC;

SELECT * FROM q5_payment_share;


-- -----------------------------------------------------------------------------
-- EXPLAIN plans – capture screenshots of these for the report
-- -----------------------------------------------------------------------------
EXPLAIN
SELECT pickup_hour, pu_zone, COUNT(*) AS trips
FROM fact_trips
GROUP BY pickup_hour, pu_zone
ORDER BY trips DESC
LIMIT 10;
