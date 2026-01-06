//
//  MarkdownWithMathView.swift
//  SimpleDiary
//
//  Created by Ruben Zilibowitz on 4/1/2026.
//

import Foundation
import SwiftUI
import MarkdownUI

struct MarkdownWithMathView: View {
    let source: String

    private var nodes: [PreviewNode] {
        splitMarkdownAndMathBlocks(source)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(nodes) { node in
                switch node {
                case .markdown(let chunk):
                    Markdown(chunk)
                        .frame(maxWidth: .infinity, alignment: .leading)

                case .mathBlock(let latex):
                    SwiftMathBlock(
                        latex: latex,
                        fontSize: 18,
                        foregroundColor: .primary
                    )
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum PreviewNode: Identifiable, Equatable {
    case markdown(String)
    case mathBlock(String)

    var id: String {
        switch self {
        case .markdown(let s): return "md:" + String(s.hashValue)
        case .mathBlock(let s): return "math:" + String(s.hashValue)
        }
    }
}

func splitMarkdownAndMathBlocks(_ input: String) -> [PreviewNode] {
    let s = input
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")

    var out: [PreviewNode] = []
    var i = s.startIndex

    func emitMarkdown(_ chunk: Substring) {
        let str = String(chunk)
        if !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            out.append(.markdown(str))
        }
    }

    // Helper to find the next opening delimiter among $$ or \[
    func nextOpen(from index: String.Index) -> (range: Range<String.Index>, kind: String)? {
        let search = s[index...]
        let dollar = search.range(of: "$$")
        let bracket = search.range(of: "\\[")
        switch (dollar, bracket) {
        case (nil, nil):
            return nil
        case let (d?, nil):
            return (d, "$$")
        case let (nil, b?):
            return (b, "\\[")
        case let (d?, b?):
            if d.lowerBound <= b.lowerBound { return (d, "$$") } else { return (b, "\\[") }
        }
    }

    // Map opening kind to its closing delimiter
    func closingDelimiter(for kind: String) -> String {
        switch kind {
        case "$$": return "$$"
        case "\\[": return "\\]"
        default: return kind
        }
    }

    while i < s.endIndex {
        guard let open = nextOpen(from: i) else {
            emitMarkdown(s[i...])
            break
        }

        // Emit markdown before the opening delimiter
        emitMarkdown(s[i..<open.range.lowerBound])

        let afterOpen = open.range.upperBound
        let closeToken = closingDelimiter(for: open.kind)
        guard let end = s[afterOpen...].range(of: closeToken) else {
            // unmatched opening, treat rest as markdown
            emitMarkdown(s[open.range.lowerBound...])
            break
        }

        let latexRaw = s[afterOpen..<end.lowerBound]
        let latex = String(latexRaw).trimmingCharacters(in: .whitespacesAndNewlines)
        out.append(.mathBlock(latex))

        i = end.upperBound
    }

    // Optional: merge adjacent markdown nodes (keeps MarkdownUI happier)
    var merged: [PreviewNode] = []
    for node in out {
        if case .markdown(let s) = node,
           case .markdown(let prev)? = merged.last {
            merged.removeLast()
            merged.append(.markdown(prev + s))
        } else {
            merged.append(node)
        }
    }

    return merged
}
