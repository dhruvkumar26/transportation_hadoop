-- =============================================================================
-- 03_export.sql
-- Assignment 1, Big Data Systems, BITS ZG522
--
-- Export the 5 Hive result tables to CSV files inside HDFS at /results/hive/
-- so the Streamlit dashboard (running on the host) can pull them with:
--   hdfs dfs -getmerge /results/hive/q1_hotspots  q1_hotspots.csv
-- =============================================================================

USE taxi_analytics;

INSERT OVERWRITE DIRECTORY '/results/hive/q1_hotspots'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
    SELECT * FROM q1_hotspots;

INSERT OVERWRITE DIRECTORY '/results/hive/q2_revenue_by_borough'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
    SELECT * FROM q2_revenue_by_borough;

INSERT OVERWRITE DIRECTORY '/results/hive/q3_congestion'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
    SELECT * FROM q3_congestion;

INSERT OVERWRITE DIRECTORY '/results/hive/q4_airports'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
    SELECT * FROM q4_airports;

INSERT OVERWRITE DIRECTORY '/results/hive/q5_payment_share'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
    SELECT * FROM q5_payment_share;
