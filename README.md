# Funnel Analysis and Customer Segmentation

## Introduction

> Ever wondered why companies lose customers due to poor website design, clunky interfaces, browser compatibility issues, or even small bugs that push users away—sometimes for good?
> 

This project explores how users move through a product funnel, where they drop off, and how customer segmentation helps identify patterns behind these behaviors. 

From a business perspective, this analysis helps to:

- **Identify** critical drop-off points in the user journey
- **Compare** performance across traffic sources and user segments
- **Enable** data-driven decisions through key metrics to improve conversion rates.

---

## Objective

To analyze user behavior across a product funnel and identify actionable insights to improve overall conversion rate and identify the drop-offs. Ultimately, this project aims to create a visually stunning dashboard in order to account for the current situation of the dataset and focus on answering several key stakeholder questions to improve business insights.

---

## Architecture Pipeline

Instead of relying on static CSV files, this project implements a robust ELT (Extract, Load and Transform) pipeline:

<img width="670" height="739" alt="image" src="https://github.com/user-attachments/assets/909275df-193d-418b-9e36-48fa7919c9cd" />


---

## **Phase I: Exploratory Data Analysis (EDA)**

EDA is carried out using the three step process of ETL, i.e. Extract, Load and Transform using Pandas, a python library used to convert csv files into useful Data frames for pre-data analysis process. The attached file contains all the steps involved in transforming the data.

[Funnel_EDA.ipynb](notebooks/Funnel_EDA.ipynb)

---

## Phase II: Database & Schema Design

To adhere to data engineering best practices, the raw data is normalized into a relational database structure (MySQL). Instead of a single massive flat file, the data is split into two distinct tables utilizing Primary and Foreign Keys:

- `users` **table : `session_id` (Primary Key), `traffic_source`, `browser`.
- **`events` table:** `event_id` (Primary Key), `session_id` (Foreign Key), `event_type`, `created_at`.

---

## **Phase III: The Python-to-MySQL Bridge**

Using the `SQLAlchemy` library, the cleaned dataframes are pushed directly into the MySQL database, acting as the loading phase of the pipeline.

```python
import pandas as pd
from sqlalchemy import create_engine

# 1. Handling datetimes
df['created_at'] = pd.to_datetime(df['created_at'])

# 2. Split data to normalize the schema
users_df = df[['session_id', 'traffic_source', 'browser']].drop_duplicates()
events_df = df[['session_id', 'event_type', 'created_at']]

# 3. Create MySQL Engine
engine = create_engine('mysql+pymysql://username:password@localhost/funnel_db')

# 4. Push to MySQL
users_df.to_sql('users', con=engine, if_exists='replace', index=False)
events_df.to_sql('events', con=engine, if_exists='replace', index=False)
```

---

## **Phase IV: Advanced SQL Transformations (Business Logic)**

Core business logic and transformations are executed directly within the database using SQL Views. This allows the BI tool to query live, transformed data rather than static exports.

1. Calculating Time-to-Cart using Window Functions/Aggregations:

```sql
CREATE VIEW session_metrics AS
WITH session_times AS (
    SELECT
        session_id,
        MIN(created_at) AS start_time,
        MAX(CASE WHEN event_type = 'cart' THEN created_at END) AS cart_time,
        MAX(CASE WHEN event_type = 'purchase' THEN created_at END) AS purchase_time
    FROM events
    GROUP BY session_id
)
SELECT
    session_id,
    TIMESTAMPDIFF(SECOND, start_time, cart_time) AS time_to_cart_sec,
    TIMESTAMPDIFF(SECOND, start_time, purchase_time) AS time_to_purchase_sec
FROM session_times;
```

1. Building Funnel Flags using Pivot:

```sql
CREATE VIEW funnel_master_data AS
SELECT
    u.session_id,
    u.traffic_source,
    u.browser,
    MAX(CASE WHEN e.event_type = 'home' THEN 1 ELSE 0 END) AS hit_home,
    MAX(CASE WHEN e.event_type = 'department' THEN 1 ELSE 0 END) AS hit_department,
    MAX(CASE WHEN e.event_type = 'product' THEN 1 ELSE 0 END) AS hit_product,
    MAX(CASE WHEN e.event_type = 'cart' THEN 1 ELSE 0 END) AS hit_cart,
    MAX(CASE WHEN e.event_type = 'purchase' THEN 1 ELSE 0 END) AS hit_purchase
FROM users u
LEFT JOIN events e ON u.session_id = e.session_id
GROUP BY u.session_id, u.traffic_source, u.browser;
```

---

## **Phase V: Stakeholder Reporting & Business Insights**

Transitioning from data engineering to business intelligence, this phase focuses on answering key operational questions from the VP of E-Commerce. The goal is to drive actionable strategies for valuable insights using the connected Power BI dashboard.

### The Business Problem

The project was designed to address five specific operational pain points:

1. **The Pipeline Bleed:**
   Where is the company losing money due to potential technical bugs?
2. **The Golden Channel:**
   Which traffic source brings in the highest realized revenue?
3. **The Retargeting Hit-List:**
   Where do 'Cart Abandoners' primarily originate from?
4. **The Engagement Threshold:**
   Is there a correlation between session duration, event volume, and conversion?
5. **The Ultimate Bottleneck:**
   What is the sharpest drop-off point in the funnel?

### Data-Driven Answers & Recommendations

Based on the Power BI dashboards, here are the immediate insights:

- **The Pipeline Bleed (Browser Optimization):** With **$198.36K in Lost Revenue**, the vast majority of our potential revenue is bleeding out through **Chrome** (accounting for nearly $100K in lost revenue), followed by Firefox and Safari.
    - *Action:* Engineering should immediately prioritize QA testing and bug-fixing on the Chrome browser experience, as minor friction here causes the largest absolute financial loss.
- **The Golden Channel (Marketing Spend):** **Email** is our undisputed Golden Channel, driving **46.42% ($62.4K)** of our total Realized Revenue. AdWords follows in second place (30.19%).
    - *Action:* Reallocate marketing spend away from underperforming channels like Organic and Facebook, and double down on Email marketing and targeted AdWords.
- **The Retargeting Hit-List:** Looking at our Cart Abandoners, the primary traffic source is, interestingly, also **Email**, heavily followed by **AdWords**.
    - *Action:* Since these users are already in our email ecosystem, we need to implement automated "abandoned cart" drip campaigns offering time-sensitive discounts to recapture this specific segment.
- **The Engagement Threshold:** The scatter plot reveals a clear clustering. **Buyers** (light blue) consistently show higher engagement, typically hitting 5 to 13 events per session and spending between 500–1500 seconds on the site. In contrast, **Bouncers/Low Intent** users and **Cart Abandoners** cluster heavily at the bottom with 3 or fewer events.
    - *Action:* Content drives sales. We need to encourage exploration (e.g., "Related Products" widgets, customer reviews) to push users past the 5-event threshold.
- **The Ultimate Bottleneck:** The overall conversion rate sits at 25.33%, but the sharpest drop-off is the **Cart-to-Purchase** stage. While 63.07% of users successfully add an item to their cart, more than half of them abandon it, resulting in a staggering **59.83% Cart Abandonment Rate**.
    - *Action:* The checkout process needs immediate auditing. We should test guest checkout options, reduce form fields, and highlight secure payment badges to reduce friction.

![Revenue Analysis - Page 1.png](powerbi/Revenue_Analysis.png)

![Behavioral Analysis - Page 2.png](powerbi/Behavioral_Analysis.png)

---

## Technical Skills Demonstrated

- **Python:** ELT scripting using `pandas` and `sqlalchemy`.
- **Data Engineering:** Relational database normalization (Primary/Foreign Keys) and schema design.
- **Advanced SQL:** CTEs, conditional aggregations, datetime manipulation, and View creation.
- **Business Intelligence:** Live database connections, dimensional modeling, and DAX in Power BI.
