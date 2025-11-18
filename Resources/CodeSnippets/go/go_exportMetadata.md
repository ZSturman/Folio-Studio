```go
package main

import (
    "encoding/json"
    "os"
    "strings"
)

var fields = []string{
    "id","filePath","title","subtitle","summary","description",
    "domain","category","status","phase","isPublic","featured",
    "requiresFollowUp","tags","mediums","genres","topics",
    "subjects","customFlag","customNumber","customObject",
}

func exportMetadata(input string, output string) {
    data, _ := os.ReadFile(input)
    var raw map[string]interface{}
    json.Unmarshal(data, &raw)

    meta := map[string]interface{}{}
    for _, f := range fields {
        if val, ok := raw[f]; ok {
            meta[f] = val
        }
    }

    if output == "" {
        output = strings.TrimSuffix(input, ".folioDoc") + ".metadata.json"
    }
    out, _ := json.MarshalIndent(meta, "", "  ")
    os.WriteFile(output, out, 0644)
}
```
