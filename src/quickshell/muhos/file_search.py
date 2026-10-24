#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
# MuhOS launcher: find files and folders in the user's main folders whose name
# contains the query. Prints a JSON list of {name, path, isDir}, best first.
#
#   file_search.py <query> [limit]
import json
import os
import sys

SKIP = {"node_modules", ".git", ".cache", "target", "build", "__pycache__", ".local", ".var"}
FOLDERS = ["Desktop", "Documents", "Downloads", "Pictures", "Music", "Videos", ""]
MAX_DEPTH = 3
MAX_VISITED = 20000


def search(query, limit):
    q = query.lower().strip()
    if len(q) < 2:
        return []
    home = os.path.expanduser("~")
    found, seen, visited = [], set(), 0
    for folder in FOLDERS:
        top = os.path.join(home, folder)
        if not os.path.isdir(top):
            continue
        for root, dirs, files in os.walk(top):
            depth = 0 if root == top else os.path.relpath(root, top).count(os.sep) + 1
            dirs[:] = [d for d in dirs if not d.startswith(".") and d not in SKIP]
            entries = [(d, True) for d in dirs] + [(f, False) for f in files]
            # Stop descending below MAX_DEPTH; the home folder itself is only
            # listed, not walked (its subfolders are covered above).
            if depth + 1 >= (1 if folder == "" else MAX_DEPTH):
                dirs.clear()
            for name, is_dir in entries:
                visited += 1
                if name.startswith(".") or q not in name.lower():
                    continue
                path = os.path.join(root, name)
                if path in seen:
                    continue
                seen.add(path)
                rank = 0 if name.lower().startswith(q) else 1
                found.append((rank, len(name), name, path, is_dir))
            if visited > MAX_VISITED:
                break
    found.sort()
    return [{"name": n, "path": p, "isDir": d} for _, _, n, p, d in found[:limit]]


if __name__ == "__main__":
    query = sys.argv[1] if len(sys.argv) > 1 else ""
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 6
    print(json.dumps(search(query, limit)))
