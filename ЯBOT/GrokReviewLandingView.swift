import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Soft Review landing for same-phone Grok → ЯBOT packets.
/// Does not block Heart / offline; dismiss anytime.
struct GrokReviewLandingView: View {
    @Binding var isPresented: Bool
    var packet: GrokYabotLink.Packet
    var onSendToChat: (String) -> Void

    @State private var copied = false

    private var bodyText: String {
        if !packet.text.isEmpty { return packet.text }
        if !packet.payload.isEmpty { return packet.payload }
        return "(empty review packet)"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("GROK → ЯBOT REVIEW")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(ClayTheme.gold)
                Text("action \(packet.action.rawValue) · id \(packet.id.prefix(8))…")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
                ScrollView {
                    Text(bodyText)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(maxHeight: 280)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))

                HStack(spacing: 10) {
                    Button("Send to Heart") {
                        let t = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        GrokYabotLink.acknowledge(packet, state: "queued_chat", note: "Send to Heart")
                        onSendToChat(t)
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)

                    Button(copied ? "Copied ✓" : "Copy status") {
                        GrokYabotLink.acknowledge(packet, state: "reviewed", note: "status copied")
                        GrokYabotLink.copyStatusToPasteboard()
                        copied = true
                    }
                    .buttonStyle(.bordered)

                    Button("Close") {
                        GrokYabotLink.acknowledge(packet, state: "dismissed", note: "review closed")
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                }
                Text("Online bonus · offline Heart still works without Grok")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.12, green: 0.10, blue: 0.09))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(ClayTheme.gold.opacity(0.35), lineWidth: 1))
            )
            .padding(.horizontal, 24)
            .padding(.top, RedwoodYabarMetrics.contentTopClearance)
        }
    }
}

/// Compact status sheet for yabot://grok?action=status / yabot://status
struct GrokStatusLandingView: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text("ЯBOT ↔ GROK STATUS")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(ClayTheme.gold)
                Text(GrokYabotLink.statusJSONString())
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .textSelection(.enabled)
                HStack {
                    Button("Copy") {
                        GrokYabotLink.copyStatusToPasteboard()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Close") { isPresented = false }
                        .buttonStyle(.bordered)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.12, green: 0.10, blue: 0.09))
            )
            .padding(24)
            .padding(.top, RedwoodYabarMetrics.contentTopClearance)
        }
    }
}
