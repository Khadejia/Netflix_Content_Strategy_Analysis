-- ============================================================================
-- PROJECT:     Netflix Content Strategy Analysis (2016–2021)
-- DATABASE:    PostgreSQL
-- AUTHOR:      Khadejia Viveros
--
-- PROJECT OVERVIEW:
-- This script runs the end-to-end data pipeline for cleaning, transforming, 
-- and modeling the Netflix global catalog dataset. It converts text strings 
-- into standard tables, separates duration units, standardizes primary genres, 
-- and outputs optimized tables engineered for Tableau dashboards.
-- ============================================================================

-- ============================================================
-- SECTION 1: CREATE STAGING TABLE
-- Raw table structure to match the original Kaggle CSV file.
-- ============================================================

CREATE TABLE netflix_staging (
    show_id         VARCHAR(10),
    type            VARCHAR(20),
    title           VARCHAR(300),
    director        VARCHAR(300),
    cast_members    VARCHAR(1000),
    country         VARCHAR(300),
    date_added      VARCHAR(50),
    release_year    INTEGER,
    rating          VARCHAR(20),
    duration        VARCHAR(20),
    listed_in       VARCHAR(300),
    description     TEXT
);

-- ============================================================
-- SECTION 2: DATA IMPORT OVERVIEW
-- Background on where the dataset comes from.
-- ============================================================

-- Load netflix_titles.csv into netflix_staging via local import or copy tool.
-- Source: Kaggle — Netflix Movies and TV Shows
-- File: netflix_titles.csv (~8,800 rows, 12 columns)

-- ============================================================
-- SECTION 3: DATA VALIDATION
-- Check row counts and basic categories before making changes.
-- ============================================================

SELECT 
    COUNT(*) AS total_rows 
FROM netflix_staging;

SELECT 
    * FROM netflix_staging 
LIMIT 5;

SELECT 
    type, 
    COUNT(*) AS count
FROM netflix_staging
GROUP BY 
    type;

-- ============================================================
-- SECTION 4: CREATE WORKING TABLE
-- Create a copy of the raw data to clean and transform safely.
-- ============================================================

CREATE TABLE netflix_working AS
SELECT 
    * FROM netflix_staging;

-- ============================================================
-- SECTION 5: IDENTIFY AND REMOVE DUPLICATE RECORDS
-- Finds duplicate records and deletes them using database CTIDs.
-- ============================================================

-- Check for baseline duplicates
SELECT
    COUNT(*) AS duplicate_records
FROM (
    SELECT
        title,
        type,
        release_year,
        COUNT(*)
    FROM netflix_working
    GROUP BY
        title,
        type,
        release_year
    HAVING COUNT(*) > 1
) duplicates;

-- Delete duplicate rows and keep the first occurrence
DELETE FROM netflix_working
WHERE ctid IN (
    SELECT 
        ctid
    FROM (
        SELECT 
            ctid,
            ROW_NUMBER() OVER (
                PARTITION BY 
                    title, 
                    type, 
                    release_year
                ORDER BY 
                    show_id
            ) AS row_num
        FROM netflix_working
    ) dupes
    WHERE row_num > 1
);

SELECT 
    COUNT(*) AS rows_after_dedup 
FROM netflix_working;

-- ============================================================
-- SECTION 6: DATE PROCESSING
-- Converts text dates into standard date, year, and month columns.
-- ============================================================

ALTER TABLE netflix_working 
    ADD COLUMN date_added_clean DATE,
    ADD COLUMN year_added       INTEGER,
    ADD COLUMN month_added      VARCHAR(7);

UPDATE netflix_working
SET date_added_clean = TO_DATE(date_added, 'Month DD, YYYY')
WHERE date_added IS NOT NULL 
  AND TRIM(date_added) != '';

UPDATE netflix_working
SET year_added  = EXTRACT(YEAR FROM date_added_clean),
    month_added = TO_CHAR(date_added_clean, 'YYYY-MM')
WHERE date_added_clean IS NOT NULL;

-- ============================================================
-- SECTION 7: EXTRACT PRIMARY GENRE
-- Pulls the first genre from the list to create a clean category.
-- ============================================================

ALTER TABLE netflix_working 
    ADD COLUMN primary_genre VARCHAR(100);

UPDATE netflix_working
SET primary_genre =
    CASE
        WHEN SPLIT_PART(listed_in, ',', 1) ILIKE '%International Movies%'  THEN 'International Movies'
        WHEN SPLIT_PART(listed_in, ',', 1) ILIKE '%International TV%'      THEN 'International TV Shows'
        WHEN SPLIT_PART(listed_in, ',', 1) ILIKE '%Documentar%'            THEN 'Documentaries'
        WHEN SPLIT_PART(listed_in, ',', 1) = 'Docuseries'                  THEN 'Documentaries'
        WHEN SPLIT_PART(listed_in, ',', 1) ILIKE '%Stand-Up%'              THEN 'Stand-Up Comedy'
        WHEN SPLIT_PART(listed_in, ',', 1) ILIKE '%Stand Up%'               THEN 'Stand-Up Comedy'
        WHEN SPLIT_PART(listed_in, ',', 1) ILIKE '%Anime%'                  THEN 'Anime'
        WHEN SPLIT_PART(listed_in, ',', 1) ILIKE '%Reality%'                THEN 'Reality TV'
        WHEN SPLIT_PART(listed_in, ',', 1) = 'TV Dramas'                   THEN 'Dramas'
        WHEN SPLIT_PART(listed_in, ',', 1) = 'TV Comedies'                 THEN 'Comedies'
        WHEN SPLIT_PART(listed_in, ',', 1) ILIKE '%Children%'              THEN 'Children & Family'
        WHEN SPLIT_PART(listed_in, ',', 1) ILIKE '%Kids%'                  THEN 'Children & Family'
        WHEN SPLIT_PART(listed_in, ',', 1) ILIKE '%Family%'                THEN 'Children & Family'
        WHEN SPLIT_PART(listed_in, ',', 1) IS NULL                         THEN 'Unknown'
        WHEN TRIM(SPLIT_PART(listed_in, ',', 1)) = ''                      THEN 'Unknown'
        ELSE TRIM(SPLIT_PART(listed_in, ',', 1))
    END;

-- ============================================================
-- SECTION 8: STANDARDIZE COUNTRY DATA
-- Standardizes country fields and fixes abbreviations like USA or UK.
-- ============================================================

ALTER TABLE netflix_working 
    ADD COLUMN primary_country VARCHAR(100);

UPDATE netflix_working
SET primary_country =
    CASE
        WHEN country ILIKE '%united states%' THEN 'United States'
        WHEN country ILIKE '%usa%'           THEN 'United States'
        WHEN country ILIKE '%united kingdom%' THEN 'United Kingdom'
        WHEN country ILIKE '%uk%'            THEN 'United Kingdom'
        WHEN country ILIKE '%south korea%'    THEN 'South Korea'
        WHEN country ILIKE '%korea%'          THEN 'South Korea'
        WHEN country IS NULL                 THEN 'Unknown'
        WHEN TRIM(country) = ''              THEN 'Unknown'
        ELSE TRIM(SPLIT_PART(country, ',', 1))
    END;

-- ============================================================
-- SECTION 9: FILL MISSING VALUES
-- Replaces blank spaces or empty text with standard 'Unknown' labels.
-- ============================================================

UPDATE netflix_working
SET
    director = COALESCE(NULLIF(TRIM(director), ''), 'Unknown'),
    cast_members = COALESCE(NULLIF(TRIM(cast_members), ''), 'Unknown'),
    rating = COALESCE(NULLIF(TRIM(rating), ''), 'Unknown');

-- ============================================================
-- SECTION 10: DURATION PROCESSING & FEATURE ENGINEERING
-- Splits runtimes into numbers and units, and groups content ratings.
-- ============================================================

-- Separate runtime numbers from the text units
ALTER TABLE netflix_working 
    ADD COLUMN duration_value INTEGER,
    ADD COLUMN duration_unit  VARCHAR(20);

UPDATE netflix_working
SET duration_value = CAST(SPLIT_PART(duration, ' ', 1) AS INTEGER),
    duration_unit  = TRIM(SPLIT_PART(duration, ' ', 2))
WHERE duration IS NOT NULL 
  AND duration ~ '^\d+';

UPDATE netflix_working SET duration_unit = 'min'     WHERE duration_unit ILIKE '%min%';
UPDATE netflix_working SET duration_unit = 'Seasons' WHERE duration_unit ILIKE '%season%';

-- Group age ratings into simpler categories for charts
ALTER TABLE netflix_working 
    ADD COLUMN rating_category VARCHAR(30);

UPDATE netflix_working
SET rating_category =
    CASE
        WHEN rating IN ('G', 'TV-G', 'TV-Y', 'TV-Y7', 'TV-Y7-FV') THEN 'Kids'
        WHEN rating IN ('PG', 'TV-PG')                            THEN 'Family'
        WHEN rating IN ('PG-13', 'TV-14')                         THEN 'Teen'
        WHEN rating IN ('R', 'TV-MA', 'NC-17')                    THEN 'Adult'
        WHEN rating IN ('NR', 'UR')                               THEN 'Unrated'
        ELSE 'Other'
    END;

-- ============================================================================
-- SECTION 11: QUALITY ASSURANCE (QA) CHECK
-- Drops incomplete rows and checks the final clean row count before exporting.
-- ============================================================================

DELETE FROM netflix_working
WHERE title IS NULL
  AND type IS NULL
  AND release_year IS NULL;

SELECT 
    COUNT(*) AS final_rows 
FROM netflix_working;

-- ============================================================
-- SECTION 12: CREATE FINAL ANALYTICS TABLE
-- The clean, final data collection structure built to connect directly to Tableau.
-- ============================================================

CREATE TABLE netflix_catalog AS
SELECT
    show_id,
    type,
    title,
    director,
    cast_members,
    country,
    primary_country,
    date_added_clean AS date_added,
    year_added,
    month_added,
    release_year,
    rating,
    rating_category,
    duration,
    duration_value,
    duration_unit,
    listed_in AS all_genres,
    primary_genre,
    description
FROM netflix_working
WHERE title IS NOT NULL
  AND type IS NOT NULL;

-- ============================================================
-- SECTION 13: CREATE INDEXES FOR PERFORMANCE
-- Speeds up search and filter queries inside dashboard charts.
-- ============================================================

CREATE INDEX idx_netflix_type ON netflix_catalog(type);
CREATE INDEX idx_netflix_country ON netflix_catalog(primary_country);
CREATE INDEX idx_netflix_genre ON netflix_catalog(primary_genre);
CREATE INDEX idx_netflix_year ON netflix_catalog(year_added);
CREATE INDEX idx_release_year ON netflix_catalog(release_year);
CREATE INDEX idx_rating ON netflix_catalog(rating_category);

-- ============================================================
-- SECTION 14: TABLEAU DASHBOARD QUERIES
-- High-level aggregations designed to feed charts and dynamic KPIs.
-- ============================================================

-- [KPI BLOCK]: Summary numbers for dashboard scorecard elements
SELECT
    COUNT(*) AS total_titles,
    SUM(CASE WHEN type = 'Movie' THEN 1 ELSE 0 END) AS movies,
    SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END) AS tv_shows,
    COUNT(DISTINCT primary_country) AS countries
FROM netflix_catalog
WHERE primary_country != 'Unknown';

-- [GROWTH TIMELINE]: Total movies and shows added year over year
SELECT
    year_added,
    type,
    COUNT(*) AS titles_added
FROM netflix_catalog
GROUP BY 
    year_added, 
    type
ORDER BY 
    year_added;

-- [GENRE RANKINGS]: Top 15 content groups across distribution pipelines
SELECT
    primary_genre,
    COUNT(*) AS title_count
FROM netflix_catalog
WHERE primary_genre != 'Unknown'
GROUP BY 
    primary_genre
ORDER BY 
    title_count DESC
LIMIT 15;

-- [MAP VISUALIZATION]: Number of titles by country
SELECT
    primary_country,
    COUNT(*) AS total_titles
FROM netflix_catalog
WHERE primary_country != 'Unknown'
GROUP BY 
    primary_country
ORDER BY 
    total_titles DESC;

-- [PIE CHART]: Share percentage split between movies and shows
SELECT
    type,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM netflix_catalog
GROUP BY 
    type;

-- [BAR CHART]: Breakdown of content ratings and maturity share
SELECT
    rating_category,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM netflix_catalog
GROUP BY 
    rating_category
ORDER BY 
    count DESC;

-- [LEADERBOARD]: Top 15 creative directors by output density
SELECT
    director,
    COUNT(*) AS title_count
FROM netflix_catalog
WHERE director IS NOT NULL 
  AND director != ''
GROUP BY 
    director
ORDER BY 
    title_count DESC
LIMIT 15;

-- [HEATMAP]: Shows how genres have changed year over year
SELECT
    year_added,
    primary_genre,
    COUNT(*) AS titles
FROM netflix_catalog
WHERE primary_genre != 'Unknown'
GROUP BY 
    year_added, 
    primary_genre
ORDER BY 
    year_added;

-- ============================================================
-- SECTION 15: MASTER PORTFOLIO EXPORT
-- The main query used to pull the clean records out for Tableau.
-- ============================================================

SELECT 
    * FROM netflix_catalog;

-- ============================================================
-- SECTION 16: ADVANCED SQL EXPLORATION
-- Uses CTEs, Window Functions, and Ranking queries to find insights.
-- ============================================================

-- [CTE]: Summarizes total catalog volumes inside country scopes
WITH country_totals AS (
    SELECT
        primary_country,
        COUNT(*) AS titles
    FROM netflix_catalog
    GROUP BY 
        primary_country
)
SELECT 
    primary_country,
    titles
FROM country_totals
ORDER BY 
    titles DESC;

-- [RANK]: Ranks global production countries by title count
SELECT
    primary_country,
    COUNT(*) AS titles,
    RANK() OVER (
        ORDER BY COUNT(*) DESC
    ) AS country_rank
FROM netflix_catalog
GROUP BY 
    primary_country;

-- [DENSE RANK]: Breaks down genre performance sequences safely
SELECT
    primary_genre,
    COUNT(*) AS titles,
    DENSE_RANK() OVER (
        ORDER BY COUNT(*) DESC
    ) AS genre_rank
FROM netflix_catalog
GROUP BY 
    primary_genre;

-- [RUNNING TOTAL]: Calculates the total historical content scale across upload years
SELECT
    year_added,
    COUNT(*) AS titles,
    SUM(COUNT(*)) OVER (
        ORDER BY year_added
    ) AS running_total
FROM netflix_catalog
GROUP BY 
    year_added;

-- [LAG]: Compares annual catalog updates with the prior year's numbers
WITH yearly AS (
    SELECT
        year_added,
        COUNT(*) AS titles
    FROM netflix_catalog
    GROUP BY 
        year_added
)
SELECT
    year_added,
    titles,
    LAG(titles) OVER (
        ORDER BY year_added
    ) AS previous_year,
    titles - LAG(titles) OVER (
        ORDER BY year_added
    ) AS change
FROM yearly;

-- [ROW NUMBER]: Finds the top 3 biggest genres in every single country
WITH ranked_genres AS (
    SELECT
        primary_country,
        primary_genre,
        COUNT(*) AS titles,
        ROW_NUMBER() OVER (
            PARTITION BY primary_country
            ORDER BY COUNT(*) DESC
        ) AS ranking
    FROM netflix_catalog
    GROUP BY
        primary_country,
        primary_genre
)
SELECT 
    primary_country,
    primary_genre,
    titles,
    ranking
FROM ranked_genres
WHERE ranking <= 3;

-- [SUBQUERY]: Flags long-form movies that are longer than the overall global average
SELECT
    title,
    duration_value
FROM netflix_catalog
WHERE duration_unit = 'min'
  AND duration_value > (
      SELECT 
          AVG(duration_value)
      FROM netflix_catalog
      WHERE duration_unit = 'min'
  );

-- [WINDOW PERCENT OVER]: Calculates media category ratios against global database volumes
SELECT
    type,
    COUNT(*) AS titles,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 
        2
    ) AS pct_total
FROM netflix_catalog
GROUP BY 
    type;

-- [HAVING CLAUSE]: Finds active directors with at least five titles on the platform
SELECT
    director,
    COUNT(*) AS titles
FROM netflix_catalog
WHERE director <> 'Unknown'
GROUP BY 
    director
HAVING COUNT(*) >= 5
ORDER BY 
    titles DESC;

-- [COMPLEX GROUPING]: Computes movie runtimes for categories with at least 10 titles
SELECT
    primary_genre,
    ROUND(AVG(duration_value), 1) AS avg_runtime,
    COUNT(*) AS movies
FROM netflix_catalog
WHERE duration_unit = 'min'
GROUP BY 
    primary_genre
HAVING COUNT(*) >= 10
ORDER BY 
    avg_runtime DESC;
