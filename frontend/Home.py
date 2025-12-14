# frontend/app.py
import streamlit as st
from pathlib import Path
import pandas as pd

from utils import choose_dataset
from data_loader import load_clone_data
from data_stats import enrich_clone_classes, compute_file_stats


ROOT_DIR = Path(__file__).parent.parent
DATA_DIR = ROOT_DIR / "data"

st.set_page_config(page_title="Clone Visualisation", layout="wide")
st.title("Clone Visualisation – Home")

st.sidebar.header("Dataset")
json_path = choose_dataset()

st.success(f"Current dataset: `{json_path.name}`")

# --- dataset comparison table ---
json_files = sorted(DATA_DIR.glob("*.json"))
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

st.markdown("### Summary: All Available Datasets")
st.dataframe(pd.DataFrame(rows), hide_index=True, width='stretch')

st.info("Open **Overview** or **Clone-Class Explorer** in the sidebar to explore.")
