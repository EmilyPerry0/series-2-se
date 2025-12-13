import streamlit as st
from pathlib import Path
import pandas as pd

from data_loader import load_clone_data
from data_stats import enrich_clone_classes, compute_file_stats, build_clone_class_df
from code_utils import read_code_snippet


ROOT_DIR = Path(__file__).parent.parent.parent
DATA_DIR = ROOT_DIR / "data"
PROJECT_ROOT = ROOT_DIR  # where src/ lives

st.title("Clone-Class Explorer")

# --- Get dataset path from session_state ---
if "json_path" not in st.session_state:
    st.warning("No dataset selected. Go to the **Home** page and pick a JSON file.")
    st.stop()

json_path = Path(st.session_state["json_path"])

project, files, clone_classes = load_clone_data(json_path)
clone_classes = enrich_clone_classes(clone_classes)
file_df = compute_file_stats(files, clone_classes)
class_df = build_clone_class_df(clone_classes)

st.caption(f"Project: **{project}** | JSON: `{json_path.name}`")

# =========================================================
# ----------------- CLONE-CLASS EXPLORER ------------------
# =========================================================

st.markdown("---")
st.header("Clone-class explorer")

# ---------- Sidebar / top filters for clone classes ----------
st.sidebar.header("Filters (clone classes)")

# Type filter: based on what exists in data
available_types = sorted(class_df["type"].dropna().unique().tolist())
selected_types = st.sidebar.multiselect(
    "Clone types to include",
    options=available_types,
    default=available_types,
)

min_members = st.sidebar.number_input(
    "Min #members per clone class",
    min_value=1,
    value=1,
    step=1,
)

min_total_loc_class = st.sidebar.number_input(
    "Min total LOC per clone class",
    min_value=0,
    value=0,
    step=5,
)

# Optional: filter by file involvement
file_filter_options = (
    ["<any file>"]
    + [f"{row.fileId}: {row.shortPath}" for _, row in file_df.sort_values("shortPath").iterrows()]
)
file_filter_choice = st.sidebar.selectbox(
    "Show classes that involve file",
    options=file_filter_options,
    index=0,
)
if file_filter_choice == "<any file>":
    file_filter_id = None
else:
    file_filter_id = int(file_filter_choice.split(":")[0])  # get fileId before colon

# ---------- Apply class filters ----------
filtered_classes_df = class_df.copy()

if selected_types:
    filtered_classes_df = filtered_classes_df[filtered_classes_df["type"].isin(selected_types)]

filtered_classes_df = filtered_classes_df[
    (filtered_classes_df["numMembers"] >= min_members)
    & (filtered_classes_df["totalLOC"] >= min_total_loc_class)
]

# If file filter is active: we need to check members of classes
if file_filter_id is not None:
    valid_ids = set()
    for cc in clone_classes:
        if any(m["fileId"] == file_filter_id for m in cc["members"]):
            valid_ids.add(cc["id"])
    filtered_classes_df = filtered_classes_df[filtered_classes_df["id"].isin(valid_ids)]

if filtered_classes_df.empty:
    st.warning("No clone classes match the current class filters.")
    st.stop()

# ---------- Class list (table) ----------
st.subheader("Clone classes")

# We’ll show top K by totalLOC
if len(filtered_classes_df) == 0:
    st.warning("No clone classes match the current filters.")
    st.stop()

max_k = max(1, min(100, len(filtered_classes_df)))

top_k = st.slider(
    "Show top K clone classes (by total LOC)",
    min_value=1,
    max_value=max_k,
    value=max_k,
)


filtered_classes_df = filtered_classes_df.sort_values(
    by="totalLOC", ascending=False
).head(top_k)

st.dataframe(
    filtered_classes_df.rename(
        columns={
            "id": "Class ID",
            "type": "Type",
            "numMembers": "#Members",
            "numFilesInvolved": "#Files",
            "totalLOC": "Total LOC",
            "maxMemberLOC": "Max member LOC",
        }
    ),
    use_container_width=True,
    hide_index=True,
)

# ---------- Select a specific clone class ----------
selected_id = st.selectbox(
    "Select a clone class to inspect",
    options=filtered_classes_df["id"].tolist(),
    format_func=lambda cid: f"Class {cid}",
)

# Find the corresponding object in the original list (for members)
selected_class = next(cc for cc in clone_classes if cc["id"] == selected_id)

st.markdown(f"### Details for clone class `{selected_id}` (type: `{selected_class.get('type', 'Unknown')}`)")

# Summary KPIs for this class
cc_col1, cc_col2, cc_col3, cc_col4 = st.columns(4)
cc_col1.metric("Members", selected_class["numMembers"])
cc_col2.metric("Files involved", selected_class["numFilesInvolved"])
cc_col3.metric("Total LOC", selected_class["totalLOC"])
cc_col4.metric("Max member LOC", selected_class["maxMemberLOC"])

# ---------- Members table ----------
members_rows = []
for m in selected_class["members"]:
    fid = m["fileId"]
    path = files.get(fid, f"<unknown file {fid}>")
    members_rows.append(
        {
            "fileId": fid,
            "filePath": path,
            "className": m.get("className", ""),
            "methodName": m.get("methodName", ""),
            "beginLine": m["beginLine"],
            "endLine": m["endLine"],
            "LOC": m["loc"],
        }
    )

members_df = pd.DataFrame(members_rows)

st.subheader("Members of this clone class")

st.dataframe(
    members_df.rename(
        columns={
            "filePath": "File",
            "className": "Class",
            "methodName": "Method",
            "beginLine": "Start line",
            "endLine": "End line",
        }
    ),
    use_container_width=True,
    hide_index=True,
)

# ---------- Code snippets ----------
st.subheader("Code snippets")

view_mode = st.radio(
    "Display snippets",
    options=["Stacked", "Side-by-side (up to 3)"],
    horizontal=True,
)

if view_mode == "Stacked":
    for idx, row in members_df.iterrows():
        st.markdown(
            f"**Member {idx+1}** – `{Path(row['filePath']).name}` "
            f"({row['className']}.{row['methodName']}, "
            f"lines {row['beginLine']}-{row['endLine']})"
        )

        snippet = read_code_snippet(
            ROOT_DIR,
            row["filePath"],
            int(row["beginLine"]),
            int(row["endLine"]),
        )
        st.code(snippet, language="java")
        st.markdown("---")
else:
    # side-by-side: we show up to the first 3 members (for layout sanity)
    max_side = min(3, len(members_df))
    cols = st.columns(max_side)

    for i in range(max_side):
        row = members_df.iloc[i]
        with cols[i]:
            st.markdown(
                f"**Member {i+1}**  \n"
                f"`{Path(row['filePath']).name}`  \n"
                f"{row['className']}.{row['methodName']}  \n"
                f"Lines {row['beginLine']}-{row['endLine']}"
            )
            snippet = read_code_snippet(
                ROOT_DIR,
                row["filePath"],
                int(row["beginLine"]),
                int(row["endLine"]),
            )
            st.code(snippet, language="java")