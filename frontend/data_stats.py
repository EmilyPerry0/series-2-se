from pathlib import PurePosixPath
import pandas as pd
import itertools


def enrich_clone_classes(clone_classes: list[dict]) -> list[dict]:
    """
    Adds per-member LOC and per-class aggregates:
      member["loc"], class["totalLOC"], class["maxMemberLOC"],
      class["numMembers"], class["numFilesInvolved"]
    """
    for cc in clone_classes:
        sizes = []
        file_ids = set()

        for m in cc["members"]:
            loc = m["endLine"] - m["beginLine"] + 1
            m["loc"] = loc
            sizes.append(loc)
            file_ids.add(m["fileId"])

        cc["totalLOC"] = sum(sizes)
        cc["maxMemberLOC"] = max(sizes) if sizes else 0
        cc["numMembers"] = len(cc["members"])
        cc["numFilesInvolved"] = len(file_ids)

    return clone_classes


def compute_file_stats(files: dict[int, str], clone_classes: list[dict]) -> pd.DataFrame:
    """
    Returns a DataFrame with one row per file that participates in at least one clone:
      fileId, path, fileName, package, totalClonedLOC, numCloneClasses
    """

    # Start with base info
    rows = []
    for fid, path in files.items():
        p = PurePosixPath(path)
        rows.append(
            {
                "fileId": fid,
                "path": path,
                "fileName": p.name,
                # simple "package" from folders before the file
                "package": ".".join(p.parts[:-1]) if len(p.parts) > 1 else "",
                "totalClonedLOC": 0,
                "cloneClassIds": set(),  # temporary, turned into count later
            }
        )

    df = pd.DataFrame(rows).set_index("fileId")

    # Accumulate LOC and clone-class membership
    for cc in clone_classes:
        cc_id = cc["id"]
        for m in cc["members"]:
            fid = m["fileId"]
            loc = m["loc"]
            if fid in df.index:
                df.at[fid, "totalClonedLOC"] += loc
                df.at[fid, "cloneClassIds"].add(cc_id)

    # Convert set -> count
    df["numCloneClasses"] = df["cloneClassIds"].apply(len)

    # Only keep files that actually appear in at least one clone
    df = df[df["numCloneClasses"] > 0].copy()

    # For pretty display
    def short_path(path: str) -> str:
        parts = PurePosixPath(path).parts
        if "src" in parts:
            idx = parts.index("src")
            return "/".join(parts[idx + 1 :])
        return path

    df["shortPath"] = df["path"].apply(short_path)

    return df.reset_index()

def build_clone_class_df(clone_classes: list[dict]) -> pd.DataFrame:
    """
    Turn the enriched clone_classes list into a DataFrame for UI:
      id, type, numMembers, numFilesInvolved, totalLOC, maxMemberLOC
    """
    rows = []
    for cc in clone_classes:
        rows.append(
            {
                "id": cc["id"],
                "type": cc.get("type", "Unknown"),
                "numMembers": cc.get("numMembers", len(cc.get("members", []))),
                "numFilesInvolved": cc.get("numFilesInvolved", 0),
                "totalLOC": cc.get("totalLOC", 0),
                "maxMemberLOC": cc.get("maxMemberLOC", 0),
            }
        )
    return pd.DataFrame(rows)

def build_treemap_nodes(file_df: pd.DataFrame, project_name: str) -> pd.DataFrame:
    """
    Build nodes for a Plotly treemap:
    - Root: project
    - Level 1: directory (everything before file name, or <root>)
    - Level 2: file (shortPath)
    value = totalClonedLOC at file level
    """
    rows = []

    # Root node
    total_loc = int(file_df["totalClonedLOC"].sum())
    rows.append({"label": project_name, "parent": "", "value": total_loc})

    # Directory nodes
    dir_paths = set()
    for _, row in file_df.iterrows():
        p = PurePosixPath(row["path"])
        dir_path = "/".join(p.parts[:-1]) if len(p.parts) > 1 else "<root>"
        dir_paths.add(dir_path)

    for d in dir_paths:
        rows.append({
            "label": d,
            "parent": project_name,
            "value": 0,  # the size sits on the files
        })

    # File nodes
    for _, row in file_df.iterrows():
        p = PurePosixPath(row["path"])
        dir_path = "/".join(p.parts[:-1]) if len(p.parts) > 1 else "<root>"
        rows.append({
            "label": row["shortPath"],
            "parent": dir_path,
            "value": int(row["totalClonedLOC"]),
        })

    return pd.DataFrame(rows)
