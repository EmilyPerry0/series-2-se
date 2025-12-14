import streamlit as st
from pathlib import Path
import plotly.express as px
import pandas as pd
from data_loader import load_clone_data
from data_stats import enrich_clone_classes, compute_file_stats, build_treemap_nodes, build_file_coupling_matrix, _shorten_filename, build_clone_class_df
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

# ---------- Clone Type Distribution ----------
st.markdown("---")
st.subheader("Clone Type Distribution")

type_counts = pd.DataFrame(
    filtered_cc_for_files
).groupby('type').size().reset_index(name='count')

# Calculate percentages
type_counts['percentage'] = (type_counts['count'] / type_counts['count'].sum() * 100).round(1)

col_pie, col_bar = st.columns(2)

with col_pie:
    fig_pie = px.pie(
        type_counts,
        values='count',
        names='type',
        title="Clone Classes by Type",
        color='type',
        color_discrete_map={
            'Type1': '#e74c3c',  # Red (exact copies)
            'Type2': '#3498db',  # Blue (renamed identifiers)
            'Type3': '#2ecc71',  # Green (modified)
            'Unknown': '#95a5a6'  # Gray
        }
    )
    fig_pie.update_traces(
        textposition='inside',
        textinfo='percent+label',
        hovertemplate='<b>%{label}</b><br>Count: %{value}<br>Percentage: %{percent}<extra></extra>'
    )
    st.plotly_chart(fig_pie, use_container_width=True)

with col_bar:
    # Add LOC per type
    type_loc = []
    for t in type_counts['type']:
        total_loc = sum(
            cc.get('totalLOC', 0) 
            for cc in filtered_cc_for_files 
            if cc.get('type') == t
        )
        type_loc.append(total_loc)
    
    type_counts['totalLOC'] = type_loc
    
    fig_bar = px.bar(
        type_counts,
        x='type',
        y='totalLOC',
        color='type',
        title="Total Cloned LOC by Type",
        labels={'type': 'Clone Type', 'totalLOC': 'Total LOC'},
        color_discrete_map={
            'Type1': '#e74c3c',
            'Type2': '#3498db',
            'Type3': '#2ecc71',
            'Unknown': '#95a5a6'
        },
        text='totalLOC'
    )
    fig_bar.update_traces(
        texttemplate='%{text:,.0f}',
        textposition='outside'
    )
    st.plotly_chart(fig_bar, use_container_width=True)

# Summary table
st.caption("Clone Type Summary")
summary_df = type_counts[['type', 'count', 'percentage', 'totalLOC']].rename(
    columns={
        'type': 'Type',
        'count': '#Clone Classes',
        'percentage': '% of Classes',
        'totalLOC': 'Total LOC'
    }
)
st.dataframe(summary_df, hide_index=True, use_container_width=True)

st.info(
    "**Type I** = Exact copies (ignore whitespace/comments) | "
    "**Type II** = Syntactic copies (identifiers renamed) | "
    "**Type III** = Modified copies (statements changed)"
)

# ---------- Clone Class Size Distribution ----------
st.markdown("---")
st.subheader("Clone Class Size Distribution")

# Build histogram data from ALL clone classes (not just filtered)
class_df_full = build_clone_class_df(clone_classes)

col_hist1, col_hist2 = st.columns(2)

with col_hist1:
    # Histogram by total LOC
    fig_hist_loc = px.histogram(
        class_df_full,
        x='totalLOC',
        color='type',
        title="Clone Classes by Total LOC",
        labels={'totalLOC': 'Total LOC', 'count': 'Number of Clone Classes'},
        nbins=20,
        color_discrete_map={
            'Type1': '#e74c3c',
            'Type2': '#3498db',
            'Type3': '#2ecc71',
            'Unknown': '#95a5a6'
        }
    )
    fig_hist_loc.update_layout(
        xaxis_title="Clone Class Size (LOC)",
        yaxis_title="Number of Clone Classes",
        bargap=0.1
    )
    st.plotly_chart(fig_hist_loc, use_container_width=True)

with col_hist2:
    # Histogram by number of members
    fig_hist_members = px.histogram(
        class_df_full,
        x='numMembers',
        color='type',
        title="Clone Classes by Number of Members",
        labels={'numMembers': 'Number of Members', 'count': 'Number of Clone Classes'},
        nbins=15,
        color_discrete_map={
            'Type1': '#e74c3c',
            'Type2': '#3498db',
            'Type3': '#2ecc71',
            'Unknown': '#95a5a6'
        }
    )
    fig_hist_members.update_layout(
        xaxis_title="Number of Clone Members",
        yaxis_title="Number of Clone Classes",
        bargap=0.1
    )
    st.plotly_chart(fig_hist_members, use_container_width=True)

# Statistics summary
st.caption("Size Distribution Statistics")
stats_cols = st.columns(4)

stats_cols[0].metric(
    "Median Clone Size",
    f"{int(class_df_full['totalLOC'].median())} LOC"
)
stats_cols[1].metric(
    "Largest Clone",
    f"{int(class_df_full['totalLOC'].max())} LOC"
)
stats_cols[2].metric(
    "Median Members",
    f"{int(class_df_full['numMembers'].median())}"
)
stats_cols[3].metric(
    "Most Duplicated",
    f"{int(class_df_full['numMembers'].max())} members"
)

# Insight: Show size buckets
st.caption("Clone Class Size Buckets")
buckets = pd.cut(
    class_df_full['totalLOC'],
    bins=[0, 10, 20, 50, 100, float('inf')],
    labels=['Tiny (≤10)', 'Small (11-20)', 'Medium (21-50)', 'Large (51-100)', 'Huge (>100)']
)
bucket_counts = buckets.value_counts().sort_index()

bucket_df = pd.DataFrame({
    'Size Bucket': bucket_counts.index,
    'Count': bucket_counts.values,
    'Percentage': (bucket_counts.values / bucket_counts.sum() * 100).round(1)
})

st.dataframe(bucket_df, hide_index=True, use_container_width=True)

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

# ---------- Enhanced Treemap with Package Hierarchy ----------
st.markdown("---")
st.subheader("Project Structure: Cloned LOC by Package and File")

# Helper function to extract package hierarchy
def extract_package_hierarchy(file_path: str) -> tuple:
    """
    Extract package hierarchy from file path.
    Returns: (top_level_package, sub_package, file_name)
    
    Example:
    'smallsql0.21_src/src/smallsql/database/SSResultSet.java'
    -> ('smallsql', 'database', 'SSResultSet.java')
    """
    from pathlib import PurePosixPath
    p = PurePosixPath(file_path)
    
    # Find 'src' or similar root
    parts = p.parts
    if 'src' in parts:
        idx = parts.index('src')
        relevant_parts = parts[idx+1:]  # everything after 'src'
    else:
        relevant_parts = parts
    
    if len(relevant_parts) == 0:
        return ('<root>', '<root>', p.name)
    elif len(relevant_parts) == 1:
        return ('<root>', '<root>', relevant_parts[0])
    elif len(relevant_parts) == 2:
        return (relevant_parts[0], '<root>', relevant_parts[1])
    else:
        # e.g., ['smallsql', 'database', 'SSResultSet.java']
        # -> top='smallsql', sub='database', file='SSResultSet.java'
        return (relevant_parts[0], relevant_parts[1], relevant_parts[-1])

# Build enhanced treemap data
treemap_rows = []

# Root node
total_loc = int(file_df["totalClonedLOC"].sum())
treemap_rows.append({
    "id": project,
    "parent": "",
    "label": project,
    "value": 0,  # size is in leaves
    "type": "project"
})

# Extract package info for each file
file_df['top_package'], file_df['sub_package'], file_df['file_only'] = zip(
    *file_df['path'].apply(extract_package_hierarchy)
)

# Get unique top-level packages
top_packages = file_df['top_package'].unique()
for tp in top_packages:
    treemap_rows.append({
        "id": tp,
        "parent": project,
        "label": tp,
        "value": 0,
        "type": "package"
    })

# Get unique sub-packages
for tp in top_packages:
    sub_packages = file_df[file_df['top_package'] == tp]['sub_package'].unique()
    for sp in sub_packages:
        pkg_id = f"{tp}.{sp}" if sp != '<root>' else tp
        parent_id = tp
        treemap_rows.append({
            "id": pkg_id,
            "parent": parent_id,
            "label": sp if sp != '<root>' else tp,
            "value": 0,
            "type": "subpackage"
        })

# Add files
for _, row in file_df.iterrows():
    tp = row['top_package']
    sp = row['sub_package']
    
    if sp == '<root>':
        parent_id = tp
    else:
        parent_id = f"{tp}.{sp}"
    
    treemap_rows.append({
        "id": row['path'],
        "parent": parent_id,
        "label": row['file_only'],
        "value": int(row['totalClonedLOC']),
        "type": "file"
    })

treemap_df_enhanced = pd.DataFrame(treemap_rows)

# Choose visualization style
viz_style = st.radio(
    "Visualization style:",
    options=["Treemap (Space-filling)", "Sunburst (Radial)"],
    horizontal=True
)

if viz_style == "Treemap (Space-filling)":
    fig_tree = px.treemap(
        treemap_df_enhanced,
        ids='id',
        names='label',
        parents='parent',
        values='value',
        color='value',
        color_continuous_scale='Reds',
        title=f"Cloned LOC Distribution: {project}"
    )
    fig_tree.update_traces(
        textposition='middle center',
        marker=dict(line=dict(width=2, color='white'))
    )
    fig_tree.update_layout(height=600)
    
else:  # Sunburst
    fig_tree = px.sunburst(
        treemap_df_enhanced,
        ids='id',
        names='label',
        parents='parent',
        values='value',
        color='value',
        color_continuous_scale='Reds',
        title=f"Cloned LOC Distribution: {project}"
    )
    fig_tree.update_traces(
        textinfo='label+percent parent'
    )
    fig_tree.update_layout(height=600)

st.plotly_chart(fig_tree, use_container_width=True)

# Package-level summary table
st.caption("Cloned LOC by Package")

package_summary = file_df.groupby('top_package').agg({
    'totalClonedLOC': 'sum',
    'numCloneClasses': 'sum',
    'fileId': 'count'
}).rename(columns={
    'totalClonedLOC': 'Total Cloned LOC',
    'numCloneClasses': 'Total Clone Classes',
    'fileId': 'Number of Files'
}).sort_values('Total Cloned LOC', ascending=False)

package_summary['% of Total LOC'] = (
    package_summary['Total Cloned LOC'] / package_summary['Total Cloned LOC'].sum() * 100
).round(1)

st.dataframe(
    package_summary.reset_index().rename(columns={'top_package': 'Package'}),
    hide_index=True,
    use_container_width=True
)

# ---------- Heatmap ----------
st.markdown("---")
st.subheader("File–file clone coupling (heatmap)")

coupling_df = build_file_coupling_matrix(
    filtered_cc_for_files,
    file_df,
    top_k=25,
    min_shared_loc=2 # ignore 1-line overlaps
)

if not coupling_df.empty and (coupling_df.values != 0).any():
    fig_coupling = px.imshow(
        coupling_df,
        labels=dict(x="File", y="File", color="Cloned LOC shared"),
    )

    # full names from the DataFrame (used for hover)
    full_names = list(coupling_df.index)

    # shortened labels for the axes
    short_names = [_shorten_filename(name, max_len=18) for name in full_names]

    # px.imshow uses 0..N-1 as coordinates internally
    tick_vals = list(range(len(short_names)))

    fig_coupling.update_xaxes(
        ticktext=short_names,
        tickvals=tick_vals,
        tickangle=-60,
    )
    fig_coupling.update_yaxes(
        ticktext=short_names,
        tickvals=tick_vals,
    )

    fig_coupling.update_layout(
        width=800,
        height=600,
        margin=dict(l=80, r=20, t=40, b=120),
    )

    st.plotly_chart(fig_coupling, use_container_width=True)
else:
    st.info("No cross-file clones to show for the current filters.")
