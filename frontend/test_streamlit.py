import streamlit as st
from pathlib import Path

st.title("Clone Visualization")
st.write("Hello world!")

DATA_DIR = Path(__file__).parent.parent / "data"
DEFAULT_JSON = DATA_DIR / "test_data.json" 

st.write("DATA_DIR:", DATA_DIR)
st.write("DEFAULT_JSON:", DEFAULT_JSON)
st.write("JSON exists?", DEFAULT_JSON.exists())
