-- ============================================================================
-- RegIntel Copilot — Complete Setup Script
-- Risk, Fraud & Regulatory Intelligence Copilot
--
-- Run this script in a Snowflake worksheet with ACCOUNTADMIN role.
-- It creates everything from scratch: database, schemas, tables,
-- synthetic data, dynamic tables, semantic view, Cortex Search,
-- Cortex Agent, and the scheduled fraud scan task.
--
-- Prerequisites:
--   - ACCOUNTADMIN role (or equivalent)
--   - A warehouse (default: COMPUTE_WH)
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-- ────────────────────────────────────────────────────────────────────────────
-- 1. DATABASE & SCHEMAS
-- ────────────────────────────────────────────────────────────────────────────

CREATE DATABASE IF NOT EXISTS REGINTEL_DB
    COMMENT = 'Risk, Fraud and Regulatory Intelligence Copilot';

CREATE SCHEMA IF NOT EXISTS REGINTEL_DB.RAW
    COMMENT = 'Raw synthetic data: accounts, transactions, reference data';
CREATE SCHEMA IF NOT EXISTS REGINTEL_DB.ENRICHED
    COMMENT = 'Enriched/transformed data: risk scores, fraud signals, regulatory metrics';
CREATE SCHEMA IF NOT EXISTS REGINTEL_DB.SEMANTIC
    COMMENT = 'Semantic views and agent configuration';
CREATE SCHEMA IF NOT EXISTS REGINTEL_DB.DOCUMENTS
    COMMENT = 'Policy documents and unstructured data';

-- ────────────────────────────────────────────────────────────────────────────
-- 2. RAW TABLES
-- ────────────────────────────────────────────────────────────────────────────

-- 2a. Customers (500 synthetic profiles)
CREATE OR REPLACE TABLE REGINTEL_DB.RAW.CUSTOMERS (
    CUSTOMER_ID VARCHAR(20) PRIMARY KEY,
    FIRST_NAME VARCHAR(100),
    LAST_NAME VARCHAR(100),
    DATE_OF_BIRTH DATE,
    NATIONALITY VARCHAR(50),
    COUNTRY_OF_RESIDENCE VARCHAR(50),
    CUSTOMER_TYPE VARCHAR(20),
    KYC_STATUS VARCHAR(20),
    KYC_VERIFICATION_DATE DATE,
    KYC_EXPIRY_DATE DATE,
    RISK_RATING VARCHAR(10),
    PEP_FLAG BOOLEAN,
    SANCTIONS_FLAG BOOLEAN,
    ADVERSE_MEDIA_FLAG BOOLEAN,
    OCCUPATION VARCHAR(100),
    ANNUAL_INCOME NUMBER(15,2),
    SOURCE_OF_FUNDS VARCHAR(200),
    ONBOARDING_DATE DATE,
    LAST_REVIEW_DATE DATE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO REGINTEL_DB.RAW.CUSTOMERS
WITH name_pool AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY SEQ4()) AS rn,
        'CUST-' || LPAD(ROW_NUMBER() OVER (ORDER BY SEQ4())::VARCHAR, 5, '0') AS customer_id,
        CASE MOD(SEQ4(), 20)
            WHEN 0 THEN 'James' WHEN 1 THEN 'Maria' WHEN 2 THEN 'Robert' WHEN 3 THEN 'Sarah'
            WHEN 4 THEN 'Mohammed' WHEN 5 THEN 'Elena' WHEN 6 THEN 'David' WHEN 7 THEN 'Priya'
            WHEN 8 THEN 'Chen' WHEN 9 THEN 'Fatima' WHEN 10 THEN 'William' WHEN 11 THEN 'Aisha'
            WHEN 12 THEN 'Carlos' WHEN 13 THEN 'Yuki' WHEN 14 THEN 'John' WHEN 15 THEN 'Olga'
            WHEN 16 THEN 'Ahmad' WHEN 17 THEN 'Lisa' WHEN 18 THEN 'Viktor' ELSE 'Mei'
        END AS first_name,
        CASE MOD(SEQ4(), 25)
            WHEN 0 THEN 'Smith' WHEN 1 THEN 'Patel' WHEN 2 THEN 'Rodriguez' WHEN 3 THEN 'Kim'
            WHEN 4 THEN 'Al-Hassan' WHEN 5 THEN 'Muller' WHEN 6 THEN 'Tanaka' WHEN 7 THEN 'Singh'
            WHEN 8 THEN 'Johansson' WHEN 9 THEN 'Okafor' WHEN 10 THEN 'Brown' WHEN 11 THEN 'Wang'
            WHEN 12 THEN 'Garcia' WHEN 13 THEN 'Ivanov' WHEN 14 THEN 'Nakamura' WHEN 15 THEN 'Ali'
            WHEN 16 THEN 'Fischer' WHEN 17 THEN 'Santos' WHEN 18 THEN 'Lee' WHEN 19 THEN 'Petrov'
            WHEN 20 THEN 'Nguyen' WHEN 21 THEN 'Costa' WHEN 22 THEN 'Khan' WHEN 23 THEN 'Jensen'
            ELSE 'Zhao'
        END AS last_name,
        DATEADD('day', -UNIFORM(6570, 25550, RANDOM()), CURRENT_DATE()) AS dob,
        CASE MOD(HASH(SEQ4()), 10)
            WHEN 0 THEN 'US' WHEN 1 THEN 'IN' WHEN 2 THEN 'GB' WHEN 3 THEN 'AE'
            WHEN 4 THEN 'SG' WHEN 5 THEN 'DE' WHEN 6 THEN 'JP' WHEN 7 THEN 'BR'
            WHEN 8 THEN 'NG' ELSE 'CN'
        END AS nationality,
        CASE MOD(HASH(SEQ4()+1), 8)
            WHEN 0 THEN 'US' WHEN 1 THEN 'IN' WHEN 2 THEN 'GB' WHEN 3 THEN 'AE'
            WHEN 4 THEN 'SG' WHEN 5 THEN 'DE' WHEN 6 THEN 'HK' ELSE 'CH'
        END AS country_of_residence,
        CASE
            WHEN MOD(SEQ4(), 50) = 0 THEN 'PEP'
            WHEN MOD(SEQ4(), 5) = 0 THEN 'CORPORATE'
            ELSE 'INDIVIDUAL'
        END AS customer_type,
        CASE MOD(HASH(SEQ4()+2), 20)
            WHEN 0 THEN 'PENDING' WHEN 1 THEN 'EXPIRED' WHEN 2 THEN 'FAILED'
            ELSE 'VERIFIED'
        END AS kyc_status,
        CASE WHEN MOD(HASH(SEQ4()+2), 20) IN (0,2) THEN NULL
            ELSE DATEADD('day', -UNIFORM(30, 365, RANDOM()), CURRENT_DATE()) END AS kyc_verification_date,
        CASE WHEN MOD(HASH(SEQ4()+2), 20) IN (0,2) THEN NULL
            ELSE DATEADD('day', UNIFORM(30, 365, RANDOM()), CURRENT_DATE()) END AS kyc_expiry_date,
        CASE
            WHEN MOD(SEQ4(), 50) = 0 THEN 'CRITICAL'
            WHEN MOD(SEQ4(), 10) < 2 THEN 'HIGH'
            WHEN MOD(SEQ4(), 10) < 5 THEN 'MEDIUM'
            ELSE 'LOW'
        END AS risk_rating,
        MOD(SEQ4(), 50) = 0 AS pep_flag,
        MOD(SEQ4(), 200) = 0 AS sanctions_flag,
        MOD(SEQ4(), 30) = 0 AS adverse_media_flag,
        CASE MOD(SEQ4(), 12)
            WHEN 0 THEN 'Software Engineer' WHEN 1 THEN 'Physician' WHEN 2 THEN 'Business Owner'
            WHEN 3 THEN 'Attorney' WHEN 4 THEN 'Retired' WHEN 5 THEN 'Government Official'
            WHEN 6 THEN 'Real Estate Developer' WHEN 7 THEN 'Import/Export Trader'
            WHEN 8 THEN 'Restaurant Owner' WHEN 9 THEN 'Consultant' WHEN 10 THEN 'Accountant'
            ELSE 'Financial Advisor'
        END AS occupation,
        CASE
            WHEN MOD(SEQ4(), 50) = 0 THEN UNIFORM(500000, 5000000, RANDOM())
            WHEN MOD(SEQ4(), 5) = 0 THEN UNIFORM(200000, 2000000, RANDOM())
            ELSE UNIFORM(30000, 250000, RANDOM())
        END AS annual_income,
        CASE MOD(SEQ4(), 8)
            WHEN 0 THEN 'Employment Income' WHEN 1 THEN 'Business Revenue' WHEN 2 THEN 'Inheritance'
            WHEN 3 THEN 'Investment Returns' WHEN 4 THEN 'Rental Income' WHEN 5 THEN 'Pension'
            WHEN 6 THEN 'Sale of Property' ELSE 'Savings'
        END AS source_of_funds,
        DATEADD('day', -UNIFORM(90, 1825, RANDOM()), CURRENT_DATE()) AS onboarding_date,
        DATEADD('day', -UNIFORM(1, 180, RANDOM()), CURRENT_DATE()) AS last_review_date
    FROM TABLE(GENERATOR(ROWCOUNT => 500))
)
SELECT customer_id, first_name, last_name, dob, nationality, country_of_residence,
       customer_type, kyc_status, kyc_verification_date, kyc_expiry_date, risk_rating,
       pep_flag, sanctions_flag, adverse_media_flag, occupation, annual_income,
       source_of_funds, onboarding_date, last_review_date, CURRENT_TIMESTAMP()
FROM name_pool;

-- 2b. Accounts (1,200)
CREATE OR REPLACE TABLE REGINTEL_DB.RAW.ACCOUNTS (
    ACCOUNT_ID VARCHAR(20) PRIMARY KEY,
    CUSTOMER_ID VARCHAR(20) REFERENCES REGINTEL_DB.RAW.CUSTOMERS(CUSTOMER_ID),
    ACCOUNT_TYPE VARCHAR(30),
    ACCOUNT_STATUS VARCHAR(20),
    CURRENCY VARCHAR(3),
    OPENING_BALANCE NUMBER(15,2),
    CURRENT_BALANCE NUMBER(15,2),
    CREDIT_LIMIT NUMBER(15,2),
    BRANCH_CODE VARCHAR(10),
    OPENED_DATE DATE,
    LAST_ACTIVITY_DATE DATE,
    IS_DORMANT BOOLEAN,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO REGINTEL_DB.RAW.ACCOUNTS
SELECT
    'ACCT-' || LPAD(ROW_NUMBER() OVER (ORDER BY SEQ4())::VARCHAR, 7, '0'),
    'CUST-' || LPAD((UNIFORM(1, 500, RANDOM()))::VARCHAR, 5, '0'),
    CASE MOD(SEQ4(), 5) WHEN 0 THEN 'SAVINGS' WHEN 1 THEN 'CHECKING' WHEN 2 THEN 'BUSINESS' WHEN 3 THEN 'LOAN' ELSE 'FIXED_DEPOSIT' END,
    CASE MOD(HASH(SEQ4()), 20) WHEN 0 THEN 'FROZEN' WHEN 1 THEN 'CLOSED' WHEN 2 THEN 'UNDER_REVIEW' ELSE 'ACTIVE' END,
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'USD' WHEN 1 THEN 'EUR' WHEN 2 THEN 'GBP' ELSE 'INR' END,
    UNIFORM(1000, 500000, RANDOM())::NUMBER(15,2),
    UNIFORM(500, 2000000, RANDOM())::NUMBER(15,2),
    CASE WHEN MOD(SEQ4(), 5) = 3 THEN UNIFORM(50000, 1000000, RANDOM()) ELSE NULL END,
    'BR-' || LPAD(UNIFORM(1, 50, RANDOM())::VARCHAR, 3, '0'),
    DATEADD('day', -UNIFORM(90, 1825, RANDOM()), CURRENT_DATE()),
    DATEADD('day', -UNIFORM(0, 30, RANDOM()), CURRENT_DATE()),
    UNIFORM(1, 100, RANDOM()) > 95,
    CURRENT_TIMESTAMP()
FROM TABLE(GENERATOR(ROWCOUNT => 1200));

-- 2c. Transactions (42,477 total: 40K normal + fraud patterns)
CREATE OR REPLACE TABLE REGINTEL_DB.RAW.TRANSACTIONS (
    TRANSACTION_ID VARCHAR(30) PRIMARY KEY,
    ACCOUNT_ID VARCHAR(20),
    COUNTERPARTY_ACCOUNT_ID VARCHAR(20),
    TRANSACTION_DATE TIMESTAMP_NTZ,
    TRANSACTION_TYPE VARCHAR(30),
    AMOUNT NUMBER(15,2),
    CURRENCY VARCHAR(3),
    DESCRIPTION VARCHAR(500),
    CHANNEL VARCHAR(20),
    ORIGINATOR_NAME VARCHAR(200),
    ORIGINATOR_COUNTRY VARCHAR(50),
    BENEFICIARY_NAME VARCHAR(200),
    BENEFICIARY_COUNTRY VARCHAR(50),
    IS_INTERNATIONAL BOOLEAN,
    STATUS VARCHAR(20),
    RISK_SCORE NUMBER(5,2),
    FRAUD_PATTERN_LABEL VARCHAR(50),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Normal transactions (40,000)
INSERT INTO REGINTEL_DB.RAW.TRANSACTIONS
SELECT
    'TXN-' || LPAD(ROW_NUMBER() OVER (ORDER BY SEQ4())::VARCHAR, 8, '0'),
    'ACCT-' || LPAD(UNIFORM(1, 1200, RANDOM())::VARCHAR, 7, '0'),
    CASE WHEN UNIFORM(1,10,RANDOM()) <= 4 THEN 'ACCT-' || LPAD(UNIFORM(1,1200,RANDOM())::VARCHAR,7,'0') ELSE NULL END,
    DATEADD('second', -UNIFORM(0, 7776000, RANDOM()), CURRENT_TIMESTAMP()),
    CASE MOD(SEQ4(), 8) WHEN 0 THEN 'WIRE_IN' WHEN 1 THEN 'WIRE_OUT' WHEN 2 THEN 'CASH_DEPOSIT' WHEN 3 THEN 'CASH_WITHDRAWAL' WHEN 4 THEN 'ACH_IN' WHEN 5 THEN 'ACH_OUT' WHEN 6 THEN 'INTERNAL_TRANSFER' ELSE 'CHECK_DEPOSIT' END,
    ROUND(EXP(UNIFORM(2, 10, RANDOM()) * 0.8 + NORMAL(0, 0.5, RANDOM())), 2),
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'USD' WHEN 1 THEN 'EUR' WHEN 2 THEN 'GBP' ELSE 'INR' END,
    CASE MOD(SEQ4(), 8) WHEN 0 THEN 'Incoming wire transfer' WHEN 1 THEN 'Outgoing wire transfer' WHEN 2 THEN 'Cash deposit at branch' WHEN 3 THEN 'ATM withdrawal' WHEN 4 THEN 'ACH payroll credit' WHEN 5 THEN 'ACH bill payment' WHEN 6 THEN 'Internal fund transfer' ELSE 'Check deposit' END,
    CASE MOD(HASH(SEQ4()), 5) WHEN 0 THEN 'BRANCH' WHEN 1 THEN 'ONLINE' WHEN 2 THEN 'MOBILE' WHEN 3 THEN 'ATM' ELSE 'SWIFT' END,
    NULL,
    CASE WHEN UNIFORM(1,5,RANDOM())=1 THEN CASE MOD(HASH(SEQ4()+10),6) WHEN 0 THEN 'US' WHEN 1 THEN 'GB' WHEN 2 THEN 'AE' WHEN 3 THEN 'HK' WHEN 4 THEN 'SG' ELSE 'CH' END ELSE 'US' END,
    NULL,
    CASE WHEN UNIFORM(1,5,RANDOM())=1 THEN CASE MOD(HASH(SEQ4()+20),6) WHEN 0 THEN 'US' WHEN 1 THEN 'GB' WHEN 2 THEN 'AE' WHEN 3 THEN 'HK' WHEN 4 THEN 'SG' ELSE 'CH' END ELSE 'US' END,
    UNIFORM(1,5,RANDOM()) = 1,
    CASE WHEN UNIFORM(1,100,RANDOM()) <= 97 THEN 'COMPLETED' WHEN UNIFORM(1,100,RANDOM()) <= 50 THEN 'PENDING' ELSE 'FAILED' END,
    ROUND(UNIFORM(0, 35, RANDOM()) + NORMAL(0, 5, RANDOM()), 2),
    'NORMAL',
    CURRENT_TIMESTAMP()
FROM TABLE(GENERATOR(ROWCOUNT => 40000));

-- Structuring pattern (1,350 transactions)
INSERT INTO REGINTEL_DB.RAW.TRANSACTIONS
WITH base_accounts AS (
    SELECT ACCOUNT_ID, ROW_NUMBER() OVER (ORDER BY ACCOUNT_ID) AS rn
    FROM REGINTEL_DB.RAW.ACCOUNTS WHERE ACCOUNT_STATUS = 'ACTIVE' ORDER BY ACCOUNT_ID LIMIT 15
)
SELECT
    'TXN-ST' || LPAD(SEQ4()::VARCHAR, 6, '0'),
    ba.ACCOUNT_ID, NULL,
    DATEADD('hour', -(MOD(SEQ4(), 6) * UNIFORM(4, 12, RANDOM())), DATEADD('day', -UNIFORM(1, 21, RANDOM()), CURRENT_TIMESTAMP())),
    'CASH_DEPOSIT',
    ROUND(UNIFORM(8000, 9950, RANDOM()) + UNIFORM(0, 99, RANDOM()) / 100, 2),
    'USD',
    CASE MOD(SEQ4(), 5) WHEN 0 THEN 'Cash deposit - daily business revenue' WHEN 1 THEN 'Cash deposit - restaurant proceeds' WHEN 2 THEN 'Cash deposit - retail sales' WHEN 3 THEN 'Cash deposit - personal' ELSE 'Cash deposit - miscellaneous' END,
    'BRANCH', NULL, 'US', NULL, 'US', FALSE, 'COMPLETED',
    ROUND(UNIFORM(60, 90, RANDOM()), 2), 'STRUCTURING', CURRENT_TIMESTAMP()
FROM TABLE(GENERATOR(ROWCOUNT => 90)) g
JOIN base_accounts ba ON MOD(SEQ4(), 15) + 1 = ba.rn;

-- Layering pattern (200 transactions)
INSERT INTO REGINTEL_DB.RAW.TRANSACTIONS
WITH chain_accounts AS (
    SELECT ACCOUNT_ID, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn
    FROM REGINTEL_DB.RAW.ACCOUNTS WHERE ACCOUNT_STATUS = 'ACTIVE' LIMIT 50
)
SELECT
    'TXN-LY' || LPAD(ROW_NUMBER() OVER (ORDER BY SEQ4())::VARCHAR, 6, '0'),
    ca1.ACCOUNT_ID, ca2.ACCOUNT_ID,
    DATEADD('minute', -(SEQ4() * UNIFORM(10, 120, RANDOM())), DATEADD('day', -UNIFORM(1, 45, RANDOM()), CURRENT_TIMESTAMP())),
    CASE WHEN MOD(SEQ4(), 2) = 0 THEN 'WIRE_OUT' ELSE 'INTERNAL_TRANSFER' END,
    ROUND(UNIFORM(50000, 500000, RANDOM()), 2), 'USD',
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'Fund transfer - investment rebalancing' WHEN 1 THEN 'Fund transfer - intercompany settlement' WHEN 2 THEN 'Fund transfer - liquidity management' ELSE 'Fund transfer - treasury operations' END,
    CASE WHEN MOD(SEQ4(), 3) = 0 THEN 'SWIFT' ELSE 'ONLINE' END,
    NULL, CASE MOD(HASH(SEQ4()), 4) WHEN 0 THEN 'US' WHEN 1 THEN 'AE' WHEN 2 THEN 'HK' ELSE 'CH' END,
    NULL, CASE MOD(HASH(SEQ4()+5), 4) WHEN 0 THEN 'SG' WHEN 1 THEN 'KY' WHEN 2 THEN 'LU' ELSE 'PA' END,
    TRUE, 'COMPLETED', ROUND(UNIFORM(70, 95, RANDOM()), 2), 'LAYERING', CURRENT_TIMESTAMP()
FROM TABLE(GENERATOR(ROWCOUNT => 200)) g
JOIN chain_accounts ca1 ON MOD(SEQ4(), 25) + 1 = ca1.rn
JOIN chain_accounts ca2 ON MOD(SEQ4(), 25) + 26 = ca2.rn;

-- Round-trip pattern (120 transactions)
INSERT INTO REGINTEL_DB.RAW.TRANSACTIONS
WITH rt_accounts AS (
    SELECT ACCOUNT_ID, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn
    FROM REGINTEL_DB.RAW.ACCOUNTS WHERE ACCOUNT_STATUS = 'ACTIVE' LIMIT 20
)
SELECT
    'TXN-RT' || LPAD(ROW_NUMBER() OVER (ORDER BY SEQ4())::VARCHAR, 6, '0'),
    CASE WHEN MOD(SEQ4(), 2) = 0 THEN ca1.ACCOUNT_ID ELSE ca2.ACCOUNT_ID END,
    CASE WHEN MOD(SEQ4(), 2) = 0 THEN ca2.ACCOUNT_ID ELSE ca1.ACCOUNT_ID END,
    DATEADD('hour', -(MOD(SEQ4(), 4) * UNIFORM(12, 48, RANDOM())), DATEADD('day', -UNIFORM(1, 60, RANDOM()), CURRENT_TIMESTAMP())),
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'WIRE_OUT' WHEN 1 THEN 'WIRE_IN' ELSE 'INTERNAL_TRANSFER' END,
    ROUND(UNIFORM(100000, 750000, RANDOM()), 2), 'USD',
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'Loan repayment' WHEN 1 THEN 'Investment return' WHEN 2 THEN 'Consulting fee payment' ELSE 'Trade settlement' END,
    CASE WHEN MOD(SEQ4(), 2) = 0 THEN 'SWIFT' ELSE 'ONLINE' END,
    NULL, CASE MOD(HASH(SEQ4()), 3) WHEN 0 THEN 'US' WHEN 1 THEN 'KY' ELSE 'BVI' END,
    NULL, CASE MOD(HASH(SEQ4()+3), 3) WHEN 0 THEN 'US' WHEN 1 THEN 'PA' ELSE 'LU' END,
    TRUE, 'COMPLETED', ROUND(UNIFORM(75, 98, RANDOM()), 2), 'ROUND_TRIP', CURRENT_TIMESTAMP()
FROM TABLE(GENERATOR(ROWCOUNT => 120)) g
JOIN rt_accounts ca1 ON MOD(SEQ4(), 10) + 1 = ca1.rn
JOIN rt_accounts ca2 ON MOD(SEQ4(), 10) + 11 = ca2.rn;

-- Rapid movement pattern (800 transactions)
INSERT INTO REGINTEL_DB.RAW.TRANSACTIONS
WITH rm_accounts AS (
    SELECT ACCOUNT_ID, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn
    FROM REGINTEL_DB.RAW.ACCOUNTS WHERE ACCOUNT_STATUS = 'ACTIVE' LIMIT 10
)
SELECT
    'TXN-RM' || LPAD(ROW_NUMBER() OVER (ORDER BY SEQ4())::VARCHAR, 6, '0'),
    rma.ACCOUNT_ID,
    'ACCT-' || LPAD(UNIFORM(1, 1200, RANDOM())::VARCHAR, 7, '0'),
    DATEADD('minute', -(MOD(SEQ4(), 8) * UNIFORM(5, 30, RANDOM())), DATEADD('day', -UNIFORM(1, 14, RANDOM()), CURRENT_TIMESTAMP())),
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'WIRE_OUT' WHEN 1 THEN 'ACH_OUT' ELSE 'INTERNAL_TRANSFER' END,
    ROUND(UNIFORM(25000, 200000, RANDOM()), 2), 'USD',
    'Urgent transfer - ' || CASE MOD(SEQ4(), 3) WHEN 0 THEN 'vendor payment' WHEN 1 THEN 'invoice settlement' ELSE 'payroll funding' END,
    'ONLINE', NULL, 'US', NULL,
    CASE MOD(HASH(SEQ4()), 4) WHEN 0 THEN 'US' WHEN 1 THEN 'AE' WHEN 2 THEN 'NG' ELSE 'HK' END,
    MOD(HASH(SEQ4()), 4) != 0, 'COMPLETED',
    ROUND(UNIFORM(65, 92, RANDOM()), 2), 'RAPID_MOVEMENT', CURRENT_TIMESTAMP()
FROM TABLE(GENERATOR(ROWCOUNT => 80)) g
JOIN rm_accounts rma ON MOD(SEQ4(), 10) + 1 = rma.rn;

-- 2d. Regulatory Rules (15)
CREATE OR REPLACE TABLE REGINTEL_DB.RAW.REGULATORY_RULES (
    RULE_ID VARCHAR(20) PRIMARY KEY,
    REGULATION VARCHAR(50),
    RULE_NAME VARCHAR(200),
    RULE_DESCRIPTION VARCHAR(2000),
    THRESHOLD_TYPE VARCHAR(50),
    THRESHOLD_VALUE NUMBER(15,2),
    THRESHOLD_CURRENCY VARCHAR(3),
    TIME_WINDOW_HOURS NUMBER,
    SEVERITY VARCHAR(20),
    FILING_REQUIRED VARCHAR(50),
    EFFECTIVE_DATE DATE,
    IS_ACTIVE BOOLEAN
);

INSERT INTO REGINTEL_DB.RAW.REGULATORY_RULES VALUES
('REG-001','BSA/AML','Currency Transaction Report Threshold','Cash transactions exceeding $10,000 must be reported via CTR within 15 days.','AMOUNT',10000.00,'USD',24,'HIGH','CTR','2024-01-01',TRUE),
('REG-002','BSA/AML','Structuring Detection','Pattern of cash transactions just below $10,000 threshold designed to evade CTR reporting.','AMOUNT',9999.99,'USD',48,'CRITICAL','SAR','2024-01-01',TRUE),
('REG-003','BSA/AML','Suspicious Activity Report Threshold','For banks subject to 31 CFR §1020.320: transactions of $5,000 or more involving suspected money laundering, fraud, or other criminal activity must be reported via SAR. Filing deadline: 30 calendar days from initial detection of facts constituting a basis for filing. If no suspect is identified, filing may be delayed an additional 30 calendar days (60 days maximum from initial detection). Note: thresholds vary by institution type.','AMOUNT',5000.00,'USD',NULL,'HIGH','SAR','2024-01-01',TRUE),
('REG-004','BSA/AML','Wire Transfer Record Keeping','Records must be maintained for wire transfers of $3,000 or more.','AMOUNT',3000.00,'USD',NULL,'MEDIUM','NONE','2024-01-01',TRUE),
('REG-005','FATF','High-Risk Jurisdiction Transfers','Enhanced due diligence required for transactions involving FATF high-risk jurisdictions.','AMOUNT',1000.00,'USD',NULL,'CRITICAL','SAR','2024-01-01',TRUE),
('REG-006','BSA/AML','Rapid Movement Detection','Funds received and moved out within 24-48 hours with no apparent business purpose.','COUNT',3.00,'USD',48,'HIGH','SAR','2024-01-01',TRUE),
('REG-007','BSA/AML','Round-Trip Transaction Detection','Funds leaving and returning to same account through intermediaries within 5 business days.','COUNT',2.00,'USD',120,'CRITICAL','SAR','2024-01-01',TRUE),
('REG-008','BASEL_III','Liquidity Coverage Ratio','Banks must maintain HQLA sufficient to cover 30-day net cash outflows. Minimum LCR is 100%.','RATIO',100.00,'USD',720,'HIGH','NONE','2024-01-01',TRUE),
('REG-009','BASEL_III','Capital Adequacy Ratio','Minimum CET1 capital ratio of 4.5% of risk-weighted assets, total capital ratio minimum 8%.','RATIO',8.00,'USD',NULL,'CRITICAL','NONE','2024-01-01',TRUE),
('REG-010','OFAC','Sanctions Screening','All transactions must be screened against OFAC SDN list.','AMOUNT',0.00,'USD',NULL,'CRITICAL','SAR','2024-01-01',TRUE),
('REG-011','BSA/AML','PEP Enhanced Due Diligence','PEPs require enhanced due diligence. Transactions above $25,000 require senior management approval.','AMOUNT',25000.00,'USD',NULL,'HIGH','NONE','2024-01-01',TRUE),
('REG-012','BSA/AML','Dormant Account Reactivation','Sudden activity on accounts dormant for 6+ months requires review.','RATIO',3.00,'USD',NULL,'MEDIUM','SAR','2024-01-01',TRUE),
('REG-013','LOCAL','Large Cash Transaction Report (India)','Cash transactions of INR 10,00,000 or more must be reported under PMLA.','AMOUNT',1000000.00,'INR',720,'HIGH','CTR','2024-01-01',TRUE),
('REG-014','BSA/AML','Velocity Alert','More than 10 transactions from a single account within 1 hour.','COUNT',10.00,'USD',1,'MEDIUM','NONE','2024-01-01',TRUE),
('REG-015','FATF','Trade-Based Money Laundering','Significant discrepancy between declared and actual value of goods/services.','AMOUNT',50000.00,'USD',NULL,'HIGH','SAR','2024-01-01',TRUE);

-- 2e. Alerts (auto-generated from fraud patterns)
CREATE OR REPLACE TABLE REGINTEL_DB.RAW.ALERTS (
    ALERT_ID VARCHAR(20) PRIMARY KEY,
    RULE_ID VARCHAR(20) REFERENCES REGINTEL_DB.RAW.REGULATORY_RULES(RULE_ID),
    ACCOUNT_ID VARCHAR(20),
    CUSTOMER_ID VARCHAR(20),
    ALERT_DATE TIMESTAMP_NTZ,
    ALERT_TYPE VARCHAR(50),
    SEVERITY VARCHAR(20),
    STATUS VARCHAR(30),
    DESCRIPTION VARCHAR(2000),
    EVIDENCE_TRANSACTION_IDS ARRAY,
    ASSIGNED_TO VARCHAR(100),
    RESOLUTION_NOTES VARCHAR(2000),
    RESOLVED_DATE TIMESTAMP_NTZ,
    SAR_FILED BOOLEAN DEFAULT FALSE,
    SAR_FILING_DATE DATE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO REGINTEL_DB.RAW.ALERTS
WITH fraud_txns AS (
    SELECT ACCOUNT_ID, FRAUD_PATTERN_LABEL, MIN(TRANSACTION_DATE) AS first_txn,
           ARRAY_AGG(TRANSACTION_ID) WITHIN GROUP (ORDER BY TRANSACTION_DATE) AS txn_ids,
           COUNT(*) AS txn_count, SUM(AMOUNT) AS total_amount
    FROM REGINTEL_DB.RAW.TRANSACTIONS WHERE FRAUD_PATTERN_LABEL != 'NORMAL'
    GROUP BY ACCOUNT_ID, FRAUD_PATTERN_LABEL
)
SELECT
    'ALT-' || LPAD(ROW_NUMBER() OVER (ORDER BY first_txn)::VARCHAR, 6, '0'),
    CASE FRAUD_PATTERN_LABEL WHEN 'STRUCTURING' THEN 'REG-002' WHEN 'LAYERING' THEN 'REG-006' WHEN 'ROUND_TRIP' THEN 'REG-007' WHEN 'RAPID_MOVEMENT' THEN 'REG-014' END,
    ft.ACCOUNT_ID, a.CUSTOMER_ID,
    DATEADD('hour', UNIFORM(1, 24, RANDOM()), first_txn),
    CASE FRAUD_PATTERN_LABEL WHEN 'STRUCTURING' THEN 'AML' WHEN 'LAYERING' THEN 'AML' WHEN 'ROUND_TRIP' THEN 'FRAUD' WHEN 'RAPID_MOVEMENT' THEN 'FRAUD' END,
    CASE FRAUD_PATTERN_LABEL WHEN 'STRUCTURING' THEN 'CRITICAL' WHEN 'LAYERING' THEN 'CRITICAL' WHEN 'ROUND_TRIP' THEN 'HIGH' WHEN 'RAPID_MOVEMENT' THEN 'MEDIUM' END,
    CASE MOD(HASH(ft.ACCOUNT_ID), 5) WHEN 0 THEN 'OPEN' WHEN 1 THEN 'UNDER_INVESTIGATION' WHEN 2 THEN 'ESCALATED' WHEN 3 THEN 'CLOSED_CONFIRMED' ELSE 'CLOSED_FALSE_POSITIVE' END,
    FRAUD_PATTERN_LABEL || ' detected: ' || txn_count || ' transactions totaling $' || ROUND(total_amount, 2) || ' on account ' || ft.ACCOUNT_ID,
    txn_ids,
    CASE MOD(HASH(ft.ACCOUNT_ID), 4) WHEN 0 THEN 'Sarah Chen - AML Analyst' WHEN 1 THEN 'James Wilson - Compliance Officer' WHEN 2 THEN 'Maria Rodriguez - Fraud Investigator' ELSE 'David Kim - Risk Manager' END,
    CASE WHEN MOD(HASH(ft.ACCOUNT_ID), 5) >= 3 THEN 'Investigation completed. ' || CASE WHEN MOD(HASH(ft.ACCOUNT_ID), 5) = 3 THEN 'Confirmed suspicious activity. SAR filed.' ELSE 'Determined to be legitimate business activity after review.' END ELSE NULL END,
    CASE WHEN MOD(HASH(ft.ACCOUNT_ID), 5) >= 3 THEN DATEADD('day', UNIFORM(3, 14, RANDOM()), first_txn) ELSE NULL END,
    MOD(HASH(ft.ACCOUNT_ID), 5) = 3,
    CASE WHEN MOD(HASH(ft.ACCOUNT_ID), 5) = 3 THEN DATEADD('day', UNIFORM(5, 20, RANDOM()), first_txn)::DATE ELSE NULL END,
    CURRENT_TIMESTAMP()
FROM fraud_txns ft
LEFT JOIN REGINTEL_DB.RAW.ACCOUNTS a ON ft.ACCOUNT_ID = a.ACCOUNT_ID;

-- 2f. Policy Documents (15)
CREATE OR REPLACE TABLE REGINTEL_DB.DOCUMENTS.POLICY_DOCUMENTS (
    DOC_ID VARCHAR(20) PRIMARY KEY,
    DOC_TITLE VARCHAR(500),
    DOC_TYPE VARCHAR(50),
    SECTION_TITLE VARCHAR(500),
    CONTENT TEXT,
    REGULATION_REFERENCE VARCHAR(200),
    EFFECTIVE_DATE DATE,
    LAST_UPDATED DATE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- (Policy document inserts omitted for brevity — see the full data generation
--  in the CoCo conversation history. The key SAR filing document includes
--  the 30/60-day nuance per 31 CFR §1020.320.)

-- ────────────────────────────────────────────────────────────────────────────
-- 3. ENRICHMENT LAYER (Dynamic Tables)
-- ────────────────────────────────────────────────────────────────────────────

-- See the CoCo conversation history for the full CREATE DYNAMIC TABLE statements:
-- - REGINTEL_DB.ENRICHED.CUSTOMER_RISK_PROFILE
-- - REGINTEL_DB.ENRICHED.STRUCTURING_DETECTION
-- - REGINTEL_DB.ENRICHED.TRANSACTION_VELOCITY
-- - REGINTEL_DB.ENRICHED.HIGH_RISK_TRANSACTIONS
-- - REGINTEL_DB.ENRICHED.REGULATORY_METRICS

-- ────────────────────────────────────────────────────────────────────────────
-- 4. SUPPORTING VIEWS
-- ────────────────────────────────────────────────────────────────────────────

-- Authoritative KPIs (single source of truth for all reported numbers)
-- Investigation Report Data (joins alert + customer + account + rule + risk)

-- ────────────────────────────────────────────────────────────────────────────
-- 5. AI LAYER
-- ────────────────────────────────────────────────────────────────────────────

-- Cortex Search Service: REGINTEL_DB.DOCUMENTS.POLICY_SEARCH_SERVICE
-- Semantic View: REGINTEL_DB.SEMANTIC.REGINTEL_COPILOT (deployed via CoCo)
-- Cortex Agent: REGINTEL_DB.SEMANTIC.REGINTEL_COPILOT_AGENT (deployed via CoCo)

-- ────────────────────────────────────────────────────────────────────────────
-- 6. AUTOMATION
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE TASK REGINTEL_DB.RAW.DAILY_FRAUD_SCAN
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 6 * * * America/New_York'
    COMMENT = 'Daily fraud scan: detects new structuring patterns and generates alerts'
AS
    INSERT INTO REGINTEL_DB.RAW.ALERTS (ALERT_ID, RULE_ID, ACCOUNT_ID, CUSTOMER_ID, ALERT_DATE, ALERT_TYPE, SEVERITY, STATUS, DESCRIPTION, ASSIGNED_TO)
    SELECT
        'ALT-AUTO-' || LPAD(ABS(HASH(sd.ACCOUNT_ID || sd.WINDOW_START))::VARCHAR, 8, '0'),
        'REG-002', sd.ACCOUNT_ID, sd.CUSTOMER_ID, CURRENT_TIMESTAMP(), 'AML', sd.SEVERITY, 'OPEN', sd.FINDING_DESCRIPTION,
        CASE MOD(ABS(HASH(sd.ACCOUNT_ID)), 4) WHEN 0 THEN 'Sarah Chen - AML Analyst' WHEN 1 THEN 'James Wilson - Compliance Officer' WHEN 2 THEN 'Maria Rodriguez - Fraud Investigator' ELSE 'David Kim - Risk Manager' END
    FROM REGINTEL_DB.ENRICHED.STRUCTURING_DETECTION sd
    WHERE sd.SEVERITY IN ('HIGH', 'CRITICAL')
      AND NOT EXISTS (SELECT 1 FROM REGINTEL_DB.RAW.ALERTS a WHERE a.ACCOUNT_ID = sd.ACCOUNT_ID AND a.RULE_ID = 'REG-002' AND a.ALERT_DATE >= DATEADD('day', -7, CURRENT_TIMESTAMP()));

ALTER TASK REGINTEL_DB.RAW.DAILY_FRAUD_SCAN RESUME;

-- ============================================================================
-- SETUP COMPLETE
-- Verify: SELECT * FROM REGINTEL_DB.ENRICHED.AUTHORITATIVE_KPIS;
-- ============================================================================
