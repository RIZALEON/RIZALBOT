import SwiftUI
import UniformTypeIdentifiers

/// Three-part Decider command bar: long bar window with add (left) + Send (magnetized right).
/// Magnetism law: Send is a FIXED RIGHT SLOT overlay — zero shove on plus/text layout.
struct ClayComposerBar: View {
    @Binding var draft: String
    @Binding var attachments: [ClayAttachment]
    var placeholder: String = ""
    var focused: FocusState<Bool>.Binding
    var onSend: () -> Void
    var onAddFiles: () -> Void

    /// OS-smart purple clay well (ref 05-purple-composer-well + 02-app-mock-shake).
    /// No macOS Button plates — plain freeform clay + / Send only.
    #if os(iOS)
    private let barHeight: CGFloat = 56
    private let plusSize: CGFloat = 32
    #else
    private let barHeight: CGFloat = 64
    private let plusSize: CGFloat = 36
    #endif
    private var barWidth: CGFloat { ClayTheme.slateInnerWidth - 8 }
    /// Exact clay Send asset aspect (320×247 ≈ 1.295). Fixed magnet slot width.
    private var sendWidth: CGFloat { barHeight * (320.0 / 247.0) }
    /// Trailing inset so text never runs under the magnetized Send.
    private var sendSlotPad: CGFloat { sendWidth + 4 }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
    }

    /// Optional smart hint: draft looks like pingpong / net-test verbs.
    var looksLikePingPong: Bool {
        PingPongNetTest.looksLikeNetTest(draft)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachments) { item in
                            Text(item.name)
                                .font(ClayTheme.clayFont(size: 11, weight: .bold))
                                .foregroundStyle(ClayTheme.offWhite)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .onTapGesture { attachments.removeAll { $0.id == item.id } }
                        }
                    }
                }
            }

            // One long bar: plus inside left · text · Send MAGNETIZED right (exact clay asset)
            ZStack(alignment: .trailing) {
                // OPAQUE clay face under art (BtnComposer has rounded-corner alpha;
                // without underlay the chalkboard shows through → false "glass").
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(ClayTheme.purpleClay)
                    .frame(width: barWidth, height: barHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(ClayTheme.charcoalDeep)
                            .padding(7)
                    )
                if ClayImage.exists("BtnComposer") {
                    Image("BtnComposer")
                        .renderingMode(.original)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: barWidth, height: barHeight)
                }
                // Soft lift only — no purple glow bloom
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(ClayTheme.purpleClay.opacity(0.35), lineWidth: 1)
                    .frame(width: barWidth, height: barHeight)
                    .allowsHitTesting(false)

                // LEFT + TEXT only — Send NOT in this HStack (magnetism: zero shove)
                HStack(spacing: 6) {
                    Button(action: onAddFiles) {
                        Group {
                            if ClayImage.exists("BtnPlus") {
                                Image("BtnPlus")
                                    .renderingMode(.original)
                                    .resizable()
                                    .interpolation(.high)
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundStyle(ClayTheme.gold)
                            }
                        }
                        .frame(width: plusSize, height: plusSize)
                        .opacity(1) // HARDCODE: transparency 0
                        .compositingGroup()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .help("Add files")
                    .padding(.leading, 14)

                    TextField("", text: $draft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(ClayTheme.clayFont(size: 14, weight: .semibold))
                        .foregroundStyle(ClayTheme.offWhite)
                        .lineLimit(1...2)
                        .focused(focused)
                        .onSubmit { if canSend { onSend() } }
                        .padding(.trailing, sendSlotPad)

                    Spacer(minLength: 0)
                }
                .frame(width: barWidth, height: barHeight)

                // MAGNETIZED Send — fixed right slot overlay (exact BtnSend clay asset)
                ClaySendMagnet(
                    canSend: canSend,
                    width: sendWidth,
                    height: barHeight,
                    pingPongHint: looksLikePingPong
                ) {
                    if canSend { onSend() }
                }
                .padding(.trailing, 2)
                .zIndex(3)
                .accessibilityLabel(looksLikePingPong ? "Send — pingpong net test" : "Send text and files")
                .help(looksLikePingPong ? "Send → pingpong net-test tree" : "Send text and files")
            }
            .frame(width: barWidth, height: barHeight)
            .compositingGroup() // flatten to opaque clay face
            .shadow(color: Color.black.opacity(0.40), radius: 4, y: 3)
            .frame(maxWidth: .infinity)
            #if os(macOS)
            .onKeyPress(keys: [.return]) { press in
                if press.modifiers.contains(.command), canSend {
                    onSend()
                    return .handled
                }
                return .ignored
            }
            #endif
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chat command")
    }
}

/// Exact claymation Send (BtnSend) — magnetized faceIcon, press feedback; always opaque (no dim-when-empty).
private struct ClaySendMagnet: View {
    var canSend: Bool
    var width: CGFloat
    var height: CGFloat
    var pingPongHint: Bool = false
    var action: () -> Void

    @State private var pressed = false

    var body: some View {
        Group {
            if ClayImage.exists("BtnSend") {
                #if canImport(AppKit)
                if let ns = ClayImage.nsImage(named: "BtnSend") {
                    Image(nsImage: ns)
                        .renderingMode(.original)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                } else {
                    sendFallbackText
                }
                #elseif canImport(UIKit)
                if let ui = ClayImage.uiImage(named: "BtnSend") {
                    Image(uiImage: ui)
                        .renderingMode(.original)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                } else {
                    sendFallbackText
                }
                #else
                sendFallbackText
                #endif
            } else {
                sendFallbackText
            }
        }
        .frame(width: width, height: height)
        .opacity(1.0) // HARDCODE: always opaque — Decider: no dim-when-empty
        .scaleEffect(pressed ? 0.94 : 1.0)
        .shadow(color: Color.black.opacity(pressed ? 0.18 : 0.32), radius: pressed ? 2 : 5, y: pressed ? 1 : 2)
        .offset(y: pressed ? 1 : 0)
        .animation(.spring(response: 0.2, dampingFraction: 0.75), value: pressed)
        .compositingGroup()
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if canSend { pressed = true }
                }
                .onEnded { value in
                    pressed = false
                    guard canSend else { return }
                    let dx = abs(value.translation.width)
                    let dy = abs(value.translation.height)
                    if dx < 24 && dy < 24 {
                        action()
                    }
                }
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            if canSend { action() }
        }
        .modifier(ClaySendFocusOff())
    }

    @ViewBuilder
    private var sendFallbackText: some View {
        Text("Send")
            .font(ClayTheme.clayGoldFont(size: 15, weight: .bold))
            .foregroundStyle(ClayTheme.gold)
            .shadow(color: Color.black.opacity(0.55), radius: 0, x: 0.6, y: 0.9)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ClayTheme.purpleClay)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(ClayTheme.gold.opacity(0.35), lineWidth: 1.2)
                    )
            )
    }
}

private struct ClaySendFocusOff: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            content.focusEffectDisabled()
        } else {
            content
        }
    }
}

/// Chat search well — same BtnComposer clay as the command bar, shorter, sits beside search.
struct ClaySearchBar: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var onClose: () -> Void
    /// Optional width override — toolbar overlay caps so magnets never shove.
    var width: CGFloat? = nil

    private let barHeight: CGFloat = 36
    #if os(iOS)
    private let defaultWidth: CGFloat = 220
    #else
    private let defaultWidth: CGFloat = 280
    #endif

    private var barWidth: CGFloat { width ?? defaultWidth }

    var body: some View {
        // Fill parent width when overlay proposes a smaller frame (magnet glass cap).
        GeometryReader { geo in
            let w = min(barWidth, max(geo.size.width, 72))
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ClayTheme.purpleClay)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(ClayTheme.charcoalDeep)
                            .padding(4)
                    )
                Image("BtnComposer")
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: w, height: barHeight)

                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .font(ClayTheme.clayFont(size: 13, weight: .semibold))
                    .foregroundStyle(ClayTheme.offWhite)
                    .focused(focused)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                    .frame(width: w, height: barHeight)
                    .background(Color.clear)
                    .onSubmit { /* live filter — keep open */ }
            }
            .frame(width: w, height: barHeight)
            .compositingGroup()
            .shadow(color: Color.black.opacity(0.30), radius: 3, y: 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: barHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search chat")
        .help("Search chat for words and phrases")
    }
}

struct ClayAttachment: Identifiable, Equatable {
    let id: UUID
    let name: String
    let url: URL
    init(id: UUID = UUID(), name: String, url: URL) {
        self.id = id; self.name = name; self.url = url
    }
}
