```ts
import * as fs from "fs";

export interface Folio { [key: string]: any }

export function loadFolio(path: string): Folio {
  return JSON.parse(fs.readFileSync(path, "utf8"));
}

function countCollectionItems(p: Folio): number {
  const c = p.collection || {};
  return Object.values(c).reduce((n, v) => n + (Array.isArray(v) ? v.length : 0), 0);
}

export function printSummary(p: Folio) {
  console.log("ID:", p.id);
  console.log("Title:", p.title || p.name);
  console.log("Domain:", p.domain);
  console.log("Tags:", (p.tags || []).join(", "));
  console.log("Collection items:", countCollectionItems(p));
}
```
