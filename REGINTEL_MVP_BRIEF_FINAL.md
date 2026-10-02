RegIntel Copilot — Project Brief
The Problem
Compliance teams in banks and NBFCs deal with fraud detection, risk monitoring, and regulatory reporting every day. Most of this work is still manual. An analyst investigating a single suspicious activity alert might spend hours switching between transaction monitoring tools, reading through policy PDFs, checking customer KYC records, and filling out filing templates.

This manual process leads to three problems: missed filing deadlines (a SAR must be filed within 30 days of detection), high false positive rates in rule-based monitoring systems, and analyst burnout from repetitive data assembly work. The actual investigation and judgment — the part that requires human expertise — gets squeezed.

We built RegIntel Copilot to fix this.

What RegIntel Copilot Does
RegIntel Copilot is a compliance assistant that runs entirely on Snowflake. A compliance analyst can ask it a plain English question and get back an answer that is grounded in actual transaction data and actual regulatory policy — not a generic AI response.

For example, an analyst can ask: "Why is account ACCT-0000001 flagged as high risk, and what regulatory action is required?"

The system does two things simultaneously:

It queries the transaction database to find the specific evidence (which transactions, what amounts, what pattern)
It searches the compliance policy documents to find the applicable regulatory rules (which filing is required, what the deadline is, what the threshold is)
Then it combines both into a single response with citations.

This is the key difference from typical fraud detection tools. We are not just detecting fraud. We are connecting fraud signals to regulatory knowledge and producing evidence-backed, audit-ready outputs that an analyst can act on.

How It Works (Architecture)
The system has four layers, each built on Snowflake services:

Layer 1 — Raw Data All source data lives in the REGINTEL_DB.RAW schema. This includes 500 customer profiles with full KYC information (identity verification status, PEP flags, sanctions screening results, risk ratings), 1,200 bank accounts, 42,477 transactions spanning 90 days, 15 regulatory rules with specific thresholds, 29 compliance alerts at various investigation stages, and 15 policy documents covering AML procedures, filing requirements, Basel III frameworks, and sanctions screening.

Layer 2 — Enrichment (Dynamic Tables) Five dynamic tables in the REGINTEL_DB.ENRICHED schema transform raw data into risk signals. These refresh automatically every five minutes, so the system always has near-real-time data. The five tables are:

Customer Risk Profile: Calculates a composite risk score from 0 to 100 for every customer. The score combines KYC status, PEP and sanctions flags, adverse media indicators, transaction anomalies, and active alert counts. A customer with expired KYC, a PEP flag, and multiple flagged transactions will score much higher than a low-risk retail customer.

Structuring Detection: Looks for potential structuring patterns — specifically, repeated cash deposits in the 
8
,
000
t
o
8,000to9,950 range clustered within 48-hour windows. This is not simply flagging any transaction below $10,000. The system evaluates the pattern: how many deposits, how close together, what the aggregate amount is, and whether this behavior is consistent with the customer's normal activity. It has identified 296 distinct structuring findings with severity classifications (Critical, High, Medium, Low).

Transaction Velocity: Tracks how many transactions each account makes per day and what volume they represent, compared against that account's 30-day rolling average. If today's activity is more than 3x the historical baseline, the system flags it as an anomaly. This catches accounts that suddenly become very active.

High-Risk Transactions: Applies multi-signal scoring to every transaction. A single transaction might be flagged because of its own risk score, because the customer is high-risk, because it involves a high-risk jurisdiction, or because it matches a known fraud pattern. The system combines all these signals into one score. It has flagged 2,494 transactions this way.

Regulatory Metrics: A single-row dashboard of 23 compliance KPIs that refresh continuously — open alerts, SARs filed, KYC gaps, CTR-eligible transactions, and fraud pattern counts.

Layer 3 — AI (Cortex Agent + Semantic View + Cortex Search) This is where the intelligence lives. A Cortex Agent sits at the center and has access to two tools:

Cortex Analyst with a Semantic View: The semantic view covers seven tables and includes ten verified queries (pre-validated SQL for common compliance questions). When a user asks a data question like "Which accounts show structuring patterns?", the agent generates governed SQL through the semantic view and returns the actual data.

Cortex Search over Policy Documents: All 15 policy documents are indexed in a Cortex Search service. When a user asks a policy question like "What are the SAR filing requirements?", the agent retrieves the relevant sections from the policy knowledge base.

When a question involves both data and policy (which most real compliance questions do), the agent uses both tools and combines the results.

Layer 4 — Application (Streamlit) A five-view Streamlit application provides the user interface. More on each view below.

Application Features (Five Views)
1. Command Center The main dashboard. Opens with three headline numbers that immediately answer the most important questions: How much risk ($210.36M in modeled suspicious exposure), How many flags (2,477 flagged transactions across 4 fraud typologies), and What needs attention (active alerts plus any cases approaching filing deadlines). Below these are customer risk distribution and fraud pattern activity charts, followed by an Investigation Queue showing the highest-priority cases sorted by severity and exposure amount.

2. Fraud Detection Two tabs for investigating fraud patterns. The Structuring Detection tab shows 296 findings where the system identified repeated sub-threshold cash deposits within aggregation windows. Each finding shows the account, customer, time window, number of transactions, total amount, average amount, and severity. The High-Risk Transactions tab shows all 2,494 flagged transactions with their fraud pattern labels, combined risk scores, and primary risk reasons. Both tabs are filterable.

3. Alerts and Investigation This is the most important view for the demo. It has two tabs:

The Alert Queue shows all compliance alerts with their type, severity, status, assigned investigator, and the regulatory rule that triggered them.

The Investigation Report Generator is the hero feature. Select any alert and click "Generate Investigation Report." The system produces a structured, seven-section report:

Subject Information — Customer name, ID, type, nationality, account details, KYC status
Risk Assessment — Composite risk score out of 100, PEP and sanctions flags, flagged transaction counts, total transaction volume
Alert Details and Fraud Typology — Which rule triggered the alert, the threshold, the description of the suspicious activity
Supporting Transaction Evidence — The actual transactions that constitute the finding, with individual amounts, dates, channels, and risk scores
Applicable Regulatory Requirements — Retrieved live from the policy knowledge base by the Cortex Agent, citing specific policy sections and filing deadlines
Investigation Findings — Current case status, whether a SAR has been filed, resolution notes
Recommended Next Steps — Context-aware recommendations (for example: if KYC is expired, it recommends KYC refresh; if the customer is a PEP, it recommends senior management approval; if a SAR has not been filed, it cites the 30-day deadline with the 60-day extension for unidentified suspects)
Every report includes a disclaimer that the output is AI-generated and requires review by a qualified compliance analyst before any regulatory action.

This single feature demonstrates the complete pipeline: detection, evidence, regulatory reasoning, documentation — in one click.

4. Customer Risk Browse all 500 customer profiles filtered by risk rating and minimum composite score. Each row shows the customer's PEP and sanctions flags, number of accounts, total balance, flagged transaction count, and active alerts. A separate section shows customers with expired, failed, or pending KYC that need renewal, sorted by risk score so the highest-risk gaps are addressed first.

5. Ask Copilot A chat interface where users type natural language questions. The Cortex Agent routes each question to the right tool (data, policy, or both) and returns an evidence-backed answer. Examples of what it can answer:

"Which accounts show structuring patterns needing SAR review?" — Returns specific accounts with transaction details
"Does this pattern meet our SAR investigation criteria? Cite the policy." — Returns the applicable BSA/AML policy section, the threshold, and the filing timeline
"What is our false positive rate for AML alerts?" — Queries the alert data and calculates the rate
"What are the Basel III liquidity coverage ratio requirements?" — Searches the regulatory knowledge base
What Makes This Different
There are many fraud detection tools. RegIntel Copilot is not competing with them on detection. The unique value is in what happens after detection:

Evidence + Regulation + Governed AI + Auditability in one place.

Most compliance workflows today look like this: a monitoring system generates an alert, then an analyst manually opens several systems to gather evidence, manually looks up the applicable regulation, manually writes up the finding, and manually determines next steps. Each step is disconnected.

RegIntel Copilot collapses all of that into a single interaction. The analyst asks a question (or clicks "Generate Investigation Report"), and the system returns the evidence from transaction data, the applicable regulation from policy documents, and the recommended actions — all cited and traceable.

The system is also governed. The Cortex Agent can only query data through the semantic view, which means it cannot access tables it should not see. Answers are grounded in actual data and actual policy text, not general AI knowledge. Every claim in the response can be traced back to a specific transaction or a specific policy section.

Fraud Patterns Modeled
The synthetic data contains four fraud typologies as labeled ground truth:

**Structuring (
12.18M exposure, 1,357 transactions):
∗
∗
T
h
e
s
y
s
t
e
m
d
e
t
e
c
t
s
p
o
t
e
n
t
i
a
l
s
t
r
u
c
t
u
r
i
n
g
b
y
i
d
e
n
t
i
f
y
i
n
g
r
e
p
e
a
t
e
d
s
u
b
−
t
h
r
e
s
h
o
l
d
c
a
s
h
d
e
p
o
s
i
t
s
w
i
t
h
i
n
d
e
f
i
n
e
d
a
g
g
r
e
g
a
t
i
o
n
w
i
n
d
o
w
s
a
n
d
e
v
a
l
u
a
t
i
n
g
t
h
e
r
e
s
u
l
t
i
n
g
t
r
a
n
s
a
c
t
i
o
n
p
a
t
t
e
r
n
a
g
a
i
n
s
t
b
a
s
e
l
i
n
e
a
c
c
o
u
n
t
b
e
h
a
v
i
o
r
.
D
e
p
o
s
i
t
s
i
n
t
h
e
12.18Mexposure,1,357transactions):∗∗Thesystemdetectspotentialstructuringbyidentifyingrepeatedsub−thresholdcashdepositswithindefinedaggregationwindowsandevaluatingtheresultingtransactionpatternagainstbaselineaccountbehavior.Depositsinthe8,000 to 
9
,
950
r
a
n
g
e
,
c
l
u
s
t
e
r
e
d
w
i
t
h
i
n
48
−
h
o
u
r
w
i
n
d
o
w
s
,
w
i
t
h
a
g
g
r
e
g
a
t
e
a
m
o
u
n
t
s
w
e
l
l
a
b
o
v
e
t
h
e
9,950range,clusteredwithin48−hourwindows,withaggregateamountswellabovethe10,000 CTR threshold.

**Layering (
55.16
M
e
x
p
o
s
u
r
e
,
200
t
r
a
n
s
a
c
t
i
o
n
s
)
:
∗
∗
R
a
p
i
d
m
o
v
e
m
e
n
t
o
f
l
a
r
g
e
a
m
o
u
n
t
s
(
55.16Mexposure,200transactions):∗∗Rapidmovementoflargeamounts(50,000 to $500,000) through chains of accounts with international hops. Funds move through multiple intermediaries quickly, with no apparent business purpose, making the money trail difficult to follow.

Round-Tripping ($53.23M exposure, 120 transactions): Funds leave an account and return to the same beneficial owner through intermediary accounts within a short period. This is designed to create the appearance of legitimate business transactions while the money ultimately returns to its origin.

Rapid Movement ($89.79M exposure, 800 transactions): Burst patterns of high-value outbound transfers that are inconsistent with the account's historical behavior. An account that normally processes a few transactions per week suddenly sends out dozens of large transfers in hours.

Total flagged transactions: 2,477. Total modeled suspicious exposure: $210,362,123.63.

Regulatory Scope
The prototype covers four regulatory frameworks:

BSA/AML (U.S.): Currency Transaction Report (CTR) threshold of 
10
,
000
f
o
r
c
a
s
h
t
r
a
n
s
a
c
t
i
o
n
s
.
S
A
R
r
e
p
o
r
t
i
n
g
c
r
i
t
e
r
i
a
f
o
r
q
u
a
l
i
f
y
i
n
g
s
u
s
p
i
c
i
o
u
s
t
r
a
n
s
a
c
t
i
o
n
s
p
e
r
31
C
F
R
§
1020.320
(
t
h
e
10,000 for cash transactions. SAR reporting criteria for qualifying suspicious transactions per 31CFR §1020.320(the5,000 threshold applicable to banks; note that thresholds vary by institution type). SAR filing deadline of 30 calendar days from initial detection, with an extension to 60 calendar days if no suspect is identified (per FinCEN filing instructions). Structuring detection and wire transfer record-keeping requirements.

Basel III (International): Liquidity Coverage Ratio with a fully-implemented minimum of 100%. Capital Adequacy Ratios including CET1 minimum of 4.5% and total capital minimum of 8% of risk-weighted assets.

OFAC (U.S.): Sanctions screening against the SDN list. Blocking and reporting requirements within 10 business days of a confirmed match.

FATF (International): High-risk jurisdiction guidance for enhanced due diligence. Note that FATF jurisdiction lists are time-sensitive and must be updated per current FATF publications.

In a production system, the regulatory scope would be configured for the specific institution's obligations. This prototype includes all four frameworks to demonstrate cross-domain regulatory reasoning.

Automation
A Snowflake scheduled task runs every day at 6:00 AM ET. It scans the Structuring Detection dynamic table for new high-severity findings, checks whether an alert already exists for that account in the last seven days, and if not, creates a new alert and assigns it to an investigator. This means the system continuously monitors for new fraud patterns without any manual intervention.

How CoCo Was Used
The entire prototype was built using Snowflake CoCo (Cortex Code), from planning through testing:

Planning: CoCo designed the database schema, selected the fraud typologies, and outlined the full architecture before any code was written.
Data Generation: CoCo generated all 42,477 synthetic transactions with referentially consistent foreign keys and four labeled fraud patterns embedded as ground truth.
Pipeline Development: CoCo wrote all five dynamic table definitions with windowed aggregations, composite scoring logic, and anomaly detection.
Semantic Layer: CoCo authored the seven-table semantic view with ten verified queries and deployed it to Snowflake.
Search Service: CoCo created the Cortex Search service and indexed all 15 policy documents.
Agent: CoCo configured and deployed the dual-tool Cortex Agent with compliance-specific instructions.
Application: CoCo scaffolded the entire 605-line Streamlit application including the investigation report generator.
Automation: CoCo created the scheduled daily fraud scan task.
Testing: CoCo validated agent responses against expected outputs and confirmed correct tool routing.
Snowflake Services Used
Dynamic Tables: Five enrichment tables with 5-minute refresh for near-real-time risk scoring and fraud detection.
Cortex Agent: Natural language orchestration across structured data and policy documents.
Cortex Analyst: Governed text-to-SQL generation through the semantic view with verified queries.
Cortex Search: Retrieval-augmented generation over 15 regulatory policy documents.
Semantic Views: Governed data layer with seven tables and ten pre-validated queries.
Scheduled Tasks: Automated daily fraud scanning and alert generation.
Streamlit: Five-view application with dashboard, fraud detection, investigation reports, customer risk profiles, and AI chat.
Limitations
This is a production-oriented prototype, not a production-ready compliance system. It is built on synthetic data in a hackathon environment. A production deployment would require real transaction data with proper access controls, model validation and explainability testing, regulatory change management processes, disaster recovery and audit logging, security review and penetration testing, and integration with existing case management and filing systems such as FinCEN's BSA E-Filing System.

Future Directions
Counterparty network graph analysis to visualize layering chains across account relationships.
MCP integration with Slack to deliver real-time alert notifications to compliance team channels.
Automated SAR XML generation in FinCEN-ready format directly from investigation reports.
ML-based anomaly detection models trained on the labeled fraud data to move beyond rule-based monitoring.
Multi-entity organizational rollup for holding company compliance views across subsidiaries.
Publication as a reusable Cortex Code skill that other teams can install and adapt.
