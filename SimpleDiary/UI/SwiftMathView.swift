//
//  SwiftMathView.swift
//  SimpleDiary
//
//  Created by Ruben Zilibowitz on 4/1/2026.
//

import SwiftUI
import SwiftMath

#if canImport(UIKit)
import UIKit

struct SwiftMathView: UIViewRepresentable {
    let latex: String
    var fontSize: CGFloat
    var displayMode: Bool = true
    var foregroundColor: Color = .primary

    func makeUIView(context: Context) -> MTMathUILabel {
        let v = MTMathUILabel()
        v.backgroundColor = .clear
        v.textAlignment = .left
        v.labelMode = displayMode ? .display : .text
        v.fontSize = fontSize
        v.contentInsets = .init(top: 0, left: 0, bottom: 0, right: 0)
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ v: MTMathUILabel, context: Context) {
        v.labelMode = displayMode ? .display : .text
        v.fontSize = fontSize
        v.textColor = UIColor(foregroundColor)
        v.latex = latex
    }
}

#elseif canImport(AppKit)
import AppKit

struct SwiftMathView: NSViewRepresentable {
    let latex: String
    var fontSize: CGFloat
    var displayMode: Bool = true
    var foregroundColor: Color = .primary

    func makeNSView(context: Context) -> MTMathUILabel {
        let v = MTMathUILabel()
//        v.backgroundColor = .clear
        v.textAlignment = .left
        v.labelMode = displayMode ? .display : .text
        v.fontSize = fontSize
        v.contentInsets = .init(top: 0, left: 0, bottom: 0, right: 0)
        return v
    }

    func updateNSView(_ v: MTMathUILabel, context: Context) {
        v.labelMode = displayMode ? .display : .text
        v.fontSize = fontSize
        v.textColor = NSColor(foregroundColor)
        v.latex = latex
    }
}
#endif
