```swift
import Foundation

func loadFolio(at path: String) throws -> [String: Any] {
    let url = URL(fileURLWithPath: path)
    let data = try Data(contentsOf: url)
    return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
}

func countCollectionItems(_ project: [String: Any]) -> Int {
    guard let collection = project["collection"] as? [String: Any] else { return 0 }
    return collection.values.reduce(0) {
        $0 + ((($1 as? [Any])?.count) ?? 0)
    }
}
```
