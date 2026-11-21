-- 0. Database setup

CREATE DATABASE IF NOT EXISTS swiggy_sales
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE swiggy_sales;


-- 1. Import the raw dataset

DROP TABLE IF EXISTS fact_swiggy_orders;
DROP TABLE IF EXISTS dim_dish;
DROP TABLE IF EXISTS dim_category;
DROP TABLE IF EXISTS dim_restaurant;
DROP TABLE IF EXISTS dim_location;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS swiggy_clean;
DROP TABLE IF EXISTS stg_swiggy_data;

CREATE TABLE stg_swiggy_data (
    state            VARCHAR(100),
    city             VARCHAR(100),
    order_date       VARCHAR(30),
    restaurant_name  VARCHAR(255),
    location         VARCHAR(255),
    category         VARCHAR(100),
    dish_name        VARCHAR(255),
    price_inr        VARCHAR(30),
    rating           VARCHAR(30),
    rating_count     VARCHAR(30)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4;

LOAD DATA LOCAL INFILE
'C:/Users/Tanishq Raj/Desktop/Data Analyst/SwiggySQL/Swiggy_Data.csv'
INTO TABLE stg_swiggy_data
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    state,
    city,
    order_date,
    restaurant_name,
    location,
    category,
    dish_name,
    price_inr,
    rating,
    rating_count
);

SELECT COUNT(*) AS source_records
FROM stg_swiggy_data;


-- 2. Initial data quality checks

-- 2A. Check for NULL values.

SELECT
    SUM(state IS NULL) AS null_state,
    SUM(city IS NULL) AS null_city,
    SUM(order_date IS NULL) AS null_order_date,
    SUM(restaurant_name IS NULL) AS null_restaurant,
    SUM(location IS NULL) AS null_location,
    SUM(category IS NULL) AS null_category,
    SUM(dish_name IS NULL) AS null_dish,
    SUM(price_inr IS NULL) AS null_price,
    SUM(rating IS NULL) AS null_rating,
    SUM(rating_count IS NULL) AS null_rating_count
FROM stg_swiggy_data;


-- 2B. Check for blank values.

SELECT
    SUM(TRIM(COALESCE(state, '')) = '') AS blank_state,
    SUM(TRIM(COALESCE(city, '')) = '') AS blank_city,
    SUM(TRIM(COALESCE(order_date, '')) = '') AS blank_order_date,
    SUM(TRIM(COALESCE(restaurant_name, '')) = '') AS blank_restaurant,
    SUM(TRIM(COALESCE(location, '')) = '') AS blank_location,
    SUM(TRIM(COALESCE(category, '')) = '') AS blank_category,
    SUM(TRIM(COALESCE(dish_name, '')) = '') AS blank_dish,
    SUM(TRIM(COALESCE(price_inr, '')) = '') AS blank_price,
    SUM(TRIM(COALESCE(rating, '')) = '') AS blank_rating,
    SUM(TRIM(COALESCE(rating_count, '')) = '') AS blank_rating_count
FROM stg_swiggy_data;


-- 2C. Identify exact duplicate records.

SELECT
    state,
    city,
    order_date,
    restaurant_name,
    location,
    category,
    dish_name,
    price_inr,
    rating,
    rating_count,
    COUNT(*) AS duplicate_count
FROM stg_swiggy_data
GROUP BY
    state,
    city,
    order_date,
    restaurant_name,
    location,
    category,
    dish_name,
    price_inr,
    rating,
    rating_count
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;


-- 3. Data cleaning and deduplication

CREATE TABLE swiggy_clean (
    state            VARCHAR(100) NOT NULL,
    city             VARCHAR(100) NOT NULL,
    order_date       DATE NOT NULL,
    restaurant_name  VARCHAR(255) NOT NULL,
    location         VARCHAR(255) NOT NULL,
    category         VARCHAR(100) NOT NULL,
    dish_name        VARCHAR(255) NOT NULL,
    price_inr        DECIMAL(10,2) NOT NULL,
    rating           DECIMAL(3,2) NULL,
    rating_count     INT NULL
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4;

INSERT INTO swiggy_clean (
    state,
    city,
    order_date,
    restaurant_name,
    location,
    category,
    dish_name,
    price_inr,
    rating,
    rating_count
)
WITH normalized AS (
    SELECT
        NULLIF(TRIM(state), '') AS state,
        NULLIF(TRIM(city), '') AS city,
        STR_TO_DATE(TRIM(order_date), '%d-%m-%Y') AS order_date,
        NULLIF(TRIM(restaurant_name), '') AS restaurant_name,
        NULLIF(TRIM(location), '') AS location,
        NULLIF(TRIM(category), '') AS category,
        NULLIF(TRIM(dish_name), '') AS dish_name,

        CASE
            WHEN TRIM(price_inr) REGEXP '^[0-9]+([.][0-9]+)?$'
            THEN CAST(TRIM(price_inr) AS DECIMAL(10,2))
            ELSE NULL
        END AS price_inr,

        CASE
            WHEN TRIM(rating) REGEXP '^[0-9]+([.][0-9]+)?$'
            THEN CAST(TRIM(rating) AS DECIMAL(3,2))
            ELSE NULL
        END AS rating,

        CASE
            WHEN TRIM(rating_count) REGEXP '^[0-9]+$'
            THEN CAST(TRIM(rating_count) AS UNSIGNED)
            ELSE NULL
        END AS rating_count

    FROM stg_swiggy_data
),
ranked AS (
    SELECT
        normalized.*,

        ROW_NUMBER() OVER (
            PARTITION BY
                state,
                city,
                order_date,
                restaurant_name,
                location,
                category,
                dish_name,
                price_inr,
                rating,
                rating_count
            ORDER BY
                state,
                city,
                restaurant_name,
                dish_name
        ) AS row_num

    FROM normalized
)

SELECT
    state,
    city,
    order_date,
    restaurant_name,
    location,
    category,
    dish_name,
    price_inr,
    rating,
    rating_count
FROM ranked
WHERE row_num = 1
  AND state IS NOT NULL
  AND city IS NOT NULL
  AND order_date IS NOT NULL
  AND restaurant_name IS NOT NULL
  AND location IS NOT NULL
  AND category IS NOT NULL
  AND dish_name IS NOT NULL
  AND price_inr IS NOT NULL
  AND price_inr >= 0
  AND (rating IS NULL OR rating BETWEEN 0 AND 5)
  AND (rating_count IS NULL OR rating_count >= 0);


-- 3A. Compare source and cleaned records.

SELECT
    (SELECT COUNT(*) FROM stg_swiggy_data) AS source_records,
    (SELECT COUNT(*) FROM swiggy_clean) AS cleaned_records,
    (SELECT COUNT(*) FROM stg_swiggy_data)
      - (SELECT COUNT(*) FROM swiggy_clean) AS records_removed;


-- 3B. Verify that duplicates have been removed.

SELECT COUNT(*) AS remaining_duplicate_groups
FROM (
    SELECT
        state,
        city,
        order_date,
        restaurant_name,
        location,
        category,
        dish_name,
        price_inr,
        rating,
        rating_count
    FROM swiggy_clean
    GROUP BY
        state,
        city,
        order_date,
        restaurant_name,
        location,
        category,
        dish_name,
        price_inr,
        rating,
        rating_count
    HAVING COUNT(*) > 1
) AS duplicate_check;


-- Indexes for faster dimension joins.

ALTER TABLE swiggy_clean
    ADD INDEX idx_clean_location (state, city, location),
    ADD INDEX idx_clean_restaurant (restaurant_name),
    ADD INDEX idx_clean_category (category),
    ADD INDEX idx_clean_dish (dish_name);


-- 4. Create dimension tables

CREATE TABLE dim_date (
    date_id       INT PRIMARY KEY,
    full_date     DATE NOT NULL UNIQUE,
    year          SMALLINT NOT NULL,
    quarter       TINYINT NOT NULL,
    month         TINYINT NOT NULL,
    month_name    VARCHAR(15) NOT NULL,
    day           TINYINT NOT NULL,
    day_name      VARCHAR(15) NOT NULL,
    week          TINYINT NOT NULL
) ENGINE = InnoDB;


CREATE TABLE dim_location (
    location_id   INT AUTO_INCREMENT PRIMARY KEY,
    state         VARCHAR(100) NOT NULL,
    city          VARCHAR(100) NOT NULL,
    location      VARCHAR(255) NOT NULL,
    UNIQUE KEY uq_location (state, city, location)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4;


CREATE TABLE dim_restaurant (
    restaurant_id   INT AUTO_INCREMENT PRIMARY KEY,
    restaurant_name VARCHAR(255) NOT NULL UNIQUE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4;


CREATE TABLE dim_category (
    category_id   INT AUTO_INCREMENT PRIMARY KEY,
    category      VARCHAR(100) NOT NULL UNIQUE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4;


CREATE TABLE dim_dish (
    dish_id       INT AUTO_INCREMENT PRIMARY KEY,
    dish_name     VARCHAR(255) NOT NULL UNIQUE
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4;


-- 5. Populate dimension tables

INSERT INTO dim_date (
    date_id,
    full_date,
    year,
    quarter,
    month,
    month_name,
    day,
    day_name,
    week
)
SELECT DISTINCT
    CAST(DATE_FORMAT(order_date, '%Y%m%d') AS UNSIGNED),
    order_date,
    YEAR(order_date),
    QUARTER(order_date),
    MONTH(order_date),
    MONTHNAME(order_date),
    DAY(order_date),
    DAYNAME(order_date),
    WEEK(order_date, 3)
FROM swiggy_clean;


INSERT INTO dim_location (state, city, location)
SELECT DISTINCT
    state,
    city,
    location
FROM swiggy_clean;


INSERT INTO dim_restaurant (restaurant_name)
SELECT DISTINCT restaurant_name
FROM swiggy_clean;


INSERT INTO dim_category (category)
SELECT DISTINCT category
FROM swiggy_clean;


INSERT INTO dim_dish (dish_name)
SELECT DISTINCT dish_name
FROM swiggy_clean;


-- 6. Create and populate the fact table

CREATE TABLE fact_swiggy_orders (
    order_id       BIGINT AUTO_INCREMENT PRIMARY KEY,
    date_id        INT NOT NULL,
    location_id    INT NOT NULL,
    restaurant_id  INT NOT NULL,
    category_id    INT NOT NULL,
    dish_id        INT NOT NULL,
    price_inr      DECIMAL(10,2) NOT NULL,
    rating         DECIMAL(3,2) NULL,
    rating_count   INT NULL
) ENGINE = InnoDB;

INSERT INTO fact_swiggy_orders (
    date_id,
    location_id,
    restaurant_id,
    category_id,
    dish_id,
    price_inr,
    rating,
    rating_count
)
SELECT
    CAST(DATE_FORMAT(s.order_date, '%Y%m%d') AS UNSIGNED),
    l.location_id,
    r.restaurant_id,
    c.category_id,
    d.dish_id,
    s.price_inr,
    s.rating,
    s.rating_count
FROM swiggy_clean AS s
INNER JOIN dim_location AS l
    ON s.state = l.state
   AND s.city = l.city
   AND s.location = l.location
INNER JOIN dim_restaurant AS r
    ON s.restaurant_name = r.restaurant_name
INNER JOIN dim_category AS c
    ON s.category = c.category
INNER JOIN dim_dish AS d
    ON s.dish_name = d.dish_name;


SELECT
    (SELECT COUNT(*) FROM swiggy_clean) AS clean_records,
    (SELECT COUNT(*) FROM fact_swiggy_orders) AS fact_records;


ALTER TABLE fact_swiggy_orders
    ADD INDEX idx_fact_date (date_id),
    ADD INDEX idx_fact_location (location_id),
    ADD INDEX idx_fact_restaurant (restaurant_id),
    ADD INDEX idx_fact_category (category_id),
    ADD INDEX idx_fact_dish (dish_id);


ALTER TABLE fact_swiggy_orders
    ADD CONSTRAINT fk_fact_date
        FOREIGN KEY (date_id)
        REFERENCES dim_date(date_id),

    ADD CONSTRAINT fk_fact_location
        FOREIGN KEY (location_id)
        REFERENCES dim_location(location_id),

    ADD CONSTRAINT fk_fact_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES dim_restaurant(restaurant_id),

    ADD CONSTRAINT fk_fact_category
        FOREIGN KEY (category_id)
        REFERENCES dim_category(category_id),

    ADD CONSTRAINT fk_fact_dish
        FOREIGN KEY (dish_id)
        REFERENCES dim_dish(dish_id);


-- 7. Basic dataset KPIs

SELECT
    COUNT(*) AS total_records,
    ROUND(SUM(price_inr), 2) AS aggregate_dish_price_inr,
    ROUND(SUM(price_inr) / 1000000, 2)
        AS aggregate_dish_price_inr_million,
    ROUND(AVG(price_inr), 2) AS average_dish_price_inr,
    ROUND(AVG(rating), 2) AS average_rating
FROM fact_swiggy_orders;


SELECT
    SUM(rating_count) AS summed_rating_count
FROM fact_swiggy_orders;


-- 8. Date-based analysis

-- 8A. Monthly analysis.

SELECT
    d.year,
    d.month,
    d.month_name,
    COUNT(*) AS total_records,
    ROUND(SUM(f.price_inr), 2) AS aggregate_dish_price_inr
FROM fact_swiggy_orders AS f
INNER JOIN dim_date AS d
    ON f.date_id = d.date_id
GROUP BY
    d.year,
    d.month,
    d.month_name
ORDER BY
    d.year,
    d.month;


-- 8B. Quarterly analysis.

SELECT
    d.year,
    d.quarter,
    COUNT(*) AS total_records,
    ROUND(SUM(f.price_inr), 2) AS aggregate_dish_price_inr
FROM fact_swiggy_orders AS f
INNER JOIN dim_date AS d
    ON f.date_id = d.date_id
GROUP BY
    d.year,
    d.quarter
ORDER BY
    d.year,
    d.quarter;


-- 8C. Year-wise change in aggregate dish-price value.

WITH yearly_summary AS (
    SELECT
        d.year,
        COUNT(*) AS total_records,
        SUM(f.price_inr) AS aggregate_dish_price
    FROM fact_swiggy_orders AS f
    INNER JOIN dim_date AS d
        ON f.date_id = d.date_id
    GROUP BY d.year
),
yearly_comparison AS (
    SELECT
        year,
        total_records,
        aggregate_dish_price,
        LAG(aggregate_dish_price) OVER (ORDER BY year)
            AS previous_year_price_value
    FROM yearly_summary
)

SELECT
    year,
    total_records,
    ROUND(aggregate_dish_price, 2) AS aggregate_dish_price_inr,
    ROUND(
        100 * (
            aggregate_dish_price - previous_year_price_value
        ) / NULLIF(previous_year_price_value, 0),
        2
    ) AS change_percent_from_previous_year
FROM yearly_comparison
ORDER BY year;


-- 8D. Day-of-week analysis.

SELECT
    d.day_name,
    COUNT(*) AS total_records,
    ROUND(SUM(f.price_inr), 2) AS aggregate_dish_price_inr
FROM fact_swiggy_orders AS f
INNER JOIN dim_date AS d
    ON f.date_id = d.date_id
GROUP BY
    WEEKDAY(d.full_date),
    d.day_name
ORDER BY
    WEEKDAY(d.full_date);


-- 9. Location-based analysis

-- 9A. Top 10 cities by number of records.

SELECT
    l.city,
    l.state,
    COUNT(*) AS total_records,
    ROUND(SUM(f.price_inr), 2) AS aggregate_dish_price_inr
FROM fact_swiggy_orders AS f
INNER JOIN dim_location AS l
    ON f.location_id = l.location_id
GROUP BY
    l.city,
    l.state
ORDER BY
    total_records DESC,
    l.city
LIMIT 10;


-- 9B. State-wise share of aggregate dish-price value.

SELECT
    l.state,
    ROUND(SUM(f.price_inr), 2) AS aggregate_dish_price_inr,
    ROUND(
        100 * SUM(f.price_inr)
        / NULLIF(
            (SELECT SUM(price_inr) FROM fact_swiggy_orders),
            0
        ),
        2
    ) AS share_percent
FROM fact_swiggy_orders AS f
INNER JOIN dim_location AS l
    ON f.location_id = l.location_id
GROUP BY l.state
ORDER BY aggregate_dish_price_inr DESC;


-- 10. Restaurant and food analysis

-- 10A. Top 10 restaurants by number of records.

SELECT
    r.restaurant_name,
    COUNT(*) AS total_records,
    ROUND(SUM(f.price_inr), 2) AS aggregate_dish_price_inr,
    ROUND(AVG(f.rating), 2) AS average_rating
FROM fact_swiggy_orders AS f
INNER JOIN dim_restaurant AS r
    ON f.restaurant_id = r.restaurant_id
GROUP BY
    r.restaurant_id,
    r.restaurant_name
ORDER BY
    total_records DESC,
    r.restaurant_name
LIMIT 10;


-- 10B. Category-wise analysis.

SELECT
    c.category,
    COUNT(*) AS total_records,
    ROUND(SUM(f.price_inr), 2) AS aggregate_dish_price_inr,
    ROUND(AVG(f.rating), 2) AS average_rating
FROM fact_swiggy_orders AS f
INNER JOIN dim_category AS c
    ON f.category_id = c.category_id
GROUP BY
    c.category_id,
    c.category
ORDER BY
    total_records DESC,
    c.category;


-- 10C. Top 10 most frequently appearing dishes.

SELECT
    d.dish_name,
    COUNT(*) AS total_records,
    ROUND(AVG(f.price_inr), 2) AS average_dish_price_inr,
    ROUND(AVG(f.rating), 2) AS average_rating
FROM fact_swiggy_orders AS f
INNER JOIN dim_dish AS d
    ON f.dish_id = d.dish_id
GROUP BY
    d.dish_id,
    d.dish_name
ORDER BY
    total_records DESC,
    d.dish_name
LIMIT 10;


-- 11. Dish price analysis

SELECT
    price_bucket,
    COUNT(*) AS record_count,
    ROUND(
        100 * COUNT(*) /
        NULLIF((SELECT COUNT(*) FROM fact_swiggy_orders), 0),
        2
    ) AS record_percentage
FROM (
    SELECT
        CASE
            WHEN price_inr < 100 THEN 'Under 100'
            WHEN price_inr < 200 THEN '100-199'
            WHEN price_inr < 300 THEN '200-299'
            WHEN price_inr < 500 THEN '300-499'
            ELSE '500+'
        END AS price_bucket,

        CASE
            WHEN price_inr < 100 THEN 1
            WHEN price_inr < 200 THEN 2
            WHEN price_inr < 300 THEN 3
            WHEN price_inr < 500 THEN 4
            ELSE 5
        END AS bucket_order
    FROM fact_swiggy_orders
) AS price_analysis
GROUP BY
    price_bucket,
    bucket_order
ORDER BY
    bucket_order;


-- 12. Ratings analysis

-- 12A. Exact rating distribution.

SELECT
    rating,
    COUNT(*) AS record_count,
    ROUND(
        100 * COUNT(*) /
        NULLIF(
            (SELECT COUNT(*)
             FROM fact_swiggy_orders
             WHERE rating IS NOT NULL),
            0
        ),
        2
    ) AS percentage_of_rated_records
FROM fact_swiggy_orders
WHERE rating IS NOT NULL
GROUP BY rating
ORDER BY rating;


-- 12B. Rating distribution by whole-number bands.

SELECT
    FLOOR(rating) AS rating_band,
    COUNT(*) AS record_count
FROM fact_swiggy_orders
WHERE rating IS NOT NULL
GROUP BY FLOOR(rating)
ORDER BY rating_band;


-- 13. Final data integrity checks

-- 13A. Row counts across all tables.

SELECT 'dim_date' AS table_name, COUNT(*) AS row_count
FROM dim_date

UNION ALL

SELECT 'dim_location', COUNT(*)
FROM dim_location

UNION ALL

SELECT 'dim_restaurant', COUNT(*)
FROM dim_restaurant

UNION ALL

SELECT 'dim_category', COUNT(*)
FROM dim_category

UNION ALL

SELECT 'dim_dish', COUNT(*)
FROM dim_dish

UNION ALL

SELECT 'fact_swiggy_orders', COUNT(*)
FROM fact_swiggy_orders;


-- 13B. Check for fact records without matching dimension records.

SELECT COUNT(*) AS unmatched_fact_rows
FROM fact_swiggy_orders AS f
LEFT JOIN dim_date AS dt
    ON f.date_id = dt.date_id
LEFT JOIN dim_location AS l
    ON f.location_id = l.location_id
LEFT JOIN dim_restaurant AS r
    ON f.restaurant_id = r.restaurant_id
LEFT JOIN dim_category AS c
    ON f.category_id = c.category_id
LEFT JOIN dim_dish AS d
    ON f.dish_id = d.dish_id
WHERE
    dt.date_id IS NULL
    OR l.location_id IS NULL
    OR r.restaurant_id IS NULL
    OR c.category_id IS NULL
    OR d.dish_id IS NULL;


-- 13C. Compare cleaned and fact table records.

SELECT
    (SELECT COUNT(*) FROM swiggy_clean) AS cleaned_records,
    (SELECT COUNT(*) FROM fact_swiggy_orders) AS fact_records,
    (SELECT COUNT(*) FROM swiggy_clean)
      - (SELECT COUNT(*) FROM fact_swiggy_orders) AS record_difference;
