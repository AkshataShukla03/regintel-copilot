import os
import json
from datetime import datetime

import streamlit as st

st.set_page_config(
    page_title="RegIntel Copilot",
    page_icon="🛡️",
    layout="wide",
    initial_sidebar_state="expanded",
)

_ttl = os.getenv("SNOWFLAKE_CONNECTION_TTL")
conn = st.connection("snowflake", ttl=int(_ttl) if _ttl else None)

# ── Sidebar ──────────────────────────────────────────────────────────────────
with st.sidebar:
    st.title("RegIntel Copilot")
    st.caption("Risk, Fraud & Regulatory Intelligence")
    st.divider()
    view = st.radio(
        "Navigation",
        [
            "Command Center",
            "Fraud Detection",
            "Alerts & Investigation",
            "Customer Risk",
            "Ask Copilot",
        ],
        index=0,
    )
    st.divider()
    st.caption("Powered by Snowflake Cortex")


# ── Helpers ──────────────────────────────────────────────────────────────────
@st.cache_data(ttl=120)
def run_query(sql):
    return conn.query(sql)


def call_agent(question: str) -> str:
    agent_input = json.dumps(
        {
            "messages": [
                {"role": "user", "content": [{"type": "text", "text": question}]}
            ]
        }
    )
    response = conn.query(
        """
        SELECT TRY_PARSE_JSON(
            SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
                'REGINTEL_DB.SEMANTIC.REGINTEL_COPILOT_AGENT',
                :1, TRUE
            )
        ) AS RESPONSE
        """,
        params=[agent_input],
    )
    result = response.iloc[0]["RESPONSE"]
    if isinstance(result, str):
        result = json.loads(result)
    parts = []
    for msg in result.get("choices", [{}])[0].get("messages", []):
        if msg.get("type") == "text":
            parts.append(msg.get("content", ""))
    return "\n".join(parts) if parts else str(result)


def fmt_millions(val):
    return f"${val / 1_000_000:,.2f}M"


def fmt_k(val):
    if val >= 1_000_000:
        return f"${val / 1_000_000:,.1f}M"
    if val >= 1_000:
        return f"${val / 1_000:,.0f}K"
    return f"${val:,.0f}"


SEVERITY_COLORS = {
    "CRITICAL": "🔴",
    "HIGH": "🟠",
    "MEDIUM": "🟡",
    "LOW": "🔵",
}


# ══════════════════════════════════════════════════════════════════════════════
# 1. COMMAND CENTER
# ══════════════════════════════════════════════════════════════════════════════
if view == "Command Center":
    st.header("Command Center")

    metrics = run_query(
        "SELECT * FROM REGINTEL_DB.ENRICHED.REGULATORY_METRICS LIMIT 1"
    )
    kpis = run_query(
        "SELECT TOTAL_FLAGGED_TXNS, TOTAL_FRAUD_EXPOSURE "
        "FROM REGINTEL_DB.ENRICHED.AUTHORITATIVE_KPIS"
    )
    if metrics.empty:
        st.warning("No metrics data available yet.")
        st.stop()
    m = metrics.iloc[0]

    # ── Row 1: Hero KPIs (How much → How many → What needs attention) ────────
    open_ct = int(m["OPEN_ALERTS"])
    escalated_ct = int(m["ESCALATED_ALERTS"])
    active_ct = open_ct + escalated_ct

    # SLA at risk: alerts open > 20 days (approaching 30-day SAR deadline)
    sla_risk = run_query("""
        SELECT COUNT(*) AS CNT
        FROM REGINTEL_DB.RAW.ALERTS
        WHERE STATUS IN ('OPEN', 'UNDER_INVESTIGATION')
          AND DATEDIFF('day', ALERT_DATE, CURRENT_TIMESTAMP()) >= 20
          AND SAR_FILED = FALSE
    """)
    sla_count = int(sla_risk.iloc[0]["CNT"]) if not sla_risk.empty else 0

    if not kpis.empty:
        k = kpis.iloc[0]
        h1, h2, h3, h4 = st.columns(4)
        h1.metric(
            "Modeled Suspicious Exposure",
            fmt_millions(float(k["TOTAL_FRAUD_EXPOSURE"])),
            help="Across 2,477 flagged transactions",
        )
        h2.metric(
            "Flagged Transactions",
            f"{int(k['TOTAL_FLAGGED_TXNS']):,}",
            help="4 fraud typologies detected",
        )
        h3.metric(
            "Active Alerts",
            str(active_ct),
            help=f"{open_ct} open · {escalated_ct} escalated",
        )
        h4.metric(
            "SLA At Risk",
            str(sla_count),
            help="Cases approaching SAR filing deadline (>20 days open)",
        )

    st.divider()

    # ── Row 2: Secondary KPIs ────────────────────────────────────────────────
    s1, s2, s3, s4 = st.columns(4)
    s1.metric("Under Investigation", int(m["UNDER_INVESTIGATION"]))
    s2.metric("SARs Filed", int(m["SARS_FILED"]))
    s3.metric("CTR-Eligible Txns", int(m["CTR_ELIGIBLE_TXNS"]))
    s4.metric(
        "KYC Gaps",
        int(m["EXPIRED_KYC_COUNT"]) + int(m["FAILED_KYC_COUNT"]) + int(m["PENDING_KYC_COUNT"]),
        help=(
            f"{int(m['EXPIRED_KYC_COUNT'])} expired · "
            f"{int(m['FAILED_KYC_COUNT'])} failed · "
            f"{int(m['PENDING_KYC_COUNT'])} pending"
        ),
    )

    st.divider()

    # ── Row 3: Charts side by side ───────────────────────────────────────────
    col_left, col_right = st.columns(2)

    with col_left:
        st.subheader("Customer Risk Distribution")
        st.caption("500 customers · composite risk score")
        risk_data = {
            "Risk Level": ["Critical", "High", "Medium", "Low"],
            "Count": [
                int(m["CRITICAL_RISK_CUSTOMERS"]),
                int(m["HIGH_RISK_CUSTOMERS"]),
                int(m["MEDIUM_RISK_CUSTOMERS"]),
                int(m["LOW_RISK_CUSTOMERS"]),
            ],
        }
        st.bar_chart(risk_data, x="Risk Level", y="Count", color="Risk Level")

    with col_right:
        st.subheader("Fraud Pattern Activity")
        st.caption("Flagged transactions by typology")
        fraud_data = {
            "Pattern": ["Structuring", "Layering", "Round-Trip", "Rapid Movement"],
            "Transactions": [
                int(m["STRUCTURING_TXNS"]),
                int(m["LAYERING_TXNS"]),
                int(m["ROUND_TRIP_TXNS"]),
                int(m["RAPID_MOVEMENT_TXNS"]),
            ],
        }
        st.bar_chart(fraud_data, x="Pattern", y="Transactions", color="Pattern")

    st.divider()

    # ── Row 4: Investigation Queue ───────────────────────────────────────────
    st.subheader("Investigation Queue")
    st.caption("Highest-priority cases requiring analyst action")

    queue = run_query("""
        SELECT
            a.ALERT_ID,
            a.SEVERITY,
            a.ACCOUNT_ID,
            UPPER(COALESCE(t.FRAUD_PATTERN_LABEL, a.ALERT_TYPE)) AS TYPOLOGY,
            COALESCE(SUM(t.AMOUNT), 0) AS EXPOSURE,
            DATEDIFF('hour', a.ALERT_DATE, CURRENT_TIMESTAMP()) AS AGE_HOURS,
            a.STATUS
        FROM REGINTEL_DB.RAW.ALERTS a
        LEFT JOIN REGINTEL_DB.ENRICHED.HIGH_RISK_TRANSACTIONS t
            ON a.ACCOUNT_ID = t.ACCOUNT_ID
        WHERE a.STATUS IN ('OPEN', 'UNDER_INVESTIGATION', 'ESCALATED')
        GROUP BY a.ALERT_ID, a.SEVERITY, a.ACCOUNT_ID, TYPOLOGY, a.ALERT_DATE, a.STATUS
        ORDER BY
            CASE a.SEVERITY
                WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2
                WHEN 'MEDIUM' THEN 3 ELSE 4
            END,
            EXPOSURE DESC
        LIMIT 8
    """)

    if not queue.empty:
        for _, row in queue.iterrows():
            sev = str(row["SEVERITY"])
            icon = SEVERITY_COLORS.get(sev, "⚪")
            age_h = int(row["AGE_HOURS"])
            if age_h >= 24:
                age_str = f"{age_h // 24}d {age_h % 24}h"
            else:
                age_str = f"{age_h}h"

            cols = st.columns([0.5, 1.5, 2, 2, 1.5, 1.5])
            cols[0].markdown(f"**{icon} {sev}**")
            cols[1].markdown(f"`{row['ACCOUNT_ID']}`")
            cols[2].markdown(str(row["TYPOLOGY"]).replace("_", " ").title())
            cols[3].markdown(f"**{fmt_k(float(row['EXPOSURE']))}**")
            cols[4].markdown(f"{age_str} ago")
            cols[5].markdown(f"_{row['STATUS']}_")
    else:
        st.success("No active alerts in queue.")


# ══════════════════════════════════════════════════════════════════════════════
# 2. FRAUD DETECTION
# ══════════════════════════════════════════════════════════════════════════════
elif view == "Fraud Detection":
    st.header("Fraud Pattern Detection")

    tab1, tab2 = st.tabs(["Structuring Detection", "High-Risk Transactions"])

    with tab1:
        st.subheader("Potential Structuring Activity")
        st.caption(
            "Repeated sub-threshold cash deposits within aggregation windows, "
            "evaluated as transaction patterns"
        )
        severity_filter = st.multiselect(
            "Filter by Severity",
            ["CRITICAL", "HIGH", "MEDIUM", "LOW"],
            default=["CRITICAL", "HIGH"],
        )
        if severity_filter:
            placeholders = ", ".join(f"'{s}'" for s in severity_filter)
            structuring = run_query(f"""
                SELECT ACCOUNT_ID, CUSTOMER_ID, WINDOW_START, WINDOW_END,
                       NUM_TRANSACTIONS, TOTAL_AMOUNT, AVG_AMOUNT, SEVERITY,
                       FINDING_DESCRIPTION
                FROM REGINTEL_DB.ENRICHED.STRUCTURING_DETECTION
                WHERE SEVERITY IN ({placeholders})
                ORDER BY TOTAL_AMOUNT DESC
                LIMIT 50
            """)
            st.dataframe(structuring, use_container_width=True)

    with tab2:
        st.subheader("High-Risk Transactions")
        st.caption("Multi-signal risk scoring: transaction + customer + jurisdiction + pattern")
        pattern_filter = st.multiselect(
            "Filter by Fraud Pattern",
            ["STRUCTURING", "LAYERING", "ROUND_TRIP", "RAPID_MOVEMENT"],
            default=["STRUCTURING", "LAYERING", "ROUND_TRIP", "RAPID_MOVEMENT"],
        )
        if pattern_filter:
            placeholders = ", ".join(f"'{p}'" for p in pattern_filter)
            high_risk = run_query(f"""
                SELECT TRANSACTION_ID, ACCOUNT_ID, CUSTOMER_NAME, TRANSACTION_DATE,
                       TRANSACTION_TYPE, AMOUNT, FRAUD_PATTERN_LABEL,
                       COMBINED_RISK_SCORE, PRIMARY_RISK_REASON
                FROM REGINTEL_DB.ENRICHED.HIGH_RISK_TRANSACTIONS
                WHERE FRAUD_PATTERN_LABEL IN ({placeholders})
                ORDER BY COMBINED_RISK_SCORE DESC
                LIMIT 100
            """)
            st.dataframe(high_risk, use_container_width=True)


# ══════════════════════════════════════════════════════════════════════════════
# 3. ALERTS & INVESTIGATION
# ══════════════════════════════════════════════════════════════════════════════
elif view == "Alerts & Investigation":
    st.header("Alerts & Investigation")

    tab_alerts, tab_report = st.tabs(["Alert Queue", "Generate Investigation Report"])

    with tab_alerts:
        status_filter = st.multiselect(
            "Filter by Status",
            [
                "OPEN",
                "UNDER_INVESTIGATION",
                "ESCALATED",
                "CLOSED_CONFIRMED",
                "CLOSED_FALSE_POSITIVE",
            ],
            default=["OPEN", "UNDER_INVESTIGATION", "ESCALATED"],
        )
        if status_filter:
            placeholders = ", ".join(f"'{s}'" for s in status_filter)
            alerts = run_query(f"""
                SELECT a.ALERT_ID, a.ALERT_TYPE, a.SEVERITY, a.STATUS,
                       a.DESCRIPTION, a.ASSIGNED_TO, a.ALERT_DATE,
                       a.SAR_FILED, a.SAR_FILING_DATE,
                       r.RULE_NAME, r.REGULATION
                FROM REGINTEL_DB.RAW.ALERTS a
                LEFT JOIN REGINTEL_DB.RAW.REGULATORY_RULES r ON a.RULE_ID = r.RULE_ID
                WHERE a.STATUS IN ({placeholders})
                ORDER BY a.ALERT_DATE DESC
            """)
            st.dataframe(alerts, use_container_width=True)

    with tab_report:
        st.subheader("Generate Investigation Report")
        st.caption(
            "Select an alert to generate a structured, evidence-backed "
            "investigation report suitable for compliance review."
        )

        alert_list = run_query("""
            SELECT ALERT_ID, ALERT_TYPE, SEVERITY, STATUS,
                   LEFT(DESCRIPTION, 80) AS SUMMARY
            FROM REGINTEL_DB.RAW.ALERTS
            ORDER BY ALERT_DATE DESC
        """)
        alert_options = {
            f"{r['ALERT_ID']}  |  {r['SEVERITY']}  |  {r['SUMMARY']}": r[
                "ALERT_ID"
            ]
            for _, r in alert_list.iterrows()
        }
        selected_label = st.selectbox("Select Alert", list(alert_options.keys()))
        selected_alert = alert_options[selected_label]

        if st.button("Generate Investigation Report", type="primary"):
            with st.spinner("Compiling evidence and generating report..."):
                rpt = run_query(f"""
                    SELECT * FROM REGINTEL_DB.ENRICHED.INVESTIGATION_REPORT_DATA
                    WHERE ALERT_ID = '{selected_alert}'
                """)
                if rpt.empty:
                    st.error("No data found for this alert.")
                    st.stop()
                r = rpt.iloc[0]

                txns = run_query(f"""
                    SELECT TRANSACTION_ID, TRANSACTION_DATE, TRANSACTION_TYPE,
                           AMOUNT, CURRENCY, CHANNEL, FRAUD_PATTERN_LABEL,
                           COMBINED_RISK_SCORE, PRIMARY_RISK_REASON
                    FROM REGINTEL_DB.ENRICHED.HIGH_RISK_TRANSACTIONS
                    WHERE ACCOUNT_ID = '{r["ACCOUNT_ID"]}'
                    ORDER BY TRANSACTION_DATE DESC
                    LIMIT 20
                """)

                reg_context = ""
                try:
                    reg_context = call_agent(
                        f"What regulatory requirements and filing obligations apply to "
                        f"a {r['ALERT_TYPE']} alert with severity {r['SEVERITY']} "
                        f"involving {r.get('ALERT_DESCRIPTION', 'suspicious activity')}? "
                        f"Cite the specific policy sections and thresholds."
                    )
                except Exception:
                    reg_context = (
                        "Regulatory context could not be retrieved. "
                        "Manual review of applicable regulations required."
                    )

                now = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
                case_id = f"CASE-{selected_alert.replace('ALT-', '')}-{datetime.utcnow().strftime('%Y%m%d')}"

                st.divider()
                st.subheader(f"Investigation Report — {case_id}")

                hdr1, hdr2, hdr3 = st.columns(3)
                hdr1.metric("Case ID", case_id)
                hdr2.metric("Alert Severity", str(r["SEVERITY"]))
                hdr3.metric("Alert Status", str(r["STATUS"]))

                st.divider()

                st.markdown("### 1. Subject Information")
                si1, si2 = st.columns(2)
                with si1:
                    st.markdown(f"""
**Customer:** {r['CUSTOMER_NAME']}
**Customer ID:** {r['CUSTOMER_ID']}
**Customer Type:** {r['CUSTOMER_TYPE']}
**Nationality:** {r['NATIONALITY']}
**Country of Residence:** {r['COUNTRY_OF_RESIDENCE']}
**Occupation:** {r['OCCUPATION']}
""")
                with si2:
                    st.markdown(f"""
**Account ID:** {r['ACCOUNT_ID']}
**Account Type:** {r['ACCOUNT_TYPE']}
**Account Status:** {r['ACCOUNT_STATUS']}
**Current Balance:** ${float(r['CURRENT_BALANCE']):,.2f} {r['CURRENCY']}
**KYC Status:** {r['KYC_STATUS']}
**Onboarding Date:** {r['ONBOARDING_DATE']}
""")

                st.markdown("### 2. Risk Assessment")
                ra1, ra2, ra3, ra4 = st.columns(4)
                ra1.metric("Composite Risk Score", f"{int(r['COMPOSITE_RISK_SCORE'])}/100")
                ra2.metric("Customer Risk Rating", str(r["CUSTOMER_RISK_RATING"]))
                ra3.metric("PEP Status", "Yes" if r["PEP_FLAG"] else "No")
                ra4.metric("Sanctions Flag", "Yes" if r["SANCTIONS_FLAG"] else "No")

                st.markdown(f"""
- **Flagged Transactions (90d):** {int(r['FLAGGED_TRANSACTION_COUNT'])}
- **Total Transactions (90d):** {int(r['TOTAL_TRANSACTIONS_90D'])}
- **Transaction Volume (90d):** ${float(r['TOTAL_TRANSACTION_VOLUME_90D']):,.2f}
- **Active Alerts:** {int(r['ACTIVE_ALERTS'])}
- **Adverse Media:** {"Yes" if r["ADVERSE_MEDIA_FLAG"] else "No"}
""")

                st.markdown("### 3. Alert Details & Fraud Typology")
                st.markdown(f"""
- **Alert ID:** {r['ALERT_ID']}
- **Alert Type:** {r['ALERT_TYPE']}
- **Alert Date:** {r['ALERT_DATE']}
- **Description:** {r['ALERT_DESCRIPTION']}
- **Assigned To:** {r['ASSIGNED_TO']}
- **Triggered Rule:** {r['RULE_NAME']} ({r['REGULATION']})
- **Rule Description:** {r['RULE_DESCRIPTION']}
- **Threshold:** ${float(r['THRESHOLD_VALUE']):,.2f} {r['THRESHOLD_CURRENCY']}
- **Filing Required:** {r['FILING_REQUIRED']}
""")

                st.markdown("### 4. Supporting Transaction Evidence")
                if not txns.empty:
                    st.dataframe(txns, use_container_width=True)
                    st.markdown(
                        f"*{len(txns)} transactions displayed. "
                        f"Total flagged amount: ${txns['AMOUNT'].sum():,.2f}*"
                    )
                else:
                    st.info("No high-risk transactions found for this account.")

                st.markdown("### 5. Applicable Regulatory Requirements")
                st.markdown(reg_context)

                st.markdown("### 6. Investigation Findings")
                sar_status = (
                    "SAR filed" if r["SAR_FILED"] else "SAR not yet filed"
                )
                st.markdown(f"""
- **Current Status:** {r['STATUS']}
- **SAR Status:** {sar_status}
- **Resolution Notes:** {r['RESOLUTION_NOTES'] or 'Pending investigation'}
""")

                st.markdown("### 7. Recommended Next Steps")
                steps = []
                if r["STATUS"] == "OPEN":
                    steps.append(
                        "Assign to senior investigator for detailed review"
                    )
                if not r["SAR_FILED"] and r["FILING_REQUIRED"] == "SAR":
                    steps.append(
                        "Evaluate for SAR filing (30 calendar days from detection; "
                        "up to 60 days if no suspect identified)"
                    )
                if r["KYC_STATUS"] in ("EXPIRED", "FAILED"):
                    steps.append(
                        "Initiate KYC refresh before continuing relationship"
                    )
                if r["PEP_FLAG"]:
                    steps.append(
                        "Obtain senior management approval per PEP EDD policy"
                    )
                if r["SANCTIONS_FLAG"]:
                    steps.append(
                        "Escalate to sanctions compliance team immediately"
                    )
                steps.append("Document all findings in case management system")
                steps.append("Schedule follow-up review within 14 days")
                for i, step in enumerate(steps, 1):
                    st.markdown(f"{i}. {step}")

                st.divider()
                st.caption(
                    f"Report generated: {now}  |  Case ID: {case_id}  |  "
                    f"Source: REGINTEL_DB  |  "
                    f"**DISCLAIMER:** This report is generated by an AI system "
                    f"and requires review by a qualified compliance analyst "
                    f"before any regulatory action is taken. All findings must "
                    f"be independently verified against source systems."
                )


# ══════════════════════════════════════════════════════════════════════════════
# 4. CUSTOMER RISK
# ══════════════════════════════════════════════════════════════════════════════
elif view == "Customer Risk":
    st.header("Customer Risk Profiles")
    st.caption("Composite risk scoring across KYC, PEP, sanctions, and transaction behavior")

    risk_filter = st.multiselect(
        "Filter by Risk Rating",
        ["CRITICAL", "HIGH", "MEDIUM", "LOW"],
        default=["CRITICAL", "HIGH"],
    )
    min_score = st.slider("Minimum Composite Risk Score", 0, 100, 30)

    if risk_filter:
        placeholders = ", ".join(f"'{r}'" for r in risk_filter)
        customers = run_query(f"""
            SELECT CUSTOMER_ID, FULL_NAME, CUSTOMER_TYPE, RISK_RATING,
                   COMPOSITE_RISK_SCORE, KYC_STATUS, PEP_FLAG, SANCTIONS_FLAG,
                   ADVERSE_MEDIA_FLAG, NUM_ACCOUNTS, TOTAL_BALANCE,
                   TOTAL_TRANSACTIONS_90D, FLAGGED_TRANSACTION_COUNT, ACTIVE_ALERTS
            FROM REGINTEL_DB.ENRICHED.CUSTOMER_RISK_PROFILE
            WHERE RISK_RATING IN ({placeholders})
              AND COMPOSITE_RISK_SCORE >= {int(min_score)}
            ORDER BY COMPOSITE_RISK_SCORE DESC
            LIMIT 100
        """)
        st.dataframe(customers, use_container_width=True)

        st.divider()
        st.subheader("KYC Renewal Required")
        st.caption("Customers with expired, failed, or pending KYC verification")
        kyc_expired = run_query("""
            SELECT CUSTOMER_ID, FULL_NAME, KYC_STATUS, RISK_RATING,
                   LAST_REVIEW_DATE, COMPOSITE_RISK_SCORE
            FROM REGINTEL_DB.ENRICHED.CUSTOMER_RISK_PROFILE
            WHERE KYC_STATUS IN ('EXPIRED', 'FAILED', 'PENDING')
            ORDER BY COMPOSITE_RISK_SCORE DESC
            LIMIT 50
        """)
        st.dataframe(kyc_expired, use_container_width=True)


# ══════════════════════════════════════════════════════════════════════════════
# 5. ASK COPILOT
# ══════════════════════════════════════════════════════════════════════════════
elif view == "Ask Copilot":
    st.header("Ask the RegIntel Copilot")
    st.caption(
        "Natural language questions grounded in transaction data and regulatory policy."
    )

    suggested = st.pills(
        "Suggested questions",
        [
            "Why is account ACCT-0000001 high risk?",
            "Which accounts show structuring patterns needing SAR review?",
            "Does this structuring pattern meet our SAR criteria? Cite the policy.",
            "What is our false positive rate for AML alerts?",
            "What are the Basel III liquidity coverage ratio requirements?",
        ],
        selection_mode="single",
    )

    if "messages" not in st.session_state:
        st.session_state.messages = []

    for msg in st.session_state.messages:
        with st.chat_message(msg["role"]):
            st.markdown(msg["content"])

    prompt = suggested or st.chat_input("Ask about risk, fraud, or compliance...")

    if prompt:
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)

        with st.chat_message("assistant"):
            with st.spinner("Analyzing..."):
                try:
                    answer = call_agent(prompt)
                    st.markdown(answer)
                except Exception as e:
                    answer = f"Error calling agent: {e}"
                    st.error(answer)

        st.session_state.messages.append({"role": "assistant", "content": answer})
