import streamlit as st
from pathlib import Path
import pandas as pd
import plotly.express as px
from data_loader import load_clone_data
from data_stats import enrich_clone_classes, compute_file_stats, build_clone_class_df, build_class_file_distribution
from utils import read_code_snippet, choose_dataset


ROOT_DIR = Path(__file__).parent.parent.parent
PROJECT_ROOT = ROOT_DIR  # where src/ lives

st.title("Clone-Class Explorer")

# ---------- Dataset selection ----------
st.sidebar.header("Dataset")
json_path = choose_dataset()

project, files, clone_classes = load_clone_data(json_path)
clone_classes = enrich_clone_classes(clone_classes)
file_df = compute_file_stats(files, clone_classes)
class_df = build_clone_class_df(clone_classes)

st.caption(f"Project: **{project}** | JSON: `{json_path.name}`")

# ---------- Clone-class filters ----------
st.sidebar.header("Filters (clone classes)")

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

# quick presets
preset = st.sidebar.radio(
    "Quick size filter",
    options=["None", "Ignore clones < 5 LOC", "Only big clones (>= 20 LOC)"],
)
if preset == "Ignore clones < 5 LOC":
    min_total_loc_class = max(min_total_loc_class, 5)
elif preset == "Only big clones (>= 20 LOC)":
    min_total_loc_class = max(min_total_loc_class, 20)

# filter by file involvement
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

# ---------- Apply filters ----------
filtered_classes_df = class_df.copy()

if selected_types:
    filtered_classes_df = filtered_classes_df[filtered_classes_df["type"].isin(selected_types)]

filtered_classes_df = filtered_classes_df[
    (filtered_classes_df["numMembers"] >= min_members)
    & (filtered_classes_df["totalLOC"] >= min_total_loc_class)
]

if file_filter_id is not None:
    valid_ids = set()
    for cc in clone_classes:
        if any(m["fileId"] == file_filter_id for m in cc["members"]):
            valid_ids.add(cc["id"])
    filtered_classes_df = filtered_classes_df[filtered_classes_df["id"].isin(valid_ids)]

if filtered_classes_df.empty:
    st.warning("No clone classes match the current class filters.")
    st.stop()

st.caption(
    f"Showing {len(filtered_classes_df)} / {len(class_df)} clone classes (after filters)."
)

# ---------- Class table ----------
st.subheader("Clone classes")

top_k = st.slider(
    "Show top K clone classes (by total LOC)",
    min_value=1,
    max_value=min(100, len(filtered_classes_df)),
    value=min(20, len(filtered_classes_df)),
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
    width='stretch',
    hide_index=True,
)

# ---------- Clone Class Scatter Plot ----------
st.markdown("---")
st.subheader("Clone Classes: Size vs. Duplication")

scatter_data = filtered_classes_df.copy()

fig_scatter = px.scatter(
    scatter_data,
    x='numMembers',
    y='totalLOC',
    size='numFilesInvolved',
    color='type',
    hover_data={
        'id': True,
        'numMembers': True,
        'totalLOC': True,
        'numFilesInvolved': True,
        'maxMemberLOC': True,
        'type': True
    },
    labels={
        'numMembers': 'Number of Clone Members',
        'totalLOC': 'Total Cloned LOC',
        'numFilesInvolved': 'Files Involved',
        'type': 'Clone Type'
    },
    color_discrete_map={
        'Type1': '#e74c3c',
        'Type2': '#3498db',
        'Type3': '#2ecc71',
        'Unknown': '#95a5a6'
    },
    title="Clone Classes: Duplication vs. Size"
)

# Add quadrant lines (median values)
median_members = scatter_data['numMembers'].median()
median_loc = scatter_data['totalLOC'].median()

fig_scatter.add_hline(
    y=median_loc,
    line_dash="dash",
    line_color="gray",
    opacity=0.5,
    annotation_text="Median LOC",
    annotation_position="right"
)

fig_scatter.add_vline(
    x=median_members,
    line_dash="dash",
    line_color="gray",
    opacity=0.5,
    annotation_text="Median Members",
    annotation_position="top"
)

fig_scatter.update_layout(
    height=500,
    xaxis_title="Number of Members (Duplication Level)",
    yaxis_title="Total LOC (Clone Size)",
    showlegend=True
)

# Make dots clickable (selection)
fig_scatter.update_traces(
    marker=dict(
        line=dict(width=1, color='white'),
        opacity=0.8
    )
)

st.plotly_chart(fig_scatter, use_container_width=True)

# Interpretation guide
with st.expander("How to interpret this scatter plot"):
    st.markdown("""
    **Quadrants (divided by median lines):**
    
    - **Top-Right (High duplication × Large size):**  **CRITICAL** — High refactoring priority
      - Many copies of large code fragments
      - Example: Common utility functions copy-pasted everywhere
    
    - **Top-Left (Low duplication × Large size):**  **MODERATE** — Review for potential extraction
      - Few copies, but each is large
      - Might be domain-specific implementations
    
    - **Bottom-Right (High duplication × Small size):**  **MODERATE** — Potential boilerplate
      - Many copies of small fragments
      - Could be getters/setters, constants, or idioms
    
    - **Bottom-Left (Low duplication × Small size):**  **LOW PRIORITY**
      - Few copies of small code
      - Least maintenance burden
    
    **Bubble size** = Number of files involved (larger = more scattered)
    
    **Click a point** below to jump to that clone class!
    """)

# Interactive selection from scatter plot
scatter_cols = st.columns([3, 1])
with scatter_cols[0]:
    selected_scatter_id = st.selectbox(
        "Or click a clone class from the scatter plot data:",
        options=scatter_data.sort_values('totalLOC', ascending=False)['id'].tolist(),
        format_func=lambda cid: (
            f"Class {cid}: {scatter_data[scatter_data['id']==cid]['type'].iloc[0]} | "
            f"{scatter_data[scatter_data['id']==cid]['numMembers'].iloc[0]} members | "
            f"{scatter_data[scatter_data['id']==cid]['totalLOC'].iloc[0]} LOC"
        ),
        key="scatter_selection"
    )

# # TODO selectbox error
# with scatter_cols[1]:
#     if st.button("Jump to Class", key="jump_scatter"):
#         st.session_state['jump_scatter_clicked'] = True
#         st.rerun()

# st.markdown("---")

# # Update the selected_id from scatter plot selection
# if 'scatter_selection' in st.session_state and st.session_state.get('jump_scatter_clicked'):
#     selected_id = st.session_state['scatter_selection']
#     # Reset the button state
#     st.session_state['jump_scatter_clicked'] = False
# else:
#     # Keep using the dropdown selection
#     selected_id = st.selectbox(
#         "Select a clone class to inspect",
#         options=filtered_classes_df["id"].tolist(),
#         format_func=lambda cid: f"Class {cid}",
#     )

# ---------- Select a specific clone class ----------
selected_id = st.selectbox(
    "Select a clone class to inspect",
    options=filtered_classes_df["id"].tolist(),
    format_func=lambda cid: f"Class {cid}",
)

selected_class = next(cc for cc in clone_classes if cc["id"] == selected_id)

st.markdown(f"### Details for clone class `{selected_id}` (type: `{selected_class.get('type', 'Unknown')}`)")

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
    width='stretch',
    hide_index=True,
)

st.subheader("Distribution of this clone class over files")

dist_df = build_class_file_distribution(selected_class, file_df)

if not dist_df.empty:
    # Treemap: parent = clone class, children = files
    fig_class_tree = px.treemap(
        dist_df,
        path=["group", "file"],   # hierarchy: Clone X -> File
        values="loc",
    )
    st.plotly_chart(fig_class_tree)

    # Simple bar chart:
    st.caption("Cloned LOC per file (within this class)")
    fig_class_bar = px.bar(
        dist_df,
        x="file",
        y="loc",
        labels={"file": "File", "loc": "LOC in this clone class"},
    )
    st.plotly_chart(fig_class_bar)
else:
    st.info("No members found for this clone class.")

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
            f"({row['className']}.{row['methodName']}, lines {row['beginLine']}-{row['endLine']})"
        )
        snippet = read_code_snippet(
            PROJECT_ROOT,
            row["filePath"],
            int(row["beginLine"]),
            int(row["endLine"]),
        )
        st.code(snippet, language="java")
        st.markdown("---")
else:
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
                PROJECT_ROOT,
                row["filePath"],
                int(row["beginLine"]),
                int(row["endLine"]),
            )
            st.code(snippet, language="java")
