//
//  JSONValue.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//

import Foundation

// MARK: - JSONValue that handles all JSON types
enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let n = try? c.decode(Double.self) { self = .number(n); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON"))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    var string: String? { if case .string(let s) = self { s } else { nil } }
    var number: Double? { if case .number(let n) = self { n } else { nil } }
    var bool:   Bool?   { if case .bool(let b)   = self { b } else { nil } }
    var uuid: UUID? { if case .string(let s) = self { UUID(uuidString: s) } else { nil } }
}

// MARK: - Dynamic coding key to sweep extra fields
struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

extension JSONValue {
    // Convert to Foundation types for JSONSerialization
    fileprivate func toFoundation() -> Any {
        switch self {
        case .null: return NSNull()
        case .bool(let b): return b
        case .number(let n): return n
        case .string(let s): return s
        case .array(let a): return a.map { $0.toFoundation() }
        case .object(let o): return o.mapValues { $0.toFoundation() }
        }
    }

    // Pretty-printed JSON text
    func prettyPrintedJSONString() -> String {
        guard JSONSerialization.isValidJSONObject(toFoundation()) else {
            // Fallback for primitives that are not containers
            if case .string(let s) = self { return "\"\(s)\"" }
            if case .number(let n) = self { return String(n) }
            if case .bool(let b)   = self { return String(b) }
            if case .null          = self { return "null" }
            return "null"
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: toFoundation(), options: [.prettyPrinted, .withoutEscapingSlashes])
            return String(data: data, encoding: .utf8) ?? "null"
        } catch {
            return "null"
        }
    }

    // Parse raw JSON text to JSONValue
    static func parseJSONString(_ text: String) -> JSONValue? {
        let data = Data(text.utf8)
        do {
            let obj = try JSONSerialization.jsonObject(with: data, options: [])
            return JSONValue.fromFoundation(obj)
        } catch {
            return nil
        }
    }

    // Build from Foundation value recursively
    fileprivate static func fromFoundation(_ any: Any) -> JSONValue? {
        switch any {
        case is NSNull:
            return .null
        case let b as Bool:
            return .bool(b)
        case let n as NSNumber:
            // NSNumber may represent Bool already handled. Treat numeric as Double.
            return .number(n.doubleValue)
        case let s as String:
            return .string(s)
        case let a as [Any]:
            return .array(a.compactMap { JSONValue.fromFoundation($0) })
        case let d as [String: Any]:
            var obj: [String: JSONValue] = [:]
            for (k, v) in d {
                if let jv = JSONValue.fromFoundation(v) { obj[k] = jv }
            }
            return .object(obj)
        default:
            return nil
        }
    }
}
