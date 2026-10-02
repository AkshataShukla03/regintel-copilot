# RegIntel Copilot

**Risk, Fraud & Regulatory Intelligence Copilot for Banking and NBFC Teams**

Built entirely with [Snowflake CoCo (Cortex Code)](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-code) — from data generation through deployment.

---

## What It Does

RegIntel Copilot is an AI-powered compliance assistant that lets banking compliance teams ask natural language questions and receive **governed, explainable, evidence-backed answers** — covering the full workflow from fraud signal detection to audit-ready investigation reports.

**The core differentiator is not fraud detection.** There are thousands of fraud detection systems. The differentiator is:

> **Structured evidence + Regulatory knowledge + Governed AI + Auditability** — in a single conversational interface.

When an analyst asks *"Why is this account high-risk, and what regulatory action is required?"*, the system simultaneously queries transaction data for evidence, searches policy documents for applicable rules, and produces a response that cites both — with a clear chain from signal to evidence to finding.

---

## Architecture

```
                         ┌──────────────────────────────────┐
                         │         STREAMLIT APP             │
                         │  Command · Fraud · Alerts · Chat  │
                         └──────────────┬───────────────────┘
                                        │
                                ┌───────┴───────┐
                                │ CORTEX AGENT  │
                                └───┬───────┬───┘
                                    │       │
                    ┌───────────────┘       └───────────────┐
                    ▼                                       ▼
            CORTEX ANALYST                          CORTEX SEARCH
            (Text-to-SQL)                           (Policy RAG)
                    │                                       │
                    ▼                                       ▼
            SEMANTIC VIEW                           15 Policy Docs
            7 tables · 10 VQRs                      AML · Basel · OFAC
                    │
                    ▼
        ┌───────────────────────┐
        │   DYNAMIC TABLES (5)  │
        │   5-minute refresh    │
        ├───────────────────────┤
        │ Customer Risk Profile │
        │ Structuring Detection │
        │ Transaction Velocity  │
        │ High-Risk Transactions│
        │ Regulatory Metrics    │
        └───────────┬───────────┘
                    ▼
        ┌───────────────────────┐
        │      RAW DATA         │
        │ 500 customers         │
        │ 1,200 accounts        │
        │ 42,477 transactions   │
        │ 15 regulatory rules   │
        │ 29 alerts             │
        └───────────────────────┘
                    ▲
                    │ Daily 6 AM ET
            ┌───────┴───────┐
            │  FRAUD SCAN   │
            │  (Scheduled)  │
            └───────────────┘
```

---

## Key Features

### Command Center
Real-time compliance dashboard with hero KPIs:
- **$210.36M** modeled suspicious exposure across **2,477** flagged transactions
- Active alerts with SLA-at-risk tracking (approaching SAR filing deadlines)
- Customer risk distribution and fraud pattern activity charts
- **Investigation Queue** — prioritized cases requiring analyst action

### Fraud Detection
- **Structuring Detection** — repeated sub-threshold cash deposits within aggregation windows, evaluated as transaction patterns
- **Layering** — rapid multi-hop transfers through account chains
- **Round-Tripping** — funds returning to origin via intermediaries
- **Rapid Movement** — burst high-value transfers inconsistent with baseline

### Investigation Report Generator
From any alert, generates a structured 7-section report:
1. Subject Information (customer + account)
2. Risk Assessment (composite score, PEP/sanctions flags)
3. Alert Details & Fraud Typology (triggered rule, threshold)
4. Supporting Transaction Evidence (individual transactions)
5. Applicable Regulatory Requirements (from Cortex Agent policy search)
6. Investigation Findings
7. Recommended Next Steps + Disclaimer

### Ask Copilot
Natural language interface backed by dual-tool Cortex Agent:
- **Data questions** → Cortex Analyst queries the semantic view
- **Policy questions** → Cortex Search retrieves regulatory documents
- **Combined questions** → Both tools used, response cites evidence + regulation

---

## Regulatory Scope

This prototype models a multi-framework compliance environment:

| Framework | Coverage |
|-----------|----------|
| **BSA/AML** | $10,000 CTR threshold, SAR criteria per 31 CFR §1020.320, structuring detection |
| **Basel III** | Liquidity Coverage Ratio (100% minimum), Capital Adequacy Ratios |
| **OFAC** | SDN list screening, blocking and reporting requirements |
| **FATF** | High-risk jurisdiction guidance, enhanced due diligence recommendations |

SAR filing logic models the 30-day deadline from initial detection, with the 60-day extension when no suspect is identified (per FinCEN filing instructions).

> **Note:** In production, regulatory scope would be scoped to the specific institution's obligations. This prototype includes all frameworks to demonstrate cross-domain regulatory reasoning.

---

## Tech Stack

| Component | Snowflake Service |
|-----------|------------------|
| Enrichment Pipeline | Dynamic Tables (5 tables, 5-min refresh) |
| AI Orchestration | Cortex Agent |
| Structured Data Analytics | Cortex Analyst + Semantic View |
| Policy Knowledge Retrieval | Cortex Search |
| Governed Data Layer | Semantic Views (7 tables, 10 VQRs) |
| Automated Monitoring | Scheduled Tasks |
| Application | Streamlit in Snowflake |
| Development | Snowflake CoCo (Cortex Code) |

---

## Project Structure

```
regintel-copilot/
├── streamlit_app.py          # Streamlit application (5 views)
├── snowflake.yml             # Snowflake app configuration
├── pyproject.toml            # Python dependencies
├── .streamlit/
│   └── config.toml           # Streamlit theme configuration
└── setup/
    └── setup.sql             # Complete DDL + data generation script

docs/
├── REGINTEL_MVP_BRIEF_FINAL.md   # Submission brief (paragraph format)
└── REGINTEL_PROJECT_DOCUMENT.pdf # Project document with walkthrough
```

---

## Setup & Deployment

### Prerequisites
- Snowflake account with ACCOUNTADMIN role (or equivalent privileges)
- Warehouse (e.g., `COMPUTE_WH`)
- Compute pool for Streamlit (e.g., `SYSTEM_COMPUTE_POOL_CPU`)

### Step 1: Run the Setup Script
```sql
-- Execute setup/setup.sql in a Snowflake worksheet
-- This creates: database, schemas, tables, synthetic data,
-- dynamic tables, semantic view, Cortex Search, Cortex Agent,
-- and the scheduled fraud scan task.
```

### Step 2: Deploy the Streamlit App
1. Open Snowsight → Workspaces
2. Create a new Streamlit project from the `regintel-copilot/` folder
3. Set **query_warehouse** and **compute_pool** in App Settings
4. Click **Run**

### Step 3: Test the Agent
```sql
SELECT TRY_PARSE_JSON(
    SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
        'REGINTEL_DB.SEMANTIC.REGINTEL_COPILOT_AGENT',
        '{"messages": [{"role": "user", "content": [{"type": "text", "text": "Which accounts show structuring patterns?"}]}]}',
        TRUE
    )
) AS RESPONSE;
```

---

## CoCo Usage (Full Lifecycle)

| Phase | What CoCo Did |
|-------|---------------|
| **Planning** | Designed data model, architecture, regulatory scope |
| **Data Generation** | 42,477 synthetic transactions with 4 labeled fraud patterns |
| **Development** | 5 dynamic tables, semantic view, Cortex Search, Cortex Agent, Streamlit app |
| **Execution** | Deployed all components, created scheduled automation |
| **Testing** | Validated agent responses, verified SQL accuracy via VQRs |

---

## Limitations

This is a **production-oriented prototype** built on synthetic data. A production deployment would require: real transaction data with access controls, model validation and explainability testing, regulatory change management, disaster recovery, security review, and integration with existing case management and filing systems.

---

## License

MIT License — see [LICENSE](LICENSE)

---

## Built With

- [Snowflake Cortex](https://www.snowflake.com/en/data-cloud/cortex/) — AI/ML platform
- [Snowflake CoCo](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-code) — Development agent
- [Streamlit](https://streamlit.io/) — Application framework
