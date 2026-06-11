# Netflix Content Strategy Analysis (2016–2021)

## Project Overview

An end-to-end data analytics project analyzing Netflix's global content catalog using PostgreSQL and Tableau. The project explores content growth trends, genre strategy, global production patterns, director influence, and rating distribution across Netflix's movie and TV show library from 2016–2021.

This project demonstrates data cleaning, SQL analysis, KPI development, and dashboard design through a Netflix-themed business intelligence solution focused on content strategy and catalog growth.

---

# Objectives

* Analyze how Netflix's content catalog grew from 2016–2021
* Identify which genres dominate the platform and how they changed over time
* Explore which countries produce the most Netflix content
* Compare movies and TV shows across content, ratings, and production trends
* Identify the most prolific directors on the platform
* Build an interactive Tableau dashboard inspired by the Netflix user interface

---

# Tools & Technologies

* PostgreSQL
* SQL
* Tableau Public
* Kaggle (CSV)

---

# Data Pipeline & Dataset Information

This project follows a structured data pipeline from source data to a final analysis-ready dataset used in Tableau.

## Data Pipeline

Source Data → Cleaning & Transformation → Data Enrichment → Final Dataset → Tableau Visualization

---

## Source Data

Located in `data/source_data/`:

- Download the Netflix Movies and TV Shows dataset from Kaggle
- Save the file as `netflix_titles.csv`
- Source CSV files are excluded from the repository via `.gitignore`

---

## Final Dataset (Used in Tableau)

Located in `data/final/`:

- Export the cleaned dataset as `netflix_clean.csv`
- Final CSV files are excluded from the repository via `.gitignore`

The final dataset was created by cleaning, standardizing, and enriching the raw Netflix catalog data into a single analysis-ready table for SQL analysis and Tableau visualization.

Data preparation included:

* Removing duplicate records
* Converting text-based dates to DATE format
* Extracting primary genres
* Extracting primary production countries
* Splitting duration into value and unit fields
* Creating rating categories
* Creating year and month fields for trend analysis

---

# SQL Workflow

The SQL workflow includes:

* Table creation and schema validation
* Data import verification
* Duplicate detection and removal
* Date conversion and validation
* Genre standardization
* Country extraction and standardization
* Duration parsing and cleanup
* Rating categorization
* Derived column creation:

  * Year Added
  * Month Added
  * Primary Genre
  * Primary Country
  * Rating Group
* Exploratory data analysis
* KPI generation
* Tableau-ready query preparation

---

# Business Questions

* How has Netflix's content catalog grown over time?
* Which genres make up the largest share of the catalog?
* Which countries contribute the most content?
* Has Netflix shifted toward movies or TV shows?
* Who are the most prolific directors on the platform?
* How is content distributed across rating categories?

---

# Key Insights

* Netflix's catalog experienced rapid growth between 2016 and 2019 before slowing in the early 2020s.
* Drama and International Movies account for a significant share of total content, reflecting Netflix's investment in global programming.
* The United States produces the most content, while India, the United Kingdom, and South Korea are among the largest international contributors.
* Movies outnumber TV shows across the catalog, though both content types experienced substantial growth during the analysis period.
* TV-MA is the most common content rating, indicating a strong focus on adult audiences.
* A relatively small group of directors contributes a disproportionately large number of titles to the platform.

---

# Live Dashboard

[View Interactive Tableau Dashboard](https://public.tableau.com/views/netflix_catalog/Dashboard1?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)

---

# Dashboard Preview

## Netflix Content Strategy Dashboard

<img width="1199" height="999" alt="Dashboard 1" src="https://github.com/user-attachments/assets/6d2a2240-41d8-4889-9455-c168a4822d4a" />



---

# Dashboard Features

The Tableau solution uses a single-page dashboard inspired by Netflix's user interface. The design incorporates a dark theme, Netflix red accents, and content organized into sections similar to Netflix content shelves.

Dashboard features include:

* KPI cards
* Content growth trend analysis
* Genre performance analysis
* Country-level production analysis
* Movies vs TV Shows comparison
* Rating distribution analysis
* Top directors analysis
* Interactive filters
* Netflix-inspired visual design

---

# Repository Structure

```text
netflix-content-strategy/
│
├── data/                             # (Large data files excluded via .gitignore)
│   ├── source_data/                  # Place downloaded source CSV dataset here (.gitkeep)
│   └── final/                        # Output directory for clean transformed data (.gitkeep)
│
├── sql/
│   └── netflix_cleaning.sql          # SQL processing and analysis scripts
│
│── .gitignore                        # Configuration to exclude heavy data tracking
│
└── README.md                         # Project documentation and portfolio overview
```

---

# Technical Skills Demonstrated

* SQL data cleaning and transformation
* PostgreSQL database management
* Text parsing using SPLIT_PART and TRIM
* Pattern-based standardization using ILIKE
* Window functions for deduplication
* Date conversion and time-series analysis
* Aggregations and joins
* KPI development and reporting
* Interactive Tableau dashboard design
* Custom dashboard theming
* Data visualization
* Data storytelling

```
```
