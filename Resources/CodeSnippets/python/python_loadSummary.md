```python
import json
from pathlib import Path

def load_folio(path: str) -> dict:
    p = Path(path)
    with p.open("r", encoding="utf-8") as f:
        return json.load(f)

def count_collection_items(project: dict) -> int:
    collection = project.get("collection") or {}
    return sum(len(v) for v in collection.values() if isinstance(v, list))

def print_summary(project: dict) -> None:
    print("ID:", project.get("id"))
    print("Title:", project.get("title") or project.get("name"))
    print("Subtitle:", project.get("subtitle"))
    print("Domain:", project.get("domain"))
    print("Public:", project.get("isPublic"))
    print("Tags:", ", ".join(project.get("tags") or []))
    print("Collection items:", count_collection_items(project))

if __name__ == "__main__":
    import sys
    project = load_folio(sys.argv[1])
    print_summary(project)
```
