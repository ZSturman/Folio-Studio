//
//  Slugify.swift
//  Folio
//
//  Created by Zachary Sturman on 11/4/25.
//


import Foundation

extension String {
    func slugified() -> String {
        // 1) lowercase
        var s = self.lowercased()

        // 2) remove diacritics
        s = s.folding(options: .diacriticInsensitive, locale: .current)

        // 3) keep a–z, 0–9, and whitespace; replace others with space
        s = s.unicodeScalars.map { scalar in
            if CharacterSet.alphanumerics.contains(scalar) || CharacterSet.whitespaces.contains(scalar) {
                return String(scalar)
            } else {
                return " "
            }
        }.joined()

        // 4) collapse whitespace to single hyphens and trim
        s = s.split(whereSeparator: { $0.isWhitespace }).joined(separator: "-")

        // 5) collapse multiple hyphens (defense) and trim hyphens
        while s.contains("--") { s = s.replacingOccurrences(of: "--", with: "-") }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        // fallback if empty
        return s.isEmpty ? "tag" : s
    }
}


