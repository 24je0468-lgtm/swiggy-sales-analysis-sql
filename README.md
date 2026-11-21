# Swiggy Sales Analysis using MySQL

An end-to-end SQL data analytics project that explores a Swiggy food delivery dataset containing approximately 197K records. The project focuses on data cleaning, database design, dimensional modelling, and extracting meaningful business insights using MySQL.

## Project Overview

This project uses SQL to analyse food delivery listing data and understand patterns across restaurants, locations, food categories, dishes, pricing, and customer ratings.

The objective is to transform raw data into a structured analytical database and perform business-oriented analysis using MySQL.

## Tech Stack

- **Database:** MySQL 8.0
- **Language:** SQL
- **Tools:** MySQL Workbench
- **Concepts:** Data Cleaning, Data Deduplication, Star Schema, CTEs, Window Functions, Aggregate Functions, Joins, Indexing and Analytical Queries.

## Dataset Overview

The dataset contains approximately 197K records and 10 columns.

| Column | Description |
|---|---|
| State | State associated with the listing |
| City | City associated with the listing |
| Order Date | Date field provided in the dataset |
| Restaurant Name | Restaurant name |
| Location | Restaurant locality |
| Category | Food category |
| Dish Name | Name of the dish |
| Price (INR) | Listed dish price |
| Rating | Restaurant or dish rating |
| Rating Count | Number of ratings |

## Project Workflow

### 1. Data Loading
- Imported raw CSV data into MySQL using `LOAD DATA LOCAL INFILE`.
- Created a staging table to store the original dataset.
- Performed initial data inspection and validation.

### 2. Data Cleaning
- Identified and removed duplicate records.
- Standardized data fields and formats.
- Converted date values into appropriate SQL date formats.
- Validated data consistency before loading it into the analytical model.

### 3. Database Design – Star Schema

Designed a Star Schema to organize the cleaned data and support efficient analytical queries.

**Dimension Tables:**
- `dim_date` – Date-related attributes such as year, month, quarter and weekday.
- `dim_location` – State, city and locality information.
- `dim_restaurant` – Restaurant details.
- `dim_category` – Food category information.
- `dim_dish` – Dish details.

**Fact Table:**
- `fact_swiggy` – Stores measurable attributes such as listed price, rating and rating count, along with references to dimension tables.

### 4. SQL Analysis

Performed analytical queries across multiple business dimensions:

**Time-Based Analysis**
- Yearly, quarterly and monthly trends.
- Weekday-wise distribution.
- Time-based changes in dataset records.

**Geographical Analysis**
- State-wise and city-wise distribution.
- Location-based restaurant analysis.
- Identification of locations with the highest representation.

**Restaurant Analysis**
- Restaurants with the highest number of listings.
- Restaurant-level rating comparisons.

**Category and Dish Analysis**
- Most frequently listed food categories.
- Popular dishes across locations.
- Category-wise and dish-wise comparisons.

**Pricing Analysis**
- Distribution of listed dish prices.
- Price segmentation into different price bands.
- Category-wise price comparisons.

**Rating Analysis**
- Rating distribution.
- Restaurant and category-level rating comparisons.
- Analysis of rating counts.

## How to Run the Project

1. Install MySQL 8.0 and MySQL Workbench.
2. Clone or download this repository.
3. Place the dataset CSV file in the appropriate directory.
4. Update the CSV file path in the `LOAD DATA LOCAL INFILE` statement.
5. Enable local data loading for the MySQL server and Workbench connection if required.
6. Open the SQL script in MySQL Workbench.
7. Execute the script and review the generated analytical outputs.

## Key Learning Outcomes

- Practical application of SQL for large-scale data analysis.
- Handling duplicate records and data inconsistencies.
- Designing relational databases using dimensional modelling.
- Implementing Star Schema architecture.
- Writing analytical queries using CTEs and window functions.
- Extracting business insights through aggregation and segmentation.

## Important Data Limitations

- The source dataset does not contain a verified unique order ID or customer ID.
- Record counts represent dataset records, not necessarily confirmed unique orders.
- Listed dish prices should not be interpreted as actual revenue or customer spending.
- Price segmentation represents listed dish price ranges.

## Future Improvements

- Build an interactive Power BI dashboard using the cleaned analytical database.
- Add automated data validation and refresh workflows.
- Include visual reports and documented analytical findings.

## Author

**Tanishq Raj**  
B.Tech – Mining Engineering  
IIT (ISM) Dhanbad

GitHub: [24je0468-lgtm](https://github.com/24je0468-lgtm)
