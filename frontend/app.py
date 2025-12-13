import streamlit as st
from pathlib import Path
import pandas as pd
import plotly.express as px

from data_loader import load_clone_data
from data_stats import enrich_clone_classes, compute_file_stats


# ---------- DATA LOADING ----------
DATA_DIR = Path(__file__).parent.parent / "data"
DEFAULT_JSON = DATA_DIR / "clone_report.json"  # TODO: change to correct default file

project, files, clone_classes = load_clone_data(DEFAULT_JSON)
clone_classes = enrich_clone_classes(clone_classes)
file_df = compute_file_stats(files, clone_classes)


# ---------- STREAMLIT UI ----------
st.set_page_config(page_title="Clone Overview", layout="wide")

st.title("System-level Clone Overview")
st.caption(f"Project: **{project}** | JSON: `{DEFAULT_JSON.name}`")


# --- High-level KPIs at the top ---
total_files = len(file_df)
total_clone_classes = len({cc["id"] for cc in clone_classes})
total_cloned_loc = int(file_df["totalClonedLOC"].sum())

col1, col2, col3 = st.columns(3)
col1.metric("Files with clones", total_files)
col2.metric("Clone classes (total)", total_clone_classes)
col3.metric("Total cloned LOC (sum over files)", total_cloned_loc)


# --- Sidebar filters ---
st.sidebar.header("Filters")

search_text = st.sidebar.text_input(
    "Filter files by name/path",
    value="",
    help="Case-insensitive substring match in short path",
)

min_loc = st.sidebar.number_input(
    "Min cloned LOC per file",
    min_value=0,
    value=0,
    step=10,
)

min_classes = st.sidebar.number_input(
    "Min #clone classes per file",
    min_value=0,
    value=0,
    step=1,
)

# --- Top-N slider ---
max_files = len(file_df)

if max_files <= 1:
    st.sidebar.info("Only one file contains clones — showing all of them.")
    top_n = max_files   # 0 or 1
else:
    top_n = st.sidebar.slider(
        "Show top N files (by cloned LOC)",
        min_value=1,
        max_value=min(50, max_files),
        value=min(10, max_files),
    )



# --- Apply filters ---
filtered = file_df.copy()

if search_text:
    s = search_text.lower()
    filtered = filtered[filtered["shortPath"].str.lower().str.contains(s)]

filtered = filtered[
    (filtered["totalClonedLOC"] >= min_loc)
    & (filtered["numCloneClasses"] >= min_classes)
]

# Guard: maybe all are filtered out
if filtered.empty:
    st.warning("No files match the current filters.")
    st.stop()



# --- Visualization 1A: Bar chart of files by cloned LOC ---
st.subheader("Files ordered by cloned LOC")

# Sort & take top N
filtered_sorted = filtered.sort_values(
    by="totalClonedLOC", ascending=False
).head(top_n)

fig = px.bar(
    filtered_sorted,
    x="shortPath",
    y="totalClonedLOC",
    hover_data=["path", "numCloneClasses"],
    labels={
        "shortPath": "File",
        "totalClonedLOC": "Cloned LOC",
        "numCloneClasses": "#Clone classes",
    },
)

fig.update_layout(
    xaxis_tickangle=-45,
    margin=dict(l=10, r=10, t=30, b=100),
)

st.plotly_chart(fig, use_container_width=True)



# --- Visualization 1B: Detailed table below ---
st.subheader("File-level clone statistics")

st.dataframe(
    filtered_sorted[
        ["fileId", "shortPath", "totalClonedLOC", "numCloneClasses", "package"]
    ].rename(
        columns={
            "shortPath": "File",
            "totalClonedLOC": "Cloned LOC",
            "numCloneClasses": "#Clone classes",
        }
    ),
    width='stretch',
    hide_index=True,
)
