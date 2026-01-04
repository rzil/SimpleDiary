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
    var bodyPointSize: CGFloat

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
                    SwiftMathView(
                        latex: latex,
                        fontSize: max(14, bodyPointSize + 2),
                        displayMode: true,
                        foregroundColor: .primary
                    )
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
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

    while i < s.endIndex {
        guard let start = s[i...].range(of: "$$") else {
            emitMarkdown(s[i...])
            break
        }

        emitMarkdown(s[i..<start.lowerBound])

        let afterStart = start.upperBound
        guard let end = s[afterStart...].range(of: "$$") else {
            // unmatched $$, treat rest as markdown
            emitMarkdown(s[start.lowerBound...])
            break
        }

        let latexRaw = s[afterStart..<end.lowerBound]
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
