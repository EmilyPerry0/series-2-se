from pathlib import Path
from typing import List


def read_code_snippet(project_root: Path, file_path: str, begin_line: int, end_line: int) -> str:
    """
    Read lines [begin_line, end_line] (1-based, inclusive) from the given file.
    Returns a single string with newline separators.
    """
    full_path = project_root / file_path  # file_path is something like "src/smallsql/...java"

    if not full_path.is_file():
        return f"// Could not find file: {full_path}"

    text = full_path.read_text(encoding="utf-8", errors="replace")
    lines: List[str] = text.splitlines()

    # Clamp indices to avoid crashes on bad data
    start_idx = max(0, begin_line - 1)
    end_idx = min(len(lines), end_line)

    snippet_lines = lines[start_idx:end_idx]
    # Add 1-based line numbers for readability
    numbered = [
        f"{i+1:4d}: {line}" for i, line in enumerate(snippet_lines, start=start_idx)
    ]

    return "\n".join(numbered)
