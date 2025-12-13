import streamlit as st
from pathlib import Path
import pandas as pd
import plotly.express as px
from data_loader import load_clone_data
from data_stats import enrich_clone_classes, compute_file_stats, build_clone_class_df


# ---------- PATHS ----------
ROOT_DIR = Path(__file__).parent.parent.parent
DATA_DIR = ROOT_DIR / "data"

st.title("System-level Clone Overview")

if "json_path" not in st.session_state:
    st.warning("No dataset selected. Go to the **Home** page and pick a JSON file.")
    st.stop()

json_path = Path(st.session_state["json_path"])

# ---------- DATA LOADING ----------
project, files, clone_classes = load_clone_data(json_path)
clone_classes = enrich_clone_classes(clone_classes)
file_df = compute_file_stats(files, clone_classes)
class_df = build_clone_class_df(clone_classes)


# ---------- STREAMLIT CONFIG ----------
st.set_page_config(page_title="Clone Visualisation", layout="wide")
st.caption(f"Project: **{project}** | JSON: `{json_path.name}`")




total_files = len(file_df)
total_clone_classes = len(class_df)
total_cloned_loc = int(file_df["totalClonedLOC"].sum())

col1, col2, col3 = st.columns(3)
col1.metric("Files with clones", total_files)
col2.metric("Clone classes (total)", total_clone_classes)
col3.metric("Total cloned LOC (sum over files)", total_cloned_loc)

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


filtered_files = file_df.copy()

if search_text:
    s = search_text.lower()
    filtered_files = filtered_files[filtered_files["shortPath"].str.lower().str.contains(s)]

filtered_files = filtered_files[
    (filtered_files["totalClonedLOC"] >= min_loc)
    & (filtered_files["numCloneClasses"] >= min_classes)
]

if filtered_files.empty:
    st.warning("No files match the current file filters.")
else:
    st.subheader("System-level overview: files ordered by cloned LOC")

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

    st.plotly_chart(fig, use_container_width=True)

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
        use_container_width=True,
        hide_index=True,
    )