import json
from pathlib import Path
from typing import Dict, List, Tuple

def load_clone_data(json_path: Path) -> Tuple[str, Dict[int, str], List[dict]]:
    """
    Load clone JSON produced by Rascal.
    Returns: (project_name, files_dict, clone_classes_list)
    files_dict: fileId -> path
    """
    raw = json.loads(json_path.read_text(encoding="utf-8"))

    project = raw["project"]
    files = {f["id"]: f["path"] for f in raw["files"]}
    clone_classes = raw["cloneClasses"]

    return project, files, clone_classes
