-- Setup for the Cortex Agents + Ruby on Rails recipe.
-- Run this as ACCOUNTADMIN (or a role with sufficient privileges).

-- ---------------------------------------------------------------------------
-- 1. Warehouse, database, and schema
-- ---------------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS ANALYST_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

CREATE DATABASE IF NOT EXISTS CORTEX_COOKBOOK;
CREATE SCHEMA IF NOT EXISTS CORTEX_COOKBOOK.AI;

USE WAREHOUSE ANALYST_WH;
USE SCHEMA CORTEX_COOKBOOK.AI;

-- ---------------------------------------------------------------------------
-- 2. Revenue table (12 months x 4 regions x 3 products = 144 rows)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE REVENUE (
    MONTH       DATE,
    REGION      VARCHAR,
    PRODUCT     VARCHAR,
    UNITS_SOLD  INT,
    REVENUE     FLOAT,
    COST        FLOAT
);

INSERT INTO REVENUE VALUES
    ('2024-01-01', 'North', 'Standard', 120, 60000, 36000),
    ('2024-02-01', 'North', 'Standard', 115, 57500, 34500),
    ('2024-03-01', 'North', 'Standard', 130, 65000, 39000),
    ('2024-04-01', 'North', 'Standard', 125, 62500, 37500),
    ('2024-05-01', 'North', 'Standard', 140, 70000, 42000),
    ('2024-06-01', 'North', 'Standard', 150, 75000, 45000),
    ('2024-07-01', 'North', 'Standard', 145, 72500, 43500),
    ('2024-08-01', 'North', 'Standard', 135, 67500, 40500),
    ('2024-09-01', 'North', 'Standard', 155, 77500, 46500),
    ('2024-10-01', 'North', 'Standard', 160, 80000, 48000),
    ('2024-11-01', 'North', 'Standard', 175, 87500, 52500),
    ('2024-12-01', 'North', 'Standard', 190, 95000, 57000),

    ('2024-01-01', 'North', 'Premium', 45, 45000, 22500),
    ('2024-02-01', 'North', 'Premium', 42, 42000, 21000),
    ('2024-03-01', 'North', 'Premium', 50, 50000, 25000),
    ('2024-04-01', 'North', 'Premium', 48, 48000, 24000),
    ('2024-05-01', 'North', 'Premium', 55, 55000, 27500),
    ('2024-06-01', 'North', 'Premium', 60, 60000, 30000),
    ('2024-07-01', 'North', 'Premium', 58, 58000, 29000),
    ('2024-08-01', 'North', 'Premium', 52, 52000, 26000),
    ('2024-09-01', 'North', 'Premium', 62, 62000, 31000),
    ('2024-10-01', 'North', 'Premium', 65, 65000, 32500),
    ('2024-11-01', 'North', 'Premium', 70, 70000, 35000),
    ('2024-12-01', 'North', 'Premium', 75, 75000, 37500),

    ('2024-01-01', 'North', 'Enterprise', 10, 50000, 20000),
    ('2024-02-01', 'North', 'Enterprise', 9, 45000, 18000),
    ('2024-03-01', 'North', 'Enterprise', 12, 60000, 24000),
    ('2024-04-01', 'North', 'Enterprise', 11, 55000, 22000),
    ('2024-05-01', 'North', 'Enterprise', 13, 65000, 26000),
    ('2024-06-01', 'North', 'Enterprise', 15, 75000, 30000),
    ('2024-07-01', 'North', 'Enterprise', 14, 70000, 28000),
    ('2024-08-01', 'North', 'Enterprise', 12, 60000, 24000),
    ('2024-09-01', 'North', 'Enterprise', 16, 80000, 32000),
    ('2024-10-01', 'North', 'Enterprise', 17, 85000, 34000),
    ('2024-11-01', 'North', 'Enterprise', 18, 90000, 36000),
    ('2024-12-01', 'North', 'Enterprise', 20, 100000, 40000),

    ('2024-01-01', 'South', 'Standard', 100, 50000, 30000),
    ('2024-02-01', 'South', 'Standard', 95, 47500, 28500),
    ('2024-03-01', 'South', 'Standard', 110, 55000, 33000),
    ('2024-04-01', 'South', 'Standard', 105, 52500, 31500),
    ('2024-05-01', 'South', 'Standard', 115, 57500, 34500),
    ('2024-06-01', 'South', 'Standard', 120, 60000, 36000),
    ('2024-07-01', 'South', 'Standard', 118, 59000, 35400),
    ('2024-08-01', 'South', 'Standard', 112, 56000, 33600),
    ('2024-09-01', 'South', 'Standard', 125, 62500, 37500),
    ('2024-10-01', 'South', 'Standard', 130, 65000, 39000),
    ('2024-11-01', 'South', 'Standard', 140, 70000, 42000),
    ('2024-12-01', 'South', 'Standard', 150, 75000, 45000),

    ('2024-01-01', 'South', 'Premium', 35, 35000, 17500),
    ('2024-02-01', 'South', 'Premium', 32, 32000, 16000),
    ('2024-03-01', 'South', 'Premium', 38, 38000, 19000),
    ('2024-04-01', 'South', 'Premium', 36, 36000, 18000),
    ('2024-05-01', 'South', 'Premium', 40, 40000, 20000),
    ('2024-06-01', 'South', 'Premium', 45, 45000, 22500),
    ('2024-07-01', 'South', 'Premium', 43, 43000, 21500),
    ('2024-08-01', 'South', 'Premium', 40, 40000, 20000),
    ('2024-09-01', 'South', 'Premium', 48, 48000, 24000),
    ('2024-10-01', 'South', 'Premium', 50, 50000, 25000),
    ('2024-11-01', 'South', 'Premium', 55, 55000, 27500),
    ('2024-12-01', 'South', 'Premium', 58, 58000, 29000),

    ('2024-01-01', 'South', 'Enterprise', 8, 40000, 16000),
    ('2024-02-01', 'South', 'Enterprise', 7, 35000, 14000),
    ('2024-03-01', 'South', 'Enterprise', 9, 45000, 18000),
    ('2024-04-01', 'South', 'Enterprise', 8, 40000, 16000),
    ('2024-05-01', 'South', 'Enterprise', 10, 50000, 20000),
    ('2024-06-01', 'South', 'Enterprise', 12, 60000, 24000),
    ('2024-07-01', 'South', 'Enterprise', 11, 55000, 22000),
    ('2024-08-01', 'South', 'Enterprise', 10, 50000, 20000),
    ('2024-09-01', 'South', 'Enterprise', 13, 65000, 26000),
    ('2024-10-01', 'South', 'Enterprise', 14, 70000, 28000),
    ('2024-11-01', 'South', 'Enterprise', 15, 75000, 30000),
    ('2024-12-01', 'South', 'Enterprise', 16, 80000, 32000),

    ('2024-01-01', 'East', 'Standard', 90, 45000, 27000),
    ('2024-02-01', 'East', 'Standard', 85, 42500, 25500),
    ('2024-03-01', 'East', 'Standard', 95, 47500, 28500),
    ('2024-04-01', 'East', 'Standard', 92, 46000, 27600),
    ('2024-05-01', 'East', 'Standard', 100, 50000, 30000),
    ('2024-06-01', 'East', 'Standard', 108, 54000, 32400),
    ('2024-07-01', 'East', 'Standard', 105, 52500, 31500),
    ('2024-08-01', 'East', 'Standard', 98, 49000, 29400),
    ('2024-09-01', 'East', 'Standard', 112, 56000, 33600),
    ('2024-10-01', 'East', 'Standard', 118, 59000, 35400),
    ('2024-11-01', 'East', 'Standard', 125, 62500, 37500),
    ('2024-12-01', 'East', 'Standard', 135, 67500, 40500),

    ('2024-01-01', 'East', 'Premium', 30, 30000, 15000),
    ('2024-02-01', 'East', 'Premium', 28, 28000, 14000),
    ('2024-03-01', 'East', 'Premium', 33, 33000, 16500),
    ('2024-04-01', 'East', 'Premium', 31, 31000, 15500),
    ('2024-05-01', 'East', 'Premium', 35, 35000, 17500),
    ('2024-06-01', 'East', 'Premium', 38, 38000, 19000),
    ('2024-07-01', 'East', 'Premium', 37, 37000, 18500),
    ('2024-08-01', 'East', 'Premium', 34, 34000, 17000),
    ('2024-09-01', 'East', 'Premium', 40, 40000, 20000),
    ('2024-10-01', 'East', 'Premium', 42, 42000, 21000),
    ('2024-11-01', 'East', 'Premium', 45, 45000, 22500),
    ('2024-12-01', 'East', 'Premium', 48, 48000, 24000),

    ('2024-01-01', 'East', 'Enterprise', 6, 30000, 12000),
    ('2024-02-01', 'East', 'Enterprise', 5, 25000, 10000),
    ('2024-03-01', 'East', 'Enterprise', 7, 35000, 14000),
    ('2024-04-01', 'East', 'Enterprise', 6, 30000, 12000),
    ('2024-05-01', 'East', 'Enterprise', 8, 40000, 16000),
    ('2024-06-01', 'East', 'Enterprise', 9, 45000, 18000),
    ('2024-07-01', 'East', 'Enterprise', 8, 40000, 16000),
    ('2024-08-01', 'East', 'Enterprise', 7, 35000, 14000),
    ('2024-09-01', 'East', 'Enterprise', 10, 50000, 20000),
    ('2024-10-01', 'East', 'Enterprise', 11, 55000, 22000),
    ('2024-11-01', 'East', 'Enterprise', 12, 60000, 24000),
    ('2024-12-01', 'East', 'Enterprise', 13, 65000, 26000),

    ('2024-01-01', 'West', 'Standard', 110, 55000, 33000),
    ('2024-02-01', 'West', 'Standard', 105, 52500, 31500),
    ('2024-03-01', 'West', 'Standard', 120, 60000, 36000),
    ('2024-04-01', 'West', 'Standard', 115, 57500, 34500),
    ('2024-05-01', 'West', 'Standard', 128, 64000, 38400),
    ('2024-06-01', 'West', 'Standard', 135, 67500, 40500),
    ('2024-07-01', 'West', 'Standard', 132, 66000, 39600),
    ('2024-08-01', 'West', 'Standard', 125, 62500, 37500),
    ('2024-09-01', 'West', 'Standard', 140, 70000, 42000),
    ('2024-10-01', 'West', 'Standard', 148, 74000, 44400),
    ('2024-11-01', 'West', 'Standard', 158, 79000, 47400),
    ('2024-12-01', 'West', 'Standard', 170, 85000, 51000),

    ('2024-01-01', 'West', 'Premium', 40, 40000, 20000),
    ('2024-02-01', 'West', 'Premium', 38, 38000, 19000),
    ('2024-03-01', 'West', 'Premium', 45, 45000, 22500),
    ('2024-04-01', 'West', 'Premium', 42, 42000, 21000),
    ('2024-05-01', 'West', 'Premium', 48, 48000, 24000),
    ('2024-06-01', 'West', 'Premium', 52, 52000, 26000),
    ('2024-07-01', 'West', 'Premium', 50, 50000, 25000),
    ('2024-08-01', 'West', 'Premium', 46, 46000, 23000),
    ('2024-09-01', 'West', 'Premium', 55, 55000, 27500),
    ('2024-10-01', 'West', 'Premium', 58, 58000, 29000),
    ('2024-11-01', 'West', 'Premium', 62, 62000, 31000),
    ('2024-12-01', 'West', 'Premium', 68, 68000, 34000),

    ('2024-01-01', 'West', 'Enterprise', 9, 45000, 18000),
    ('2024-02-01', 'West', 'Enterprise', 8, 40000, 16000),
    ('2024-03-01', 'West', 'Enterprise', 10, 50000, 20000),
    ('2024-04-01', 'West', 'Enterprise', 9, 45000, 18000),
    ('2024-05-01', 'West', 'Enterprise', 11, 55000, 22000),
    ('2024-06-01', 'West', 'Enterprise', 13, 65000, 26000),
    ('2024-07-01', 'West', 'Enterprise', 12, 60000, 24000),
    ('2024-08-01', 'West', 'Enterprise', 11, 55000, 22000),
    ('2024-09-01', 'West', 'Enterprise', 14, 70000, 28000),
    ('2024-10-01', 'West', 'Enterprise', 15, 75000, 30000),
    ('2024-11-01', 'West', 'Enterprise', 16, 80000, 32000),
    ('2024-12-01', 'West', 'Enterprise', 18, 90000, 36000);

-- ---------------------------------------------------------------------------
-- 3. Semantic view over the revenue table
-- ---------------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW CORTEX_COOKBOOK.AI.REVENUE_SV
  TABLES (
    revenue AS CORTEX_COOKBOOK.AI.REVENUE
      COMMENT = 'Monthly revenue by region and product tier for 2024'
  )
  FACTS (
    revenue.units_sold_fact AS UNITS_SOLD,
    revenue.revenue_fact    AS REVENUE,
    revenue.cost_fact       AS COST
  )
  DIMENSIONS (
    revenue.month   AS MONTH   COMMENT = 'First day of the month',
    revenue.region  AS REGION  COMMENT = 'Sales region: North, South, East, West',
    revenue.product AS PRODUCT COMMENT = 'Product tier: Standard, Premium, Enterprise'
  )
  METRICS (
    revenue.total_units   AS SUM(revenue.units_sold_fact),
    revenue.total_revenue AS SUM(revenue.revenue_fact),
    revenue.total_cost    AS SUM(revenue.cost_fact),
    revenue.total_profit  AS SUM(revenue.revenue_fact) - SUM(revenue.cost_fact)
  )
  COMMENT = 'Revenue semantic view for the Cortex Agents + Rails recipe';

-- ---------------------------------------------------------------------------
-- 4. Cortex Agent object (models, instructions, and budget live here,
--    so the Rails app can't override them at run time)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE AGENT CORTEX_COOKBOOK.AI.REVENUE_AGENT
  COMMENT = 'Answers revenue questions for the Rails recipe'
  FROM SPECIFICATION $$
models:
  orchestration: auto
orchestration:
  budget:
    seconds: 60
    tokens: 16000
instructions:
  response: "Be concise. Lead with the number, then one sentence of context."
  orchestration: "Use the revenue tool for any question about revenue, cost, profit, units, regions, or products. When the user asks for a chart, or a trend over months, use data_to_chart after the revenue tool."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: revenue
      description: "Monthly 2024 revenue, cost, and units by region and product tier."
  - tool_spec:
      type: data_to_chart
      name: data_to_chart
      description: "Generates a Vega-Lite chart from the revenue tool's results."
tool_resources:
  revenue:
    semantic_view: CORTEX_COOKBOOK.AI.REVENUE_SV
    execution_environment:
      type: warehouse
      warehouse: ANALYST_WH
$$;

-- ---------------------------------------------------------------------------
-- 5. Least-privilege role + key-pair service user for the Rails app
-- ---------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS RAILS_AGENT_ROLE;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE RAILS_AGENT_ROLE;
GRANT USAGE ON WAREHOUSE ANALYST_WH TO ROLE RAILS_AGENT_ROLE;
GRANT USAGE ON DATABASE CORTEX_COOKBOOK TO ROLE RAILS_AGENT_ROLE;
GRANT USAGE ON SCHEMA CORTEX_COOKBOOK.AI TO ROLE RAILS_AGENT_ROLE;
GRANT SELECT ON TABLE CORTEX_COOKBOOK.AI.REVENUE TO ROLE RAILS_AGENT_ROLE;
GRANT SELECT ON SEMANTIC VIEW CORTEX_COOKBOOK.AI.REVENUE_SV TO ROLE RAILS_AGENT_ROLE;
GRANT USAGE ON AGENT CORTEX_COOKBOOK.AI.REVENUE_AGENT TO ROLE RAILS_AGENT_ROLE;

-- Generate the key pair locally first (see README), then paste the public key:
CREATE USER IF NOT EXISTS RAILS_AGENT_SVC
  TYPE = SERVICE
  DEFAULT_ROLE = RAILS_AGENT_ROLE
  DEFAULT_WAREHOUSE = ANALYST_WH
  COMMENT = 'Service user for the Cortex Agents + Rails recipe';
GRANT ROLE RAILS_AGENT_ROLE TO USER RAILS_AGENT_SVC;
-- ALTER USER RAILS_AGENT_SVC SET RSA_PUBLIC_KEY = '<contents of rsa_key.pub, no header/footer>';
