import streamlit as st
from pathlib import Path
from data_loader import load_clone_data
from data_stats import enrich_clone_classes, compute_file_stats
import pandas as pd

st.set_page_config(page_title="Clone Visualisation", layout="wide")

ROOT_DIR = Path(__file__).parent.parent
DATA_DIR = ROOT_DIR / "data"

st.title("Clone Visualisation – Home")

st.write(
    "Use the sidebar to pick which JSON (project/algorithm) you want to explore, "
    "then select a page: **Overview** or **Clone-Class Explorer**."
)

# Discover available JSON files
json_files = sorted(DATA_DIR.glob("*.json"))
if not json_files:
    st.error(f"No JSON files found in `{DATA_DIR}`. Run the Rascal tool first.")
else:
    # Make them pretty in the UI
    options = {f.name: f for f in json_files}

    # Default: keep previous choice if present
    default_name = st.session_state.get("json_name", next(iter(options)))

    selected_name = st.sidebar.selectbox(
        "Select dataset (JSON file)",
        options=list(options.keys()),
        index=list(options.keys()).index(default_name),
    )

    selected_path = options[selected_name]

    # Store in session_state for other pages to use
    st.session_state["json_name"] = selected_name
    st.session_state["json_path"] = str(selected_path)

    st.write(f"**Current dataset:** `{selected_name}`")
    st.success("Now switch to the *Overview* or *Clone-Class Explorer* page in the sidebar.")

st.markdown("### Datasets summary")

rows = []
for jf in json_files:
    proj, files_, ccs_ = load_clone_data(jf)
    ccs_ = enrich_clone_classes(ccs_)
    fdf_ = compute_file_stats(files_, ccs_)
    rows.append(
        {
            "JSON": jf.name,
            "Project": proj,
            "Files with clones": len(fdf_),
            "Clone classes": len(ccs_),
            "Total cloned LOC": int(fdf_["totalClonedLOC"].sum()),
        }
    )

summary_df = pd.DataFrame(rows)
st.dataframe(summary_df, use_container_width=True, hide_index=True)

