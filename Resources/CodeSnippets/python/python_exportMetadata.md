```python
import json
from pathlib import Path

FIELDS = [
    "id","filePath","title","subtitle","summary","description",
    "domain","category","status","phase","isPublic","featured",
    "requiresFollowUp","tags","mediums","genres","topics",
    "subjects","customFlag","customNumber","customObject"
]

def export_metadata(folio_path, out_path=None):
    folio = Path(folio_path)
    proj = json.loads(folio.read_text("utf-8"))
    meta = {k: proj.get(k) for k in FIELDS if k in proj}

    out = Path(out_path) if out_path else folio.with_suffix(".metadata.json")
    out.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print("Wrote:", out)
```
