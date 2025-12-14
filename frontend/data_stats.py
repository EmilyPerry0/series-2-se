from pathlib import PurePosixPath
import pandas as pd
import itertools
import numpy as np


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

def _shorten_filename(name: str, max_len: int = 18) -> str:
    """
    Shorten very long file names for axis labels.

    Example:
      'ExpressionFunctionReturnP1StringAndBinary.java'
      -> 'Expression…Binary.java'
    """
    if len(name) <= max_len:
        return name

    # keep start and end, replace middle with ellipsis
    keep = max_len - 1  # one char for ellipsis
    front = keep // 2
    back = keep - front
    return f"{name[:front]}…{name[-back:]}"


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


def build_file_coupling_matrix(
    clone_classes: list[dict],
    file_df: pd.DataFrame,
    top_k: int = 25,
    min_shared_loc: int = 1,
) -> pd.DataFrame:
    """
    Build a symmetric matrix where cell (i,j) = total cloned LOC shared
    between file i and file j (over all given clone classes).

    - only keeps files that share at least `min_shared_loc` LOC with someone
    - sorts files by total shared LOC and keeps the top_k most coupled ones

    Assumes:
      - enrich_clone_classes() has already run (members have 'loc')
      - file_df has columns: fileId, shortPath
    """
    if file_df.empty:
        return pd.DataFrame()

    # Map fileId -> shortPath
    id_to_label = {row.fileId: row.fileName for row in file_df.itertuples()}
    file_ids = list(id_to_label.keys())
    n = len(file_ids)

    if n < 2:
        # Nothing interesting to show
        return pd.DataFrame()

    id_index = {fid: i for i, fid in enumerate(file_ids)}

    # Build full NxN matrix
    mat = np.zeros((n, n), dtype=int)

    for cc in clone_classes:
        # Consider only files in this class that appear in file_df
        class_fids = sorted(
            {m["fileId"] for m in cc["members"] if m["fileId"] in id_index}
        )
        if len(class_fids) < 2:
            continue

        # For every pair of files, accumulate shared LOC
        for i, j in itertools.combinations(class_fids, 2):
            weight = sum(
                m.get("loc", m["endLine"] - m["beginLine"] + 1)
                for m in cc["members"]
                if m["fileId"] in (i, j)
            )
            ii, jj = id_index[i], id_index[j]
            mat[ii, jj] += weight
            mat[jj, ii] += weight  # symmetric

    # --- remove files that don't share any LOC with others ---
    row_sums = mat.sum(axis=1)
    nonzero_indices = [
        i for i, s in enumerate(row_sums) if s >= min_shared_loc
    ]

    if not nonzero_indices:
        # no cross-file clones at all
        return pd.DataFrame()

    # --- keep only the top_k most "coupled" files ---
    nonzero_indices.sort(key=lambda i: row_sums[i], reverse=True)
    nonzero_indices = nonzero_indices[:top_k]

    mat2 = mat[nonzero_indices][:, nonzero_indices]
    full_names = [row.fileName for row in file_df.itertuples()]
    # map index -> label (shortened name)
    labels = [
        file_df[file_df["fileId"] == file_ids[i]]["fileName"].iloc[0]
        for i in nonzero_indices
    ]

    df = pd.DataFrame(mat2, index=labels, columns=labels)
    return df

def build_class_file_distribution(cc: dict,
                                  file_df: pd.DataFrame) -> pd.DataFrame:
    """
    For a single clone class cc:
    returns a DataFrame with columns:
      group (e.g. 'Clone 5'),
      file (short path),
      loc (sum of LOC for that file in this class)
    """
    per_file = {}

    for m in cc["members"]:
        fid = m["fileId"]
        loc = m.get("loc", m["endLine"] - m["beginLine"] + 1)
        per_file.setdefault(fid, 0)
        per_file[fid] += loc

    rows = []
    for fid, loc in per_file.items():
        short = file_df[file_df["fileId"] == fid]["shortPath"].iloc[0]
        rows.append({
            "group": f"Clone {cc['id']}",
            "file": short,
            "loc": int(loc),
        })
    return pd.DataFrame(rows)
