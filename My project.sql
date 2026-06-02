-- ============================================================
-- LOGISTICS TRACKING DATABASE SETUP & LOAD SCRIPT
-- Compatible with: MySQL 5.7+ / MySQL 8.x
-- Data file: logistics_cleaned.csv
-- ============================================================

-- ------------------------------------------------------------
-- STEP 1: Enable local file import & disable strict mode
-- ------------------------------------------------------------
SET SQL_MODE = '';
SET GLOBAL local_infile = ON;

-- ------------------------------------------------------------
-- STEP 2: Create & select database
-- ------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS logistics_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE logistics_db;

-- ------------------------------------------------------------
-- STEP 3: Create shipments table
-- ------------------------------------------------------------
DROP TABLE IF EXISTS shipments;

CREATE TABLE shipments (
  gps_provider                VARCHAR(100),
  booking_id                  VARCHAR(50)       NOT NULL,
  shipment_type               VARCHAR(20)       NOT NULL,
  booking_date                DATETIME,
  vehicle_registration        VARCHAR(50),
  origin_location             VARCHAR(500),
  destination_location        VARCHAR(500),
  origin_latitude             DECIMAL(11, 8),
  origin_longitude            DECIMAL(11, 8),
  destination_latitude        DECIMAL(11, 8),
  destination_longitude       DECIMAL(11, 8),
  data_ping_time              DATETIME,
  planned_eta                 DATETIME,
  current_location            VARCHAR(500),
  actual_eta                  DATETIME,
  current_latitude            DECIMAL(11, 8),
  current_longitude           DECIMAL(11, 8),
  ontime                      ENUM('Yes', 'No'),
  trip_start_date             DATETIME,
  trip_end_date               DATETIME,
  transportation_distance_km  DECIMAL(10, 2),
  vehicle_type                VARCHAR(100),
  min_kms_per_day             INT,
  driver_name                 VARCHAR(100),
  driver_mobile_no            VARCHAR(20),
  customer_name               VARCHAR(200),
  supplier_name               VARCHAR(200),
  material_shipped            VARCHAR(255),

  PRIMARY KEY (booking_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- STEP 4: Load cleaned CSV data
-- NOTE: Update the file path below to where you saved
--       logistics_cleaned.csv on your machine
-- ------------------------------------------------------------
-- i have error duplicate entry so i decided to truncate the table 


SET GLOBAL local_infile = 1;
SHOW GLOBAL VARIABLES LIKE 'local_infile';
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.2/Uploads/logistics_cleaned.csv'
REPLACE -- it replaces duplicate instead of throwing error
INTO TABLE shipments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
  gps_provider,
  booking_id,
  shipment_type,
  @booking_date,
  vehicle_registration,
  origin_location,
  destination_location,
  @origin_latitude,
  @origin_longitude,
  @destination_latitude,
  @destination_longitude,
  @data_ping_time,
  @planned_eta,
  current_location,
  @actual_eta,
  @current_latitude,
  @current_longitude,
  ontime,
  @trip_start_date,
  @trip_end_date,
  @transportation_distance_km,
  vehicle_type,
  @min_kms_per_day,
  driver_name,
  driver_mobile_no,
  customer_name,
  supplier_name,
  material_shipped
)
SET
  booking_date               = NULLIF(@booking_date, ''),
  origin_latitude            = NULLIF(@origin_latitude, ''),
  origin_longitude           = NULLIF(@origin_longitude, ''),
  destination_latitude       = NULLIF(@destination_latitude, ''),
  destination_longitude      = NULLIF(@destination_longitude, ''),
  data_ping_time             = NULLIF(@data_ping_time, ''),
  planned_eta                = NULLIF(@planned_eta, ''),
  actual_eta                 = NULLIF(@actual_eta, ''),
  current_latitude           = NULLIF(@current_latitude, ''),
  current_longitude          = NULLIF(@current_longitude, ''),
  trip_start_date            = NULLIF(@trip_start_date, ''),
  trip_end_date              = NULLIF(@trip_end_date, ''),
  transportation_distance_km = NULLIF(@transportation_distance_km, ''),
  min_kms_per_day            = NULLIF(@min_kms_per_day, '');

-- Confirm load
SELECT CONCAT('Rows loaded: ', COUNT(*)) AS status FROM shipments;
-- ============================================================
-- ANALYSIS QUERIES
-- ============================================================

-- ------------------------------------------------------------
-- Q1: Top routes by frequency + average distance
-- ------------------------------------------------------------
SELECT
  origin_location,
  destination_location,
  COUNT(*)                               AS route_count,
  ROUND(AVG(transportation_distance_km), 1) AS avg_distance_km
FROM shipments
GROUP BY origin_location, destination_location
ORDER BY route_count DESC
LIMIT 20;

-- ------------------------------------------------------------
-- Q2: On-time vs Delayed breakdown
-- ------------------------------------------------------------
SELECT
  ontime,
  COUNT(*) AS shipment_count,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM shipments), 1) AS pct
FROM shipments
GROUP BY ontime;

-- ------------------------------------------------------------
-- Q3: Delay rate by supplier
-- ------------------------------------------------------------
-- SELECT
--   supplier_name,
--   COUNT(*)                                                                AS total_shipments,
--   SUM(CASE WHEN ontime = 'No' THEN 1 ELSE 0 END)                         AS delayed,
--   ROUND(100.0 * SUM(CASE WHEN ontime = 'No' THEN 1 ELSE 0 END) / COUNT(*), 1) AS delay_rate_pct
-- FROM shipments
-- GROUP BY supplier_name
-- ORDER BY delay_rate_pct DESC;


SELECT
  supplier_name,
  COUNT(*)                                                                    AS total_shipments,
  SUM(CASE WHEN ontime = 'No' THEN 1 ELSE 0 END)                             AS `delayed`,
  ROUND(100.0 * SUM(CASE WHEN ontime = 'No' THEN 1 ELSE 0 END) / COUNT(*), 1) AS delay_rate_pct
FROM shipments
GROUP BY supplier_name
ORDER BY delay_rate_pct DESC;

-- ------------------------------------------------------------
-- Q4: Average & max delivery time per route (in hours)
-- ------------------------------------------------------------
SELECT
  origin_location,
  destination_location,
  COUNT(*)                                                         AS trips,
  ROUND(AVG(TIMESTAMPDIFF(HOUR, booking_date, actual_eta)), 1)     AS avg_delivery_hrs,
  MAX(TIMESTAMPDIFF(HOUR, booking_date, actual_eta))               AS max_delivery_hrs
FROM shipments
WHERE actual_eta IS NOT NULL AND booking_date IS NOT NULL
GROUP BY origin_location, destination_location
ORDER BY avg_delivery_hrs DESC
LIMIT 15;

-- ------------------------------------------------------------
-- Q5: Peak booking days (top 10 busiest)
-- ------------------------------------------------------------
SELECT
  DATE(booking_date) AS booking_day,
  COUNT(*)           AS bookings
FROM shipments
WHERE booking_date IS NOT NULL
GROUP BY booking_day
ORDER BY bookings DESC
LIMIT 10;

-- ------------------------------------------------------------
-- Q6: Most shipped materials
-- ------------------------------------------------------------
SELECT
  material_shipped,
  COUNT(*)                                                     AS shipment_count,
  ROUND(AVG(transportation_distance_km), 1)                    AS avg_distance_km,
  SUM(CASE WHEN ontime = 'No' THEN 1 ELSE 0 END)               AS delayed_count
FROM shipments
GROUP BY material_shipped
ORDER BY shipment_count DESC
LIMIT 15;

-- ------------------------------------------------------------
-- Q7: Vehicle type performance
-- ------------------------------------------------------------
SELECT
  vehicle_type,
  COUNT(*)                                                                AS trips,
  ROUND(AVG(transportation_distance_km), 1)                               AS avg_distance_km,
  ROUND(100.0 * SUM(CASE WHEN ontime = 'No' THEN 1 ELSE 0 END) / COUNT(*), 1) AS delay_rate_pct
FROM shipments
WHERE vehicle_type != ''
GROUP BY vehicle_type
ORDER BY trips DESC;

-- ------------------------------------------------------------
-- Q8: Delay hotspots (current locations with most delays)
-- ------------------------------------------------------------
SELECT
  current_location,
  COUNT(*) AS delay_count
FROM shipments
WHERE ontime = 'No'
GROUP BY current_location
ORDER BY delay_count DESC
LIMIT 10;

-- ------------------------------------------------------------
-- Q9: Top customers by volume + delay count
-- ------------------------------------------------------------
SELECT
  customer_name,
  COUNT(*)                                          AS total_shipments,
  SUM(CASE WHEN ontime = 'No' THEN 1 ELSE 0 END)   AS `delayed`
FROM shipments
GROUP BY customer_name
ORDER BY total_shipments DESC
LIMIT 10;

-- ------------------------------------------------------------
-- Q10: Monthly shipment trend
-- ------------------------------------------------------------
SELECT
  DATE_FORMAT(booking_date, '%Y-%m') AS month,
  COUNT(*)                           AS total_shipments,
  SUM(CASE WHEN ontime = 'Yes' THEN 1 ELSE 0 END) AS on_time,
  SUM(CASE WHEN ontime = 'No'  THEN 1 ELSE 0 END) AS `delayed`
FROM shipments
WHERE booking_date IS NOT NULL
GROUP BY month
ORDER BY month;