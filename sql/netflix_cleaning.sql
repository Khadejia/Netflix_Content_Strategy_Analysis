-- ============================================================
-- PROJECT : Netflix Content Strategy Analysis 2015-2025
-- DATABASE: PostgreSQL
-- PURPOSE : Prepare Netflix catalog data for Tableau analysis
-- AUTHOR  : Khadejia Viveros
-- ============================================================

-- DATASET
-- Source: Kaggle — Netflix Movies and TV Shows
-- File: netflix_titles.csv (~8,800 rows, 12 columns)
-- ============================================================


-- ============================================================
-- SECTION 1: STAGING TABLE
-- Base structure matching the Kaggle dataset
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
-- SECTION 2: IMPORT DATA
-- Load netflix_titles.csv into netflix_staging
-- ============================================================


-- ============================================================
-- SECTION 3: DATA VALIDATION
-- ============================================================

SELECT COUNT(*) AS total_rows FROM netflix_staging;

SELECT * FROM netflix_staging LIMIT 5;

SELECT type, COUNT(*) AS count
FROM netflix_staging
GROUP BY type;


-- ============================================================
-- SECTION 4: WORKING TABLE
-- Copy of staging data for transformations
-- ============================================================

CREATE TABLE netflix_working AS
SELECT * FROM netflix_staging;


-- ============================================================
-- SECTION 5: REMOVE DUPLICATES
-- Keeps first occurrence of duplicate titles
-- ============================================================

DELETE FROM netflix_working
WHERE ctid IN (
    SELECT ctid
    FROM (
        SELECT ctid,
               ROW_NUMBER() OVER (
                   PARTITION BY title, type, release_year
                   ORDER BY show_id
               ) AS row_num
        FROM netflix_working
    ) dupes
    WHERE row_num > 1
);

SELECT COUNT(*) AS rows_after_dedup FROM netflix_working;


-- ============================================================
-- SECTION 6: DATE PROCESSING
-- Converts date_added into usable date fields
-- ============================================================

ALTER TABLE netflix_working ADD COLUMN date_added_clean DATE;
ALTER TABLE netflix_working ADD COLUMN year_added       INTEGER;
ALTER TABLE netflix_working ADD COLUMN month_added      VARCHAR(7);

UPDATE netflix_working
SET date_added_clean = TO_DATE(date_added, 'Month DD, YYYY')
WHERE date_added IS NOT NULL AND TRIM(date_added) != '';

UPDATE netflix_working
SET year_added  = EXTRACT(YEAR FROM date_added_clean),
    month_added = TO_CHAR(date_added_clean, 'YYYY-MM')
WHERE date_added_clean IS NOT NULL;


-- ============================================================
-- SECTION 7: PRIMARY GENRE
-- Extracts first genre for simplified analysis
-- ============================================================

ALTER TABLE netflix_working ADD COLUMN primary_genre VARCHAR(100);

UPDATE netflix_working
SET primary_genre = TRIM(SPLIT_PART(listed_in, ',', 1));

UPDATE netflix_working SET primary_genre = 'International Movies'
WHERE primary_genre ILIKE '%International Movies%';

UPDATE netflix_working SET primary_genre = 'International TV Shows'
WHERE primary_genre ILIKE '%International TV%';

UPDATE netflix_working SET primary_genre = 'Documentaries'
WHERE primary_genre ILIKE '%Documentar%';

UPDATE netflix_working SET primary_genre = 'Stand-Up Comedy'
WHERE primary_genre ILIKE '%Stand-Up%' OR primary_genre ILIKE '%Stand Up%';

UPDATE netflix_working SET primary_genre = 'Children & Family'
WHERE primary_genre ILIKE '%Children%'
   OR primary_genre ILIKE '%Kids%'
   OR primary_genre ILIKE '%Family%';

UPDATE netflix_working SET primary_genre = 'Anime'
WHERE primary_genre ILIKE '%Anime%';

UPDATE netflix_working SET primary_genre = 'Reality TV'
WHERE primary_genre ILIKE '%Reality%';

UPDATE netflix_working SET primary_genre = 'Crime'
WHERE primary_genre ILIKE '%Crime%' OR primary_genre ILIKE '%Thrillers%';

UPDATE netflix_working SET primary_genre = 'Dramas'
WHERE primary_genre = 'TV Dramas';

UPDATE netflix_working SET primary_genre = 'Comedies'
WHERE primary_genre = 'TV Comedies';

UPDATE netflix_working SET primary_genre = 'Documentaries'
WHERE primary_genre = 'Docuseries';

UPDATE netflix_working SET primary_genre = 'Kids'
WHERE primary_genre ILIKE '%kids%'
   OR primary_genre ILIKE '%children%';

UPDATE netflix_working
SET primary_genre = 'Unknown'
WHERE primary_genre IS NULL OR TRIM(primary_genre) = '';


-- ============================================================
-- SECTION 8: PRIMARY COUNTRY
-- Standardizes country values for analysis
-- ============================================================

ALTER TABLE netflix_working ADD COLUMN primary_country VARCHAR(100);

UPDATE netflix_working
SET primary_country = TRIM(SPLIT_PART(country, ',', 1));

UPDATE netflix_working SET primary_country = 'United States'
WHERE primary_country ILIKE '%united states%' OR primary_country ILIKE '%usa%';

UPDATE netflix_working SET primary_country = 'United Kingdom'
WHERE primary_country ILIKE '%united kingdom%' OR primary_country ILIKE '%uk%';

UPDATE netflix_working SET primary_country = 'South Korea'
WHERE primary_country ILIKE '%south korea%' OR primary_country ILIKE '%korea%';

UPDATE netflix_working
SET primary_country = 'Unknown'
WHERE primary_country IS NULL OR TRIM(primary_country) = '';


-- ============================================================
-- SECTION 9: DURATION PROCESSING
-- Splits duration into numeric and unit components
-- ============================================================

ALTER TABLE netflix_working ADD COLUMN duration_value INTEGER;
ALTER TABLE netflix_working ADD COLUMN duration_unit  VARCHAR(20);

UPDATE netflix_working
SET duration_value = CAST(SPLIT_PART(duration, ' ', 1) AS INTEGER),
    duration_unit  = TRIM(SPLIT_PART(duration, ' ', 2))
WHERE duration IS NOT NULL AND duration ~ '^\d+';

UPDATE netflix_working SET duration_unit = 'min'
WHERE duration_unit ILIKE '%min%';

UPDATE netflix_working SET duration_unit = 'Seasons'
WHERE duration_unit ILIKE '%season%';


-- ============================================================
-- SECTION 10: RATING GROUPING
-- Simplifies rating categories for visualization
-- ============================================================

ALTER TABLE netflix_working ADD COLUMN rating_category VARCHAR(30);

UPDATE netflix_working
SET rating_category =
    CASE
        WHEN rating IN ('G', 'TV-G', 'TV-Y', 'TV-Y7', 'TV-Y7-FV') THEN 'Kids'
        WHEN rating IN ('PG', 'TV-PG') THEN 'Family'
        WHEN rating IN ('PG-13', 'TV-14') THEN 'Teen'
        WHEN rating IN ('R', 'TV-MA', 'NC-17') THEN 'Adult'
        WHEN rating IN ('NR', 'UR') THEN 'Unrated'
        ELSE 'Other'
    END;


-- ============================================================
-- SECTION 11: DATA CLEANUP
-- Removes incomplete or invalid records
-- ============================================================

DELETE FROM netflix_working
WHERE title IS NULL
  AND type IS NULL
  AND release_year IS NULL;

SELECT COUNT(*) AS final_rows FROM netflix_working;


-- ============================================================
-- SECTION 12: ANALYTICS TABLE
-- Final dataset for Tableau dashboards
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
-- SECTION 13: ANALYTICS QUERIES
-- Used to power Tableau dashboard visuals
-- ============================================================

-- KPI SUMMARY
SELECT
    COUNT(*) AS total_titles,
    SUM(CASE WHEN type = 'Movie' THEN 1 ELSE 0 END) AS movies,
    SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END) AS tv_shows,
    COUNT(DISTINCT primary_country) AS countries
FROM netflix_catalog
WHERE primary_country != 'Unknown';


-- CONTENT GROWTH OVER TIME
SELECT
    year_added,
    type,
    COUNT(*) AS titles_added
FROM netflix_catalog
GROUP BY year_added, type
ORDER BY year_added;


-- TOP GENRES
SELECT
    primary_genre,
    COUNT(*) AS title_count
FROM netflix_catalog
WHERE primary_genre != 'Unknown'
GROUP BY primary_genre
ORDER BY title_count DESC
LIMIT 15;


-- GLOBAL DISTRIBUTION
SELECT
    primary_country,
    COUNT(*) AS total_titles
FROM netflix_catalog
WHERE primary_country != 'Unknown'
GROUP BY primary_country
ORDER BY total_titles DESC;


-- CONTENT TYPE SHARE
SELECT
    type,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM netflix_catalog
GROUP BY type;


-- RATING DISTRIBUTION
SELECT
    rating_category,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM netflix_catalog
GROUP BY rating_category
ORDER BY count DESC;


-- TOP DIRECTORS
SELECT
    director,
    COUNT(*) AS title_count
FROM netflix_catalog
WHERE director IS NOT NULL AND director != ''
GROUP BY director
ORDER BY title_count DESC
LIMIT 15;


-- GENRE OVER TIME
SELECT
    year_added,
    primary_genre,
    COUNT(*) AS titles
FROM netflix_catalog
WHERE primary_genre != 'Unknown'
GROUP BY year_added, primary_genre
ORDER BY year_added;


-- ============================================================
-- SECTION 14: EXPORT
-- Export netflix_catalog for Tableau visualization
-- ============================================================
