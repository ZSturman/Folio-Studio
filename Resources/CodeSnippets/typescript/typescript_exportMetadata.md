```ts
import * as fs from "fs";

const FIELDS = [
  "id","filePath","title","subtitle","summary","description",
  "domain","category","status","phase","isPublic","featured",
  "requiresFollowUp","tags","mediums","genres","topics",
  "subjects","customFlag","customNumber","customObject"
];

export function exportMetadata(path: string, outPath?: string) {
  const data = JSON.parse(fs.readFileSync(path, "utf8"));
  const meta: any = {};
  for (const f of FIELDS) if (data[f] !== undefined) meta[f] = data[f];
  const output = outPath || path.replace(/\.folio.*$/, ".metadata.json");
  fs.writeFileSync(output, JSON.stringify(meta, null, 2));
}
```
