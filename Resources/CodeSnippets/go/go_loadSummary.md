```go
package main

import (
    "encoding/json"
    "fmt"
    "os"
)

func loadFolio(path string) (map[string]interface{}, error) {
    data, err := os.ReadFile(path)
    if err != nil { return nil, err }
    var out map[string]interface{}
    json.Unmarshal(data, &out)
    return out, nil
}

func main() {
    project, _ := loadFolio(os.Args[1])
    fmt.Println(project)
}
```
