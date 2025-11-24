import SwiftUI
import Foundation

public struct JSONOutlineView: View {
    let nodes: [PreviewNode]
    let summary: JSONPreviewSummary

    public init(nodes: [PreviewNode], summary: JSONPreviewSummary) {
        self.nodes = nodes
        self.summary = summary
    }

    public var body: some View {
        VStack(spacing: 8) {
            SummaryHeader(summary: summary)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(nodes) { node in
                        OutlineRow(node: node)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

public struct JSONPreviewSummary: Equatable {
    public let title: String
    public let subtitle: String?
    public let status: String?
    public let phase: String?
    public let isPublic: Bool
    public let featured: Bool
    public let updatedAt: Date?

    public init(
        title: String,
        subtitle: String? = nil,
        status: String? = nil,
        phase: String? = nil,
        isPublic: Bool,
        featured: Bool,
        updatedAt: Date? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.phase = phase
        self.isPublic = isPublic
        self.featured = featured
        self.updatedAt = updatedAt
    }
}

private struct SummaryHeader: View {
    let summary: JSONPreviewSummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.title)
                    .bold()
                if let subtitle = summary.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 6) {
                chip(summary.isPublic ? "Public" : "Private", color: summary.isPublic ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                if summary.featured {
                    chip("Featured", color: Color.yellow.opacity(0.15))
                }
                if let status = summary.status, !status.isEmpty {
                    chip(status)
                }
                if let phase = summary.phase, !phase.isEmpty {
                    chip(phase)
                }
                if let updated = summary.updatedAt {
                    chip("Updated \(DateFormatter.previewShort.string(from: updated))", color: Color.gray.opacity(0.15))
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

private struct OutlineRow: View {
    let node: PreviewNode

    var body: some View {
        if node.hasChildren {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(node.children) { child in
                        OutlineRow(node: child)
                            .padding(.leading, 16)
                    }
                }
            } label: {
                HStack {
                    Text(node.label)
                        .bold()
                    Spacer()
                    if let value = node.value {
                        Text(value)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .monospacedDigit()
                    }
                }
                .font(.body)
            }
        } else {
            HStack {
                Text(node.label)
                    .font(.body)
                Spacer()
                if let value = node.value {
                    Text(value)
                        .font(.body.monospacedDigit())
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

private func chip(_ text: String, color: Color = Color.blue.opacity(0.15)) -> some View {
    Text(text)
        .font(.caption)
        .foregroundColor(.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color)
        )
}

private func secondaryText(_ text: String) -> Text {
    Text(text).foregroundColor(.secondary)
}

extension DateFormatter {
    static let previewShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

extension JSONOutlineView {
    static func from(document: FolioDocument) -> JSONOutlineView {
        let nodes = document.buildPreviewNodes()
        let summary = JSONPreviewSummary(
            title: document.title,
            subtitle: document.subtitle,
            status: document.status,
            phase: document.phase,
            isPublic: document.isPublic,
            featured: document.featured,
            updatedAt: document.updatedAt
        )
        return JSONOutlineView(nodes: nodes, summary: summary)
    }
}
