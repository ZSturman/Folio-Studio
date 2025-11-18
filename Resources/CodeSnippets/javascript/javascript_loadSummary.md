```javascript
import fs from "fs";

export function loadFolio(path) {
  return JSON.parse(fs.readFileSync(path, "utf8"));
}

function countCollectionItems(project) {
  const c = project.collection || {};
  return Object.values(c).reduce((n, v) => n + (Array.isArray(v) ? v.length : 0), 0);
}

export function printSummary(project) {
  console.log("ID:", project.id);
  console.log("Title:", project.title || project.name);
  console.log("Domain:", project.domain);
  console.log("Tags:", (project.tags || []).join(", "));
  console.log("Collection items:", countCollectionItems(project));
}

const file = process.argv[2];
printSummary(loadFolio(file));
```
