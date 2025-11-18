```javascript
import fs from "fs";

const FIELDS = [
  "id","filePath","title","subtitle","summary","description",
  "domain","category","status","phase","isPublic","featured",
  "requiresFollowUp","tags","mediums","genres","topics",
  "subjects","customFlag","customNumber","customObject"
];

export function exportMetadata(path, outPath) {
  const raw = JSON.parse(fs.readFileSync(path, "utf8"));
  const meta = Object.fromEntries(
    FIELDS.filter(f => raw[f] !== undefined).map(f => [f, raw[f]])
  );
  const output = outPath || path.replace(/\.folio.*$/, ".metadata.json");
  fs.writeFileSync(output, JSON.stringify(meta, null, 2));
  console.log("Wrote:", output);
}
```
