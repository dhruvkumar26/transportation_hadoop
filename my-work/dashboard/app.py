"""
NYC Yellow Taxi – Analytics Dashboard
BITS ZG522 · Big Data Systems · Assignment 1

Consumes the CSV results exported by 03_export.sql (Hive) after they've been
pulled from HDFS to local FS via:
    hdfs dfs -getmerge /results/hive/q1_hotspots         data/q1_hotspots.csv
    hdfs dfs -getmerge /results/hive/q2_revenue_by_borough data/q2_revenue_by_borough.csv
    hdfs dfs -getmerge /results/hive/q3_congestion       data/q3_congestion.csv
    hdfs dfs -getmerge /results/hive/q4_airports         data/q4_airports.csv
    hdfs dfs -getmerge /results/hive/q5_payment_share    data/q5_payment_share.csv

Run:
    streamlit run app.py
"""
import os
import pandas as pd
import plotly.express as px
import streamlit as st

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")

st.set_page_config(
    page_title="NYC Yellow Taxi Analytics",
    page_icon="🚕",
    layout="wide",
)

st.title("🚕 NYC Yellow Taxi – Big Data Analytics")
st.caption("BITS ZG522 · Big Data Systems · Assignment 1 · 3 months (Jan–Mar 2026) · ~11M trips")

# ---------------------------------------------------------------------------
# Data loading (Hive exports have no header row)
# ---------------------------------------------------------------------------
def load(csv_name: str, cols: list[str]) -> pd.DataFrame:
    path = os.path.join(DATA_DIR, csv_name)
    if not os.path.exists(path):
        st.error(f"Missing file: {path}\nRun the getmerge commands from the docstring.")
        st.stop()
    return pd.read_csv(path, header=None, names=cols)


q1 = load("q1_hotspots.csv",
          ["pickup_hour", "pu_borough", "pu_zone", "trips"])
q2 = load("q2_revenue_by_borough.csv",
          ["pu_borough", "payment_method", "trips", "revenue_usd",
           "avg_fare", "avg_tip_pct"])
q3 = load("q3_congestion.csv",
          ["pickup_hour", "pu_loc_id", "do_loc_id", "trips",
           "avg_duration_min", "avg_distance_mi", "min_per_mile"])
q4 = load("q4_airports.csv",
          ["airport", "destination_zone", "destination_borough", "trips",
           "avg_distance_mi", "avg_fare", "avg_tip_pct", "avg_duration_min"])
q5 = load("q5_payment_share.csv",
          ["pu_borough", "pct_card", "pct_cash", "pct_other", "trips"])

# ---------------------------------------------------------------------------
# KPI row
# ---------------------------------------------------------------------------
total_trips = int(q2["trips"].sum())
total_rev   = q2["revenue_usd"].sum()
avg_fare    = q2["avg_fare"].mean()
avg_tip     = q2["avg_tip_pct"].mean()

c1, c2, c3, c4 = st.columns(4)
c1.metric("Total Trips",   f"{total_trips:,}")
c2.metric("Revenue (USD)", f"${total_rev/1e6:,.2f} M")
c3.metric("Avg Fare",      f"${avg_fare:.2f}")
c4.metric("Avg Tip %",     f"{avg_tip:.1f}%")

st.divider()

# ---------------------------------------------------------------------------
# Q1 – Demand hotspots
# ---------------------------------------------------------------------------
st.subheader("Q1 · Demand hotspots by hour")

col_a, col_b = st.columns([1, 3])
with col_a:
    hour = st.slider("Pickup hour", 0, 23, 18)
with col_b:
    top10 = (q1[q1["pickup_hour"] == hour]
             .sort_values("trips", ascending=False)
             .head(10))
    fig = px.bar(top10, x="trips", y="pu_zone", orientation="h",
                 color="pu_borough", title=f"Top 10 pickup zones at {hour:02d}:00")
    fig.update_layout(yaxis={'categoryorder': 'total ascending'})
    st.plotly_chart(fig, use_container_width=True)

# ---------------------------------------------------------------------------
# Q2 – Revenue by borough & payment
# ---------------------------------------------------------------------------
st.subheader("Q2 · Revenue by borough and payment method")
fig2 = px.bar(q2, x="pu_borough", y="revenue_usd", color="payment_method",
              barmode="group", title="Revenue (USD) by borough × payment")
st.plotly_chart(fig2, use_container_width=True)

# ---------------------------------------------------------------------------
# Q3 – Congestion signal
# ---------------------------------------------------------------------------
st.subheader("Q3 · Congestion – minutes per mile by hour")
q3_by_hour = q3.groupby("pickup_hour", as_index=False)["min_per_mile"].mean()
fig3 = px.line(q3_by_hour, x="pickup_hour", y="min_per_mile", markers=True,
               title="Avg minutes per mile across all busy PU→DO pairs")
fig3.update_layout(xaxis=dict(dtick=1))
st.plotly_chart(fig3, use_container_width=True)

st.caption("Top 15 slowest PU→DO pairs (min per mile)")
st.dataframe(q3.sort_values("min_per_mile", ascending=False).head(15), use_container_width=True)

# ---------------------------------------------------------------------------
# Q4 – Airport profile
# ---------------------------------------------------------------------------
st.subheader("Q4 · Airport trip profile")

selected_ap = st.radio("Airport", ["JFK", "LGA", "EWR"], horizontal=True)
ap = q4[q4["airport"] == selected_ap].sort_values("trips", ascending=False).head(15)

col1, col2 = st.columns(2)
with col1:
    fig4a = px.bar(ap.head(10), x="trips", y="destination_zone",
                   orientation="h", color="destination_borough",
                   title=f"Top destinations from {selected_ap}")
    fig4a.update_layout(yaxis={'categoryorder': 'total ascending'})
    st.plotly_chart(fig4a, use_container_width=True)
with col2:
    st.dataframe(ap, use_container_width=True)

# ---------------------------------------------------------------------------
# Q5 – Payment share
# ---------------------------------------------------------------------------
st.subheader("Q5 · Card vs cash share by borough")
q5_long = q5.melt(id_vars=["pu_borough", "trips"],
                  value_vars=["pct_card", "pct_cash", "pct_other"],
                  var_name="method", value_name="pct")
q5_long["method"] = q5_long["method"].map({"pct_card":"Card","pct_cash":"Cash","pct_other":"Other"})
fig5 = px.bar(q5_long, x="pu_borough", y="pct", color="method",
              title="Payment method share (%)", text="pct")
fig5.update_traces(texttemplate="%{text:.1f}%")
st.plotly_chart(fig5, use_container_width=True)

st.divider()
st.caption("Pipeline: HDFS → Pig (ETL) → native MR (trips-per-zone) → Hive (analytics) → HBase (zone lookup) → Streamlit")
