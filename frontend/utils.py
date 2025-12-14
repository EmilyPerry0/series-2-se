from pathlib import Path
import streamlit as st
from typing import List


ROOT_DIR = Path(__file__).parent.parent
DATA_DIR = ROOT_DIR / "data"

def read_code_snippet(project_root: Path, file_path: str, begin_line: int, end_line: int) -> str:
    """
    Read lines [begin_line, end_line] but return **only code lines**:
      - Skip blank lines
      - Skip comment-only lines (// ... or /* ... */)
    Keep original line numbers for context.
    """
    full_path = project_root / file_path

    if not full_path.is_file():
        return f"// Could not find file: {full_path}"

    text = full_path.read_text(encoding="utf-8", errors="replace")
    lines: List[str] = text.splitlines()

    start_idx = max(0, begin_line - 1)
    end_idx = min(len(lines), end_line)

    snippet_lines = lines[start_idx:end_idx]

    filtered = []
    inside_block_comment = False

    for i, line in enumerate(snippet_lines, start=start_idx):
        raw = line.strip()

        # Handle block comments /* ... */
        if inside_block_comment:
            if "*/" in raw:
                inside_block_comment = False
            continue

        if raw.startswith("/*"):
            inside_block_comment = True
            continue

        # Skip blank lines
        if raw == "":
            continue

        # Skip single-line comments
        if raw.startswith("//"):
            continue

        # Skip comment-only block lines
        if raw.startswith("*") and raw.endswith("*/"):
            continue

        # Keep the line (with original line number)
        filtered.append(f"{i+1:4d}: {line}")

    if not filtered:
        return "// (No non-comment code lines in this region)"

    return "\n".join(filtered)

def choose_dataset() -> Path:
    """
    Show a 'Select dataset (JSON)' dropdown in the sidebar.
    Stores selection in st.session_state['json_name'] and ['json_path'].
    Returns the selected JSON Path.
    """
    json_files = sorted(DATA_DIR.glob("*.json"))
    if not json_files:
        st.sidebar.error(f"No JSON files found in `{DATA_DIR}`. Run the Rascal tool first.")
        st.stop()

    options = {f.name: f for f in json_files}

    # default: previous choice if present, otherwise first file
    default_name = st.session_state.get("json_name", next(iter(options)))

    # make sure default_name is valid even if files changed
    if default_name not in options:
        default_name = next(iter(options))

    selected_name = st.sidebar.selectbox(
        "Select dataset (JSON file)",
        options=list(options.keys()),
        index=list(options.keys()).index(default_name),
    )

    selected_path = options[selected_name]

    # keep in session_state so all pages use the same selection
    st.session_state["json_name"] = selected_name
    st.session_state["json_path"] = str(selected_path)

    return selected_path
