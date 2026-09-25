import SwiftUI
import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Small clay face of one of Я's bots (Garage roster face: BotFaceYaBot · BotFaceYaMax · …),
/// or an image file in the workshop folder; falls back to a plain symbol. Used by the Workshop and the Garage.
struct WorkshopAuthorFace: View {
    let author: String
    var size: CGFloat = 26
    /// false = no ring/plate (Garage list follows the no-plate law).
    var framed: Bool = true

    var body: some View {
        let a = WorkshopAuthors.lookup(author)
        return Group {
            if let img = Self.faceImage(a?.face) {
                img.resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill").resizable().scaledToFit()
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28))
        .overlay(RoundedRectangle(cornerRadius: size * 0.28).stroke(Color.white.opacity(framed ? 0.3 : 0), lineWidth: 1))
        .help(a.map { "\($0.display) — \($0.look ?? "")" } ?? author)
    }

    static func faceImage(_ face: String?) -> Image? {
        guard let face, !face.isEmpty else { return nil }
        #if canImport(AppKit)
        if NSImage(named: face) != nil { return Image(face) }
        let file = GameWorkshop.root.appendingPathComponent(face)
        if let ns = NSImage(contentsOf: file) { return Image(nsImage: ns) }
        #elseif canImport(UIKit)
        if UIImage(named: face) != nil { return Image(face) }
        let file = GameWorkshop.root.appendingPathComponent(face)
        if let ui = UIImage(contentsOfFile: file.path) { return Image(uiImage: ui) }
        #endif
        return nil
    }
}
