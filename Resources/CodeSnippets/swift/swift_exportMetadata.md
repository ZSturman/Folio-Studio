```swift
import Foundation

let fields = [
    "id","filePath","title","subtitle","summary","description",
    "domain","category","status","phase","isPublic","featured",
    "requiresFollowUp","tags","mediums","genres","topics",
    "subjects","customFlag","customNumber","customObject"
]

func exportMetadata(inputPath: String, outputPath: String? = nil) throws {
    let inURL = URL(fileURLWithPath: inputPath)
    let data = try Data(contentsOf: inURL)
    let raw = try JSONSerialization.jsonObject(with: data) as! [String:Any]

    var meta: [String: Any] = [:]
    for f in fields { if let v = raw[f] { meta[f] = v } }

    let outURL: URL
    if let outputPath { outURL = URL(fileURLWithPath: outputPath) }
    else { outURL = inURL.deletingPathExtension().appendingPathExtension("metadata.json") }

    let json = try JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted])
    try json.write(to: outURL)
}
```
