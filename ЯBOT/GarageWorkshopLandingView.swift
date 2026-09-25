import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Garage workshop landing — Decider HARDCODE 2026-09-23/24.
/// BtnGarage opens this claymation room UNDER sticky Redwood ЯBAR.
/// Left clay sidebar: Search / Create / housed bots / Marketplace / Stats·Data·Training.
/// Shelves house bots; Home on ЯBAR leaves landing. No floating page EXIT.
/// NAMING LAW 2026-09-24 17:12 MDT: the Garage presents Я's bots (its digital robot kids) by their designated
/// names — the SAME names they speak with in chat. Housed bots come from the Garage roster
/// (BotLabel.housedBots · seat/BOT-LABELS.json v3), not from a hardcoded list: today ЯBOT (blue clay horned bat,
/// face BotFaceYaBot, left shelf — shown as "Scout" here until 0.3.0) + ЯMAX (white clay companion, BotFaceYaMax,
/// right shelf). No numbers shown. Shelf hotspots and list rows stay in sync via selectedBotId.
/// Garage itself is the place / bot builder, not a bot.
/// LEGACY TITLE RULE 2026-09-24 17:43 MDT: pre-law titles (ЯBOT#2 · ЯBOT#3) are listed under "Legacy titles"
/// with their origin — kept as-is, usable only from that origin (BotLabel.legacyTitles). No face, no plate.
struct GarageWorkshopLandingView: View {
    @Binding var isPresented: Bool
    @State private var selectedLane: String = "bots"
    @State private var selectedBotId: String? = nil
    @State private var botSearch: String = ""
    @State private var workStripHint: String = ""
    @State private var roster: [BotLabel.RosterBot] = []
    @State private var newBotName: String = ""
    @State private var createNote: String = ""
    @State private var speakingName: String? = nil
    @State private var legacyTitles: [BotLabel.RosterBot] = []

    private let sidebarWidth: CGFloat = 248

    /// Housed bots = Garage roster (single source of bot names).
    private var housedBots: [BotLabel.RosterBot] { roster.filter { $0.housed != false } }

    private func refreshRoster() {
        roster = BotLabel.roster
        legacyTitles = BotLabel.legacyTitles
        speakingName = BotLabel.activeGuestLabel
    }

    private func shelfX(_ bot: BotLabel.RosterBot) -> CGFloat? {
        switch bot.shelf {
        case "left": return 0.48
        case "right": return 0.52
        default: return nil
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Shelf hotspots over full stage (middle shelf, center bay)
            GeometryReader { geo in
                let hotSize = max(56, geo.size.width * 0.07)
                ForEach(housedBots.filter { shelfX($0) != nil }) { bot in
                    shelfHotspot(
                        botId: bot.id,
                        label: "\(bot.name) on shelf",
                        centerX: geo.size.width * (shelfX(bot) ?? 0.5),
                        centerY: geo.size.height * 0.46,
                        size: hotSize
                    )
                }
            }
            .allowsHitTesting(true)

            // Left clay sidebar — under sticky ЯBAR via contentTopClearance
            HStack(alignment: .top, spacing: 0) {
                garageSidebar
                    .frame(width: sidebarWidth)
                    .frame(maxHeight: .infinity, alignment: .top)
                Spacer(minLength: 0)
            }
            .padding(.top, RedwoodYabarMetrics.contentTopClearance)
            .padding(.bottom, 12)

            // Optional light brand — top-center of stage, clear of doorway clutter
            VStack {
                Text("Я / GARAGE · WORKSHOP")
                    .font(ClayTheme.clayFont(size: 11, weight: .bold))
                    .foregroundStyle(ClayTheme.offWhite.opacity(0.72))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.45))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .padding(.top, RedwoodYabarMetrics.contentTopClearance + 8)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)

            // Work strip — bottom of stage when a bot is selected
            if selectedBotId != nil, let bot = housedBots.first(where: { $0.id == selectedBotId }) {
                VStack {
                    Spacer()
                    workStrip(for: bot)
                        .padding(.leading, sidebarWidth + 20)
                        .padding(.trailing, 20)
                        .padding(.bottom, 18)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.18), value: selectedBotId)
        .onAppear { refreshRoster() }
        // Full-bleed room behind chrome (zIndex 200 overlays bar); image does NOT pad itself.
        .background {
            ZStack {
                Color.black
                if ClayImage.exists("GarageWorkshop") {
                    Image("GarageWorkshop")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                }
            }
            .clipped()
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .accessibilityLabel("Garage workshop — bot creation room")
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - Shelf hotspots

    private func shelfHotspot(
        botId: String,
        label: String,
        centerX: CGFloat,
        centerY: CGFloat,
        size: CGFloat
    ) -> some View {
        let isSelected = selectedBotId == botId
        return Button {
            selectBot(botId)
        } label: {
            Circle()
                .fill(Color.white.opacity(isSelected ? 0.06 : 0.01))
                .overlay(
                    Circle()
                        .strokeBorder(
                            isSelected
                                ? AngularGradient(
                                    colors: [
                                        Color.orange.opacity(0.95),
                                        Color.cyan.opacity(0.9),
                                        Color.orange.opacity(0.95)
                                    ],
                                    center: .center
                                )
                                : AngularGradient(
                                    colors: [Color.clear, Color.clear],
                                    center: .center
                                ),
                            lineWidth: isSelected ? 3 : 0
                        )
                )
                .shadow(color: isSelected ? Color.orange.opacity(0.55) : .clear, radius: isSelected ? 10 : 0)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .position(x: centerX, y: centerY)
        .accessibilityLabel(label)
    }

    // MARK: - Work strip

    private func workStrip(for bot: BotLabel.RosterBot) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Working with \(bot.name)")
                    .font(ClayTheme.clayFont(size: 13, weight: .bold))
                    .foregroundStyle(ClayTheme.offWhite)
                if !workStripHint.isEmpty {
                    Text(workStripHint)
                        .font(ClayTheme.clayFont(size: 10, weight: .medium))
                        .foregroundStyle(ClayTheme.offWhite.opacity(0.55))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if speakingName == bot.name {
                workAction("Я speaks") {
                    _ = BotLabel.leave()
                    refreshRoster()
                    workStripHint = "\(bot.name) left the chat · Я — the Machine Mind — speaks"
                }
            } else {
                workAction("Speak") {
                    let reply = BotLabel.enter(bot.name)
                    refreshRoster()
                    workStripHint = reply.components(separatedBy: "\n").first ?? reply
                }
            }
            workAction("Open") { workStripHint = "Open · \(bot.name) (stub)" }
            workAction("Stats") { workStripHint = "Stats · \(bot.name) (stub)"; selectedLane = "stats" }
            workAction("Train") { workStripHint = "Train · \(bot.name) (stub)"; selectedLane = "training" }
            Button {
                clearBotSelection()
            } label: {
                Text("Clear")
                    .font(ClayTheme.clayFont(size: 11, weight: .semibold))
                    .foregroundStyle(ClayTheme.offWhite.opacity(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear bot selection")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.45), Color.cyan.opacity(0.35), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.45), radius: 10, y: 4)
        )
    }

    private func workAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ClayTheme.clayFont(size: 12, weight: .semibold))
                .foregroundStyle(ClayTheme.offWhite)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.orange.opacity(0.28))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.orange.opacity(0.5), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selection helpers

    private func selectBot(_ id: String) {
        if selectedBotId == id {
            clearBotSelection()
            return
        }
        selectedBotId = id
        selectedLane = "bots"
        workStripHint = ""
    }

    private func clearBotSelection() {
        selectedBotId = nil
        workStripHint = ""
        if selectedLane == "bots" || housedBots.contains(where: { $0.id == selectedLane }) {
            selectedLane = "bots"
        }
    }

    // MARK: - Sidebar

    private var garageSidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GARAGE")
                .font(ClayTheme.clayFont(size: 12, weight: .bold))
                .foregroundStyle(ClayTheme.offWhite.opacity(0.85))
                .padding(.horizontal, 4)

            // Search bots
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ClayTheme.offWhite.opacity(0.7))
                TextField("Search bots", text: $botSearch)
                    .textFieldStyle(.plain)
                    .font(ClayTheme.clayFont(size: 13, weight: .medium))
                    .foregroundStyle(ClayTheme.offWhite)
                    #if os(macOS)
                    .textFieldStyle(.plain)
                    #endif
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )

            laneRow(id: "create", title: "+ Create new Bot", system: "plus.circle.fill")
            if selectedLane == "create" {
                createPanel
            }
            laneRow(id: "bots", title: "Housed bots", system: "square.stack.3d.up.fill")

            // Bot list — Garage roster (designated names + faces; shelf figures map here)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(filteredBots, id: \.id) { bot in
                    Button {
                        selectBot(bot.id)
                    } label: {
                        HStack(spacing: 8) {
                            if bot.face != nil {
                                WorkshopAuthorFace(author: bot.name, size: 24, framed: false)
                            } else {
                                Circle()
                                    .fill(Color.cyan.opacity(selectedBotId == bot.id ? 0.55 : 0.22))
                                    .frame(width: 8, height: 8)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(bot.name + (speakingName == bot.name ? " · speaking" : ""))
                                    .font(ClayTheme.clayFont(size: 13, weight: .semibold))
                                    .foregroundStyle(ClayTheme.offWhite)
                                Text(bot.look ?? "")
                                    .font(ClayTheme.clayFont(size: 10, weight: .medium))
                                    .foregroundStyle(ClayTheme.offWhite.opacity(0.55))
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectedBotId == bot.id ? Color.white.opacity(0.12) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(
                                            selectedBotId == bot.id
                                                ? Color.orange.opacity(0.55)
                                                : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(bot.name), \(bot.look ?? "")")
                }
            }
            .padding(.leading, 4)

            // Legacy titles — registered before the naming law; kept as-is, usable only from their origin (no face, no plate)
            if !legacyTitles.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Legacy titles")
                        .font(ClayTheme.clayFont(size: 10, weight: .bold))
                        .foregroundStyle(ClayTheme.offWhite.opacity(0.6))
                    ForEach(legacyTitles) { b in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(b.name + (speakingName == b.name ? " · speaking" : ""))
                                .font(ClayTheme.clayFont(size: 11, weight: .semibold))
                                .foregroundStyle(ClayTheme.offWhite.opacity(0.85))
                            Text("origin: " + BotLabel.describeOrigin(b.origin))
                                .font(ClayTheme.clayFont(size: 9, weight: .medium))
                                .foregroundStyle(ClayTheme.offWhite.opacity(0.45))
                                .lineLimit(2)
                        }
                        .accessibilityLabel("Legacy title \(b.name), origin \(BotLabel.describeOrigin(b.origin))")
                    }
                }
                .padding(.leading, 8)
            }

            Divider().overlay(Color.white.opacity(0.18))

            laneRow(id: "market", title: "Marketplace", system: "storefront.fill")
            laneRow(id: "stats", title: "Stats", system: "chart.bar.fill")
            laneRow(id: "data", title: "Data", system: "externaldrive.fill")
            laneRow(id: "training", title: "Training", system: "brain.head.profile")

            Spacer(minLength: 0)

            Text(laneHint)
                .font(ClayTheme.clayFont(size: 10, weight: .medium))
                .foregroundStyle(ClayTheme.offWhite.opacity(0.5))
                .padding(.horizontal, 4)
                .lineLimit(2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.62))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.22), Color.orange.opacity(0.18), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.55), radius: 14, x: 4, y: 6)
        )
        .padding(.leading, 10)
    }

    private var filteredBots: [BotLabel.RosterBot] {
        let q = botSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return housedBots }
        return housedBots.filter { b in
            ([b.name, b.id, b.look ?? ""] + (b.aliases ?? []) + (b.formerNames ?? []))
                .contains { $0.lowercased().contains(q) }
        }
    }

    /// + Create new Bot — the name typed here is the bot's designated name (what it speaks with in chat).
    private var createPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Name (as it will speak)", text: $newBotName)
                .textFieldStyle(.plain)
                .font(ClayTheme.clayFont(size: 13, weight: .medium))
                .foregroundStyle(ClayTheme.offWhite)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.45))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                        )
                )
                .onSubmit { createBot() }
            HStack(spacing: 8) {
                workAction("Create") { createBot() }
                Text("no numbers · no duplicates")
                    .font(ClayTheme.clayFont(size: 9, weight: .medium))
                    .foregroundStyle(ClayTheme.offWhite.opacity(0.45))
            }
            if !createNote.isEmpty {
                Text(createNote)
                    .font(ClayTheme.clayFont(size: 10, weight: .medium))
                    .foregroundStyle(ClayTheme.offWhite.opacity(0.7))
                    .lineLimit(4)
            }
        }
        .padding(.leading, 4)
    }

    private func createBot() {
        let (bot, msg) = BotLabel.createBot(name: newBotName)
        createNote = msg.components(separatedBy: "\n").first ?? msg
        refreshRoster()
        if let bot {
            newBotName = ""
            selectedBotId = bot.id
            selectedLane = "bots"
            workStripHint = "Created · \(bot.name) — Я's newest bot"
        }
    }

    private var laneHint: String {
        if let id = selectedBotId, let bot = housedBots.first(where: { $0.id == id }) {
            if speakingName == bot.name { return "\(bot.name) is speaking in chat (Я's bot)" }
            if bot.shelf != nil { return "Working with \(bot.name) — shelf linked" }
            return "Working with \(bot.name)"
        }
        switch selectedLane {
        case "create": return "Name it as it will speak in chat · Я's new bot"
        case "market": return "Stub · marketplace later"
        case "stats": return "Stub · bot stats later"
        case "data": return "Stub · bot data later"
        case "training": return "Stub · training later"
        case "bots":
            let names = housedBots.map(\.name)
            return names.isEmpty ? "No housed bots yet · + Create new Bot" : "Я's bots · select " + names.joined(separator: " or ")
        default:
            return "Garage lanes · stubs only"
        }
    }

    private func laneRow(id: String, title: String, system: String) -> some View {
        Button {
            selectedLane = id
            // Switching away from bots lane keeps bot selection (shelf ring stays)
            // unless user is clearing via Clear / re-tap.
        } label: {
            HStack(spacing: 10) {
                Image(systemName: system)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selectedLane == id ? Color.orange.opacity(0.95) : ClayTheme.offWhite.opacity(0.75))
                    .frame(width: 18)
                Text(title)
                    .font(ClayTheme.clayFont(size: 13, weight: .semibold))
                    .foregroundStyle(ClayTheme.offWhite)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selectedLane == id ? Color.orange.opacity(0.22) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                selectedLane == id ? Color.orange.opacity(0.45) : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
