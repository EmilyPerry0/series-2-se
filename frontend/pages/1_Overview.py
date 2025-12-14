# frontend/pages/1_Overview.py
import streamlit as st
from pathlib import Path
import plotly.express as px

from data_loader import load_clone_data
from data_stats import enrich_clone_classes, compute_file_stats, build_treemap_nodes, build_file_coupling_matrix
from utils import choose_dataset



st.title("System-level Clone Overview")

# ---------- Dataset selection ----------
st.sidebar.header("Dataset")
json_path = choose_dataset()

project, files, clone_classes = load_clone_data(json_path)
clone_classes = enrich_clone_classes(clone_classes)

# type filter for file-level stats
available_types = sorted({cc.get("type", "Unknown") for cc in clone_classes})
selected_types = st.sidebar.multiselect(
    "Include clone types (for file overview)",
    options=available_types,
    default=available_types,
)

filtered_cc_for_files = [
    cc for cc in clone_classes if cc.get("type", "Unknown") in selected_types
]

file_df = compute_file_stats(files, filtered_cc_for_files)

st.caption(f"Project: **{project}** | JSON: `{json_path.name}`")

# ---------- Top metrics ----------
total_files = len(file_df)
total_clone_classes = len(filtered_cc_for_files)
total_cloned_loc = int(file_df["totalClonedLOC"].sum())

col1, col2, col3 = st.columns(3)
col1.metric("Files with clones", total_files)
col2.metric("Clone classes (selected types)", total_clone_classes)
col3.metric("Total cloned LOC (sum over files)", total_cloned_loc)

# ---------- File filters ----------
st.sidebar.header("Filters (files overview)")

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

if file_df.empty:
    st.warning("No files contain clones of the selected types.")
    st.stop()

top_n = st.sidebar.slider(
    "Show top N files (by cloned LOC)",
    min_value=0,
    max_value=min(50, len(file_df)),
    value=min(10, len(file_df)),
)

# ---------- Apply filters ----------
filtered_files = file_df.copy()

if search_text:
    s = search_text.lower()
    filtered_files = filtered_files[
        filtered_files["shortPath"].str.lower().str.contains(s)
    ]

filtered_files = filtered_files[
    (filtered_files["totalClonedLOC"] >= min_loc)
    & (filtered_files["numCloneClasses"] >= min_classes)
]

if filtered_files.empty:
    st.warning("No files match the current file filters.")
    st.stop()

st.caption(
    f"Showing {len(filtered_files)} / {len(file_df)} files (after filters)."
)

# ---------- Bar chart ----------
st.subheader("Files ordered by cloned LOC")

filtered_sorted = filtered_files.sort_values(
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

st.plotly_chart(fig)

# ---------- Table ----------
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

# ---------- Treemap ----------
st.markdown("---")
st.subheader("Project structure treemap (cloned LOC per file)")

treemap_df = build_treemap_nodes(file_df, project)

fig_treemap = px.treemap(
    treemap_df,
    names="label",
    parents="parent",
    values="value",
)

st.plotly_chart(fig_treemap)

# ---------- Heatmap ----------
st.markdown("---")
st.subheader("File–file clone coupling (heatmap)")

coupling_df = build_file_coupling_matrix(filtered_cc_for_files, file_df)

if not coupling_df.empty and (coupling_df.values != 0).any():
    fig_coupling = px.imshow(
        coupling_df,
        labels=dict(x="File", y="File", color="Cloned LOC shared"),
    )
    st.plotly_chart(fig_coupling, use_container_width=True)
else:
    st.info("No shared clones between files for the current filters.")
