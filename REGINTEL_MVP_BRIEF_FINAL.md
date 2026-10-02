RegIntel Copilot — Prototype/MVP Brief (Final Submission)


Problem and Opportunity

Banking and NBFC compliance teams manage fraud detection, risk monitoring, and regulatory reporting across multiple frameworks through largely manual, siloed processes. Analysts spend the majority of their time toggling between transaction monitoring systems, policy documents, spreadsheet trackers, and filing templates, gathering and assembling data rather than investigating and exercising judgment. Industry estimates suggest that global spending on financial crime compliance runs in the hundreds of billions of dollars annually, that rule-based transaction monitoring systems generate high rates of false positive alerts, and that manual investigation of a single alert can take several hours depending on complexity. The consequences of inefficiency are regulatory penalties, missed filing deadlines, and investigator burnout. There is a clear need for a system that can surface risk and fraud signals from structured transaction data, combine them with regulatory policy knowledge, and produce audit-ready, evidence-backed outputs from natural language questions, so compliance professionals can focus on investigation and decision-making rather than data assembly.

Regulatory Scope: This prototype models a multi-framework compliance environment. It includes U.S.-specific regulations (BSA/AML with FinCEN CTR and SAR filing requirements, OFAC sanctions screening) alongside international frameworks (Basel III capital and liquidity standards, FATF recommendations on high-risk jurisdictions). In a production deployment, these would be scoped to a specific institution's regulatory obligations. For this prototype, we include all frameworks to demonstrate the system's ability to reason across regulatory domains.


Solution Overview

RegIntel Copilot is a compliance assistant built entirely on Snowflake that enables business and compliance users to ask natural language questions and receive governed, explainable, evidence-backed answers covering the full flow from signal detection to documented regulatory findings.

The system's core differentiator is not fraud detection itself — there are many fraud detection systems. The differentiator is the combination of structured evidence retrieval, regulatory knowledge retrieval, governed AI, and auditability in a single conversational interface. When an analyst asks "Why is this account high-risk, and what regulatory action is required?", the system simultaneously queries transaction data for evidence, searches policy documents for applicable rules, and produces a response that cites both — with a clear chain from signal to evidence to finding.

The architecture uses two distinct AI capabilities wired through a single Cortex Agent: structured data analytics through Cortex Analyst with a semantic view over enriched transaction and risk data, and unstructured policy knowledge retrieval through Cortex Search over indexed regulatory documents. Raw data flows into dynamic tables that continuously enrich and score for fraud patterns and risk signals, which feed the semantic view. Policy documents are indexed in a Cortex Search service. The agent orchestrates across both tools, and a Streamlit application provides a visual dashboard, an alert investigation workflow with report generation, and the conversational interface. A scheduled Snowflake task automates daily fraud scanning.


What We Built

The prototype is deployed on Snowflake under the REGINTEL_DB database with four schemas: RAW for source data, ENRICHED for transformed dynamic tables, SEMANTIC for the semantic view and agent, and DOCUMENTS for policy content and the search service. All numbers below are drawn from a single authoritative KPI view (REGINTEL_DB.ENRICHED.AUTHORITATIVE_KPIS) to ensure consistency.

Data Layer: The raw data contains 500 synthetic customer profiles with KYC fields including PEP flags, sanctions screening, adverse media indicators, and risk ratings; 1,200 bank accounts across five types; 42,477 transactions spanning 90 days; 15 regulatory rules covering BSA/AML thresholds, Basel III ratios, OFAC screening, and FATF guidance; 29 compliance alerts in various investigation stages; and 15 detailed policy documents covering AML procedures, SAR and CTR filing requirements, Basel III frameworks, sanctions screening, KYC verification, and fraud detection typologies.

Embedded Fraud Patterns: The transaction data contains four fraud patterns as labeled ground truth for detection validation. Structuring: 1,357 transactions flagged through pattern analysis — the prototype detects potential structuring by identifying repeated sub-threshold cash deposits within defined aggregation windows and evaluating the resulting transaction pattern against baseline account behavior (deposits in the $8,000 to $9,950 range clustered within 48-hour windows, totaling $12,182,660.63 in modeled exposure). Layering: 200 transactions (rapid movement of $50,000 to $500,000 through chains of accounts with international hops, totaling $55,156,647.00). Round-tripping: 120 transactions (funds leaving and returning to the same beneficial owner through intermediary accounts, totaling $53,234,792.00). Rapid movement: 800 transactions (burst patterns of high-value outbound transfers inconsistent with account history, totaling $89,788,024.00). Total flagged transactions: 2,477. Total modeled suspicious exposure: $210,362,123.63.

Enrichment Pipeline: Five dynamic tables refresh every five minutes. Customer Risk Profile computes a composite risk score from 0 to 100 for each customer combining KYC status, PEP and sanctions flags, adverse media, transaction anomalies, and active alerts. Structuring Detection performs windowed analysis over cash transactions in the $8,000 to $9,999 range within 48-hour windows, identifying 296 distinct findings with severity classifications. Transaction Velocity tracks daily counts and volumes per account against 30-day rolling averages, flagging deviations exceeding 3x. High Risk Transactions applies multi-signal scoring to 2,494 transactions combining transaction-level risk, customer risk, jurisdiction risk, and fraud pattern detection. Regulatory Metrics produces 23 compliance KPIs refreshed continuously.

AI Layer: A semantic view over seven tables with ten verified queries covering common compliance questions. A Cortex Search service indexing all 15 policy documents with attributes for document type, section, and regulation reference. A Cortex Agent that wires both tools together with compliance-specific response instructions including evidence citation, regulatory rule references, and recommended actions.

Investigation Report Generator: From any alert in the system, the application can generate a structured investigation report containing: case identifier, subject information (customer and account details), risk assessment (composite score, PEP/sanctions status, flagged transaction counts), alert details and fraud typology (triggered rule, threshold, description), supporting transaction evidence (individual transactions with amounts, dates, risk scores), applicable regulatory requirements (retrieved from policy documents by the Cortex Agent), investigation findings and current status, recommended next steps based on the alert context, evidence source references, and a disclaimer that the output requires analyst review before regulatory action. This single workflow demonstrates the complete signal-to-finding pipeline in one interaction.

Automation: A scheduled Snowflake task runs daily at 6 AM ET to detect new structuring patterns and generate alerts automatically.


Target Users

The system serves five compliance personas. AML Analysts use it to identify structuring patterns, review transaction clusters, and prepare SAR narratives. Compliance Officers monitor KPIs, track alert SLAs, and assess program effectiveness. Risk Managers review customer risk profiles and assess aggregate exposure. Fraud Investigators drill into specific transaction chains for layering and round-tripping. Regulatory Reporters check CTR-eligible transactions, review filing deadlines, and generate documentation.


CoCo Usage Across the Lifecycle

Every phase of this prototype was built using Snowflake CoCo. During planning, CoCo explored the problem space, designed the data model, and outlined the architecture. During development, CoCo generated all synthetic data with referentially consistent foreign keys and labeled fraud patterns, created five dynamic tables, authored the semantic view with verified queries, built the Cortex Search service, assembled the Cortex Agent, and scaffolded the Streamlit application with investigation report generation. During execution, CoCo deployed the agent, created the scheduled task, and ran the end-to-end system. During testing, CoCo validated agent responses, confirmed correct tool routing, and verified SQL accuracy through verified queries.

Specific capabilities demonstrated: synthetic data generation with embedded fraud signals, data pipeline creation using dynamic tables, semantic model authoring with verified queries, document processing via Cortex Search, Streamlit app generation including the investigation report workflow, scheduled automation, and guardrails through semantic view scoping.


Judging Criteria Alignment

Real-world relevance: The solution models actual regulatory frameworks with defensible thresholds — U.S. bank-focused BSA/AML reporting rules including the $10,000 CTR threshold and applicable SAR reporting criteria for qualifying suspicious transactions, the Basel III fully-implemented 100% LCR minimum, and FATF high-risk jurisdiction guidance. For this prototype, the SAR logic models the $5,000 threshold applicable to banks under 31 CFR §1020.320; thresholds vary by institution type and jurisdiction in production. It uses real fraud typologies that compliance teams encounter and follows actual filing workflows including the nuanced SAR timeline (30 calendar days from initial detection; up to 60 days if no suspect is identified, per FinCEN filing instructions). The investigation report generator mirrors the structure of enterprise case management outputs.

Technical execution: Entirely Snowflake-native with no external services. Dynamic tables for near-real-time enrichment. Dual-tool Cortex Agent combining structured analytics and unstructured retrieval. Semantic view with verified queries for governed SQL generation. Scheduled automation for continuous monitoring.

Solution completeness: Covers the full signal-to-finding pipeline from raw transactions through enrichment, detection, evidence gathering, regulatory reasoning, and documented output. The investigation report demonstrates the complete workflow in one interaction: detection, evidence, regulation, finding, recommended action.


Demo Script (3 Minutes)

Opening (0:00-0:20): "It is 9 AM. An AML analyst has 296 structuring findings to investigate. Instead of manually opening transaction systems and policy documents, let us investigate one case."

Click an alert in the Alerts and Investigation view. Select a CRITICAL severity structuring alert.

Investigation (0:20-1:00): "Why was this customer flagged?" Click Generate Investigation Report. The system compiles the case: customer profile, risk score, account details, the specific transactions ($8,000 to $9,950 cash deposits within a 48-hour window), the regulatory rule that triggered the alert (BSA/AML structuring detection), and recommended next steps.

Regulatory reasoning (1:00-1:40): Switch to Ask Copilot. Type: "Does the structuring pattern on this account meet our SAR investigation criteria? Cite the relevant policy." The agent returns a structured assessment: (1) Assessment — "Potentially reportable; analyst review required," (2) Transaction Evidence — count, aggregate amount, aggregation window, (3) Risk Indicators — repeated sub-threshold deposits, aggregated cash activity, pattern inconsistent with baseline, (4) Regulatory Context — BSA/SAR policy section reference, (5) Filing Timeline — "30 calendar days from initial detection; if no suspect is identified, filing may be delayed up to 60 calendar days per FinCEN filing instructions," (6) Supporting transaction IDs, (7) Disclaimer that final regulatory determination requires authorized compliance review. This structured response demonstrates the agent is not merely pattern-matching keywords — it is connecting evidence to regulation.

Evidence drill-down (1:40-2:20): "Show me the transactions supporting this conclusion." The agent returns the individual transactions with amounts, dates, and risk scores. Then: "What is our SAR filing deadline if we have not identified a suspect?" The agent returns the nuanced answer: 30 calendar days from initial detection in the standard case, with an additional 30 days (60 total maximum) if no suspect is identified — citing the applicable FinCEN filing instructions.

Closing (2:20-3:00): "What we just demonstrated is the complete compliance workflow: detection of a fraud pattern, investigation with structured evidence, regulatory reasoning grounded in actual policy, and a documented finding with recommended actions. Everything runs on Snowflake. The data pipeline refreshes every five minutes. The daily fraud scan runs automatically. The agent is governed through the semantic view — it can only query what the semantic model exposes. Built entirely with CoCo from data generation through deployment."

What this demonstrates: Detection, Investigation, Regulatory Reasoning, Evidence, Documentation — in three minutes, from a single platform.


Snowflake Services Used

Dynamic Tables for the enrichment pipeline. Cortex Agent for natural language orchestration. Cortex Analyst for text-to-SQL over the governed semantic view. Cortex Search for retrieval over policy documents. Semantic Views for the governed data layer with verified queries. Scheduled Tasks for automated daily scanning. Streamlit for the dashboard, investigation reports, and conversational interface.


Limitations and Scope

This is a production-oriented prototype built on synthetic data in a hackathon environment. It demonstrates architectural patterns and AI capabilities, not a production-ready compliance system. A production deployment would require: real transaction data with proper access controls, model validation and explainability testing, regulatory change management processes, disaster recovery and audit logging, security review and penetration testing, and integration with existing case management and filing systems. The regulatory frameworks modeled (BSA/AML, Basel III, OFAC, FATF) are included for breadth of demonstration; a production system would be scoped to the specific institution's regulatory obligations.


Future Directions

Counterparty network graph analysis for layering chain visualization. MCP integration with Slack for real-time alert notifications. Automated SAR XML generation in FinCEN-ready format. ML-based anomaly detection trained on the labeled fraud data. Multi-entity organizational rollup for holding company compliance views. Publication as a reusable Cortex Code skill.
