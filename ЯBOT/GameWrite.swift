import Foundation

/// GAMEWRITE — in-app bots draft Я Game code into the GAME BUILDERS WORKSHOP (Drafts only).
/// Gamewrite authors: Я's bots by their Garage names (today ЯBOT · ЯMAX) — names from the Garage roster,
/// permission list in <workshop>/authors.json (editable without a rebuild). Unknown names are refused.
/// Command: gamewrite <language> <file> <purpose>   (optional: `as yabot` / `as yamax`, `in <project>`,
///          and a ```fenced``` body to submit exact code instead of asking the Heart).
/// Languages: TypeScript · JavaScript · HTML · CSS · JSON · JSON Schema · GLSL · Markdown
///            + Swift / Kotlin as drafts only (wrapper code — flagged "needs rebuild").
/// Law: validate on save (language/extension, size cap, JSON parses, no secrets / keys / seed phrases,
///      no signing endpoints, no wallet signing calls). Game never signs. Nothing goes live without Decider.
/// Teach book: mind/books/GAMEWRITE-FUNDAMENTALS-0.1.md (bundled).
enum GameWrite {
    static let sizeCap = 256 * 1024
    static let fundamentalsBook = "GAMEWRITE-FUNDAMENTALS-0.1"

    struct Lang {
        let id: String
        let display: String
        let extensions: [String]
        let defaultDir: String
        let draftOnly: Bool
    }

    static let languages: [Lang] = [
        Lang(id: "typescript", display: "TypeScript", extensions: ["ts"], defaultDir: "src", draftOnly: false),
        Lang(id: "javascript", display: "JavaScript", extensions: ["js", "mjs"], defaultDir: "live", draftOnly: false),
        Lang(id: "html", display: "HTML", extensions: ["html", "htm"], defaultDir: "live", draftOnly: false),
        Lang(id: "css", display: "CSS", extensions: ["css"], defaultDir: "live", draftOnly: false),
        Lang(id: "json", display: "JSON", extensions: ["json"], defaultDir: "data", draftOnly: false),
        Lang(id: "jsonschema", display: "JSON Schema", extensions: ["json"], defaultDir: "schema", draftOnly: false),
        Lang(id: "glsl", display: "GLSL (Phaser shaders)", extensions: ["glsl", "frag", "vert"], defaultDir: "shaders", draftOnly: false),
        Lang(id: "markdown", display: "Markdown (design docs)", extensions: ["md"], defaultDir: "docs", draftOnly: false),
        Lang(id: "swift", display: "Swift (wrapper · draft only)", extensions: ["swift"], defaultDir: "native/apple", draftOnly: true),
        Lang(id: "kotlin", display: "Kotlin (wrapper · draft only)", extensions: ["kt", "kts"], defaultDir: "native/android", draftOnly: true),
    ]

    static let aliases: [String: String] = [
        "ts": "typescript", "typescript": "typescript", "tsx": "typescript",
        "js": "javascript", "javascript": "javascript", "mjs": "javascript",
        "html": "html", "htm": "html",
        "css": "css",
        "json": "json",
        "schema": "jsonschema", "jsonschema": "jsonschema", "json-schema": "jsonschema", "json_schema": "jsonschema",
        "glsl": "glsl", "shader": "glsl", "frag": "glsl", "vert": "glsl",
        "md": "markdown", "markdown": "markdown", "doc": "markdown", "design": "markdown",
        "swift": "swift", "kotlin": "kotlin", "kt": "kotlin",
    ]

    static func lang(_ raw: String) -> Lang? {
        guard let id = aliases[raw.lowercased()] else { return nil }
        return languages.first { $0.id == id }
    }

    // MARK: - Validation (on save AND again before apply)

    struct Check {
        var ok: Bool
        var language: String?
        var file: String?
        var needsRebuild: Bool
        var problems: [String]
        var warnings: [String]
    }

    static func validate(language rawLang: String, file rawFile: String, content: String) -> Check {
        var c = Check(ok: false, language: nil, file: nil, needsRebuild: false, problems: [], warnings: [])
        guard let L = lang(rawLang) else {
            c.problems.append("language '\(rawLang)' not allowed. Allowed: " + languages.map(\.display).joined(separator: ", "))
            return c
        }
        c.language = L.id
        c.needsRebuild = L.draftOnly
        // File path: relative, inside project, allowed extension.
        var file = rawFile.trimmingCharacters(in: .whitespacesAndNewlines)
        if file.isEmpty { file = defaultFile(for: L) }
        if !file.contains("/") { file = L.defaultDir + "/" + file }
        let parts = file.split(separator: "/").map(String.init)
        if file.hasPrefix("/") || file.hasPrefix("~") || parts.contains("..") || parts.contains(where: { $0.hasPrefix(".") }) {
            c.problems.append("file must be a plain relative path inside the project (no /, ~, .., dotfiles)")
        }
        if file == "project.json" { c.problems.append("project.json is Decider-owned") }
        let ext = (file as NSString).pathExtension.lowercased()
        if !L.extensions.contains(ext) {
            c.problems.append("extension .\(ext) does not match \(L.display) (\(L.extensions.map { "." + $0 }.joined(separator: " ")))")
        }
        c.file = file
        // Size cap.
        let bytes = content.utf8.count
        if bytes == 0 { c.problems.append("empty draft") }
        if bytes > sizeCap { c.problems.append("draft is \(bytes) bytes; cap is \(sizeCap)") }
        // JSON parses.
        if L.id == "json" || L.id == "jsonschema" {
            if let d = content.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed]) {
                if L.id == "jsonschema" {
                    let dict = o as? [String: Any]
                    if dict == nil || (dict?["$schema"] == nil && dict?["type"] == nil) {
                        c.problems.append("JSON Schema needs an object with \"$schema\" or \"type\"")
                    }
                }
            } else {
                c.problems.append("JSON does not parse")
            }
        }
        let sec = securityProblems(content, language: L.id)
        c.problems.append(contentsOf: sec.problems)
        c.warnings.append(contentsOf: sec.warnings)
        if content.contains("eval(") || content.contains("new Function(") {
            c.warnings.append("uses eval/new Function — Decider review")
        }
        if L.draftOnly { c.warnings.append("\(L.display): needs rebuild; cannot compile in-app") }
        c.ok = c.problems.isEmpty
        return c
    }

    /// No secrets / keys / seed phrases; no signing endpoints; no wallet signing calls. Game never signs.
    static func securityProblems(_ text: String, language: String = "") -> (problems: [String], warnings: [String]) {
        var out: [String] = []
        var warn: [String] = []
        let lower = text.lowercased()
        let patterns: [(String, String)] = [
            ("-----BEGIN [A-Z ]*PRIVATE KEY-----", "private key block"),
            ("\\b(sk|rk)_(live|test)_[A-Za-z0-9]{16,}", "API secret key"),
            ("\\bAKIA[0-9A-Z]{16}\\b", "cloud access key"),
            ("\\bgh[pousr]_[A-Za-z0-9]{30,}", "GitHub token"),
            ("\\bxox[abprs]-[A-Za-z0-9-]{10,}", "Slack token"),
            ("\\b[1-9A-HJ-NP-Za-km-z]{85,90}\\b", "base58 secret-key-length string"),
            ("\\[\\s*(\\d{1,3}\\s*,\\s*){31,}\\d{1,3}\\s*\\]", "raw keypair byte array"),
            ("\\b0x[0-9a-fA-F]{64}\\b", "32-byte hex secret"),
        ]
        for (p, name) in patterns where text.range(of: p, options: .regularExpression) != nil {
            out.append("looks like a secret: \(name)")
        }
        let words = ["seed phrase", "seedphrase", "mnemonic", "secret key", "secretkey", "private key", "privatekey",
                     "recovery phrase", "api_key", "apikey"]
        for w in words where lower.contains(w) {
            // Design docs may talk ABOUT keys (laws); code may not carry them.
            if language == "markdown" { warn.append("mentions '\(w)' (doc) — make sure no real key is inside") }
            else { out.append("mentions '\(w)' — keys and seed phrases never go in game code") }
        }
        let signing = ["signtransaction", "signalltransactions", "signmessage", "signandsendtransaction",
                       "sendtransaction", "sendrawtransaction", "keypair.fromsecretkey", "keypair.generate",
                       "keypair.fromseed", "nacl.sign", "createkeypairsignerfrom", "generatekeypairsigner",
                       "createsignerfromkeypair", "signtransactionmessagewithsigners", "window.solana",
                       "window.phantom", "window.solflare", "requestairdrop", "wallet.sign", "signer.sign"]
        for s in signing where lower.contains(s) { out.append("wallet/signing call '\(s)' — game never signs; propose a wallet action instead") }
        let endpoints = ["mainnet-beta.solana.com", "api.devnet.solana.com", "api.testnet.solana.com", "rpc.helius",
                         "helius-rpc.com", "quiknode.pro", "alchemy.com/v2", "rpcpool.com", "phantom.app/ul",
                         "solflare.com/ul", "walletconnect", "jup.ag/swap", "/rpc"]
        for e in endpoints where lower.contains(e) { out.append("network URL to a signing/RPC endpoint '\(e)'") }
        return (out, warn)
    }

    static func defaultFile(for L: Lang) -> String {
        switch L.id {
        case "typescript": return "src/scenes/NewScene.ts"
        case "javascript": return "live/mod.js"
        case "html": return "live/draft.html"
        case "css": return "live/style.css"
        case "json": return "data/level.json"
        case "jsonschema": return "schema/terraformya.save.schema.json"
        case "glsl": return "shaders/clay.frag"
        case "markdown": return "docs/DESIGN.md"
        case "swift": return "native/apple/GameBridge.swift"
        default: return "native/android/GameBridge.kt"
        }
    }

    // MARK: - Chat command

    static var help: String { """
    GAMEWRITE · bots draft Я Game code into the GAME BUILDERS WORKSHOP (Drafts — never live without Decider)
    authors (Garage names): \(WorkshopAuthors.namesLine()) (default \(WorkshopAuthors.defaultAuthor?.display ?? "none"); `as <name>` picks one; unknown names are refused)
    gamewrite <language> <file> <purpose>
      e.g. gamewrite typescript src/scenes/Dig.ts mound grows where BLUEFACE digs
           gamewrite glsl shaders/clay.frag warm clay tint as yamax
           gamewrite json data/level1.json first terraform level in blueface
    add ```code``` after the purpose to submit exact code (bots / CoS / Grok packets).
    languages: TypeScript · JavaScript · HTML · CSS · JSON · JSON Schema · GLSL · Markdown · Swift* · Kotlin* (*draft only, needs rebuild)
    also: gamewrite languages · gamewrite list · gamewrite show <draftId> · workshop
    apply / reject / respawn: Decider taps them in the Workshop (yabot://game/workshop). Book: GAMEWRITE-FUNDAMENTALS-0.1
    """ }

    static func languagesLine() -> String {
        "GAMEWRITE languages:\n" + languages.map { "· \($0.display) — .\($0.extensions.joined(separator: " .")) → \($0.defaultDir)/" }.joined(separator: "\n")
    }

    static func listDrafts() -> String {
        let ds = GameWorkshop.drafts()
        if ds.isEmpty { return "No workshop drafts yet. Try: gamewrite typescript src/scenes/Dig.ts mound grows where BLUEFACE digs" }
        return "WORKSHOP DRAFTS (newest first):\n" + ds.prefix(20).map {
            "· \($0.id) · \($0.status.rawValue) · \($0.language) · \($0.project)/\($0.file) · by \($0.authorDisplay) — \($0.purpose)"
        }.joined(separator: "\n")
    }

    static func show(_ id: String) -> String {
        guard let d = GameWorkshop.draft(id) else { return "No draft \(id). Try: gamewrite list" }
        let body = GameWorkshop.content(d)
        let head = body.components(separatedBy: "\n").prefix(60).joined(separator: "\n")
        return "\(d.id) · \(d.status.rawValue) · \(d.language) · \(d.project)/\(d.file) · by \(d.authorDisplay)\npurpose: \(d.purpose)\n```\n\(head)\n```"
    }

    /// Parse `gamewrite …` or natural phrasing and author a draft. Returns chat reply.
    static func handle(_ text: String) -> String {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Inline fenced code (exact submission)
        var inline: String? = nil
        if let start = body.range(of: "```") {
            let after = body[start.upperBound...]
            let firstNL = after.firstIndex(of: "\n") ?? after.startIndex
            if let end = body.range(of: "```", range: firstNL..<body.endIndex) {
                inline = String(body[firstNL..<end.lowerBound]).trimmingCharacters(in: .newlines)
            } else {
                inline = String(after[firstNL...]).trimmingCharacters(in: .newlines)
            }
            body = String(body[..<start.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for p in ["gamewrite:", "gamewrite ", "game write:", "game write ", "write game code:", "write game code ",
                  "draft game code:", "draft game code ", "write game ", "draft game "] {
            if body.lowercased().hasPrefix(p) { body = String(body.dropFirst(p.count)).trimmingCharacters(in: .whitespaces); break }
        }
        // author: "as yabot" / "as ЯMAX" / any id · display · alias in authors.json
        var authorRaw = ""
        let words = WorkshopAuthors.aliasWords().map { NSRegularExpression.escapedPattern(for: $0) }
            .sorted { $0.count > $1.count }.joined(separator: "|")
        if !words.isEmpty,
           let r = body.range(of: "(?:^|\\s)as\\s+(" + words + ")(?=\\s|$)", options: [.regularExpression, .caseInsensitive]) {
            let hit = String(body[r]).trimmingCharacters(in: .whitespaces)
            authorRaw = hit.replacingOccurrences(of: #"^as\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
            body.replaceSubrange(r, with: " ")
            body = body.trimmingCharacters(in: .whitespaces)
        }
        // Any other trailing "as <name>" (end of text, or right before "in project …") names an author too —
        // it is resolved against the Garage roster and REFUSED if unknown (no silent fallback, e.g. "as garage").
        if authorRaw.isEmpty,
           let r = body.range(of: #"(?:^|\s)as\s+(\S+)\s*(?=$|\s+in\s+project\b|\s+in\s+blueface\b)"#,
                              options: [.regularExpression, .caseInsensitive]) {
            let hit = String(body[r]).trimmingCharacters(in: .whitespaces)
            authorRaw = hit.replacingOccurrences(of: #"^as\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
            body.replaceSubrange(r, with: " ")
            body = body.trimmingCharacters(in: .whitespaces)
        }
        if !authorRaw.isEmpty, WorkshopAuthors.resolve(authorRaw) == nil {
            return "GAMEWRITE refused (nothing saved) · " + WorkshopAuthors.refusal(authorRaw)
                + "\nIf \"as \(authorRaw)\" was part of the purpose, rephrase it (e.g. \"like \(authorRaw)\")."
        }
        // project: "in <project>"
        var project = GameWorkshop.seedProjectId
        if let r = body.range(of: #"\bin\s+project\s+([A-Za-z0-9_-]+)|\bin\s+(blueface)\b"#, options: [.regularExpression, .caseInsensitive]) {
            let words = body[r].split(separator: " ")
            if let last = words.last { project = String(last).lowercased() }
            body.removeSubrange(r)
        }
        let tokens = body.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var L: Lang? = nil
        var file = ""
        var rest: [String] = []
        for t in tokens {
            let clean = t.trimmingCharacters(in: CharacterSet(charactersIn: ",;:"))
            if L == nil, let l = lang(clean) { L = l; continue }
            if file.isEmpty, clean.contains("."), !clean.hasSuffix("."), clean.range(of: #"^[A-Za-z0-9_./-]+\.[A-Za-z0-9]+$"#, options: .regularExpression) != nil {
                file = clean; continue
            }
            rest.append(t)
        }
        if L == nil, !file.isEmpty {
            let ext = (file as NSString).pathExtension.lowercased()
            if file.lowercased().hasSuffix(".schema.json") { L = lang("jsonschema") } else { L = lang(ext) }
        }
        if L == nil {
            let low = body.lowercased()
            if low.contains("phaser") || low.contains("scene") { L = lang("typescript") }
            else if low.contains("shader") { L = lang("glsl") }
            else if low.contains("level") || low.contains("data") { L = lang("json") }
            else if low.contains("design") || low.contains("doc") { L = lang("markdown") }
        }
        guard let lang = L else {
            return "GAMEWRITE needs a language.\n" + help
        }
        let purpose = rest.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if file.isEmpty { file = defaultFile(for: lang) }
        return authorDraft(language: lang, file: file, purpose: purpose, project: project, authorRaw: authorRaw, inline: inline)
    }

    static func authorDraft(language L: Lang, file: String, purpose: String, project: String, authorRaw: String, inline: String?) -> String {
        var code: String
        var source: String
        if let inline, !inline.isEmpty {
            code = inline; source = "inline"
        } else {
            let starterCode = starter(language: L.id, file: file, purpose: purpose)
            code = starterCode; source = "starter"
            if NativeHeart.seated && !L.draftOnly {
                let raw = NativeHeart.generate(prompt: heartPrompt(L, file: file, purpose: purpose), maxNewTokens: 320)
                if let fenced = extractFence(raw), !fenced.isEmpty,
                   validate(language: L.id, file: file, content: fenced).ok {
                    code = fenced; source = "heart"
                }
            }
        }
        let (_, msg) = GameWorkshop.propose(project: project, file: file, language: L.id, content: code,
                                            purpose: purpose, author: authorRaw, source: source)
        if source == "starter" {
            return msg + "\n(Heart draft unavailable or failed validation — seeded the \(L.display) starter from \(fundamentalsBook). Edit/redo freely; still a draft.)"
        }
        return msg
    }

    static func heartPrompt(_ L: Lang, file: String, purpose: String) -> String {
        """
        You are a Я Game builder bot (TeraformЯ, Phaser 4 + TypeScript in a WebView). Write \(L.display) for file \(file).
        Purpose: \(purpose.isEmpty ? "small useful piece for the BLUEFACE game" : purpose)
        Rules: one \(L.id) code block in ``` fences only; short (under 40 lines); no network; no wallets, keys or signing (game never signs);
        BLUEFACE moves are fixed: idle walk dig cheer takeThat; save = {v:1,name:'BLUEFACE',crown:'Я',position,facing,action,tool}.
        Phaser: class X extends Phaser.Scene { create(){} update(t,dt){} } · Graphics + generateTexture for art (no image files).
        """
    }

    static func extractFence(_ raw: String) -> String? {
        guard let start = raw.range(of: "```") else { return nil }
        let after = raw[start.upperBound...]
        let nl = after.firstIndex(of: "\n") ?? after.startIndex
        if let end = raw.range(of: "```", range: nl..<raw.endIndex) {
            return String(raw[nl..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(after[nl...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Starters (fundamentals-shaped; always valid)

    static func starter(language: String, file: String, purpose: String) -> String {
        let p = purpose.isEmpty ? "Я Game draft" : purpose
        switch language {
        case "typescript":
            let cls = ((file as NSString).lastPathComponent as NSString).deletingPathExtension
                .filter { $0.isLetter || $0.isNumber }
            let name = cls.isEmpty ? "DraftScene" : cls
            return """
            // \(p)
            // GAMEWRITE starter · TypeScript + Phaser 4 · NonNuclear draft (Decider applies)
            import Phaser from 'phaser';

            export class \(name) extends Phaser.Scene {
              private moundCount = 0;
              constructor() { super('\(name.lowercased())'); }

              create(): void {
                const g = this.add.graphics();
                g.fillStyle(0x6b4a2b, 1).fillEllipse(32, 16, 64, 32);
                g.generateTexture('mound', 64, 32);
                g.destroy();
                this.add.text(24, 20, 'TeraformЯ', { fontFamily: 'Arial', fontSize: '24px', color: '#f1d09a' });
              }

              /** Call from BLUEFACE's 'dig' event: hero.on('dig', p => scene.spawnMound(p.x, p.y)). */
              spawnMound(x: number, y: number): void {
                const m = this.add.image(x, y, 'mound').setScale(0.2);
                this.tweens.add({ targets: m, scale: 1, duration: 400, ease: 'Back.Out' });
                this.moundCount += 1;
              }

              update(_time: number, _deltaMs: number): void {}
            }
            """
        case "javascript":
            return """
            // \(p)
            // GAMEWRITE starter · JavaScript (runs in the game WebView) · no network, no wallets
            (function () {
              'use strict';
              const game = window.__BF;              // BLUEFACE automation hook (scene, hero, state)
              if (!game) { console.log('BLUEFACE not loaded'); return; }
              const s = game.state();                // {v:1,name:'BLUEFACE',crown:'Я',position,facing,action,tool}
              console.log('BLUEFACE at', s.position.x, s.position.y, 'doing', s.action);
            })();
            """
        case "html":
            return """
            <!DOCTYPE html>
            <html lang="en">
            <head>
              <meta charset="utf-8" />
              <meta name="viewport" content="width=device-width, initial-scale=1" />
              <title>Я Game · draft</title>
              <style>
                html, body { margin: 0; height: 100%; background: #140e0a; color: #efe6d6; font: 16px/1.4 system-ui, sans-serif; }
                main { display: grid; place-items: center; height: 100%; }
              </style>
            </head>
            <body>
              <!-- \(p) -->
              <main><h1>TeraformЯ · draft</h1></main>
            </body>
            </html>
            """
        case "css":
            return """
            /* \(p) — GAMEWRITE starter · CSS */
            :root { --clay: #6b4a2b; --cream: #efe6d6; --gold: #c9a227; }
            html, body { margin: 0; height: 100%; background: #140e0a; color: var(--cream); }
            #game { display: flex; align-items: center; justify-content: center; height: 100%; }
            canvas { max-width: 100%; max-height: 100%; image-rendering: auto; }
            """
        case "json":
            return """
            {
              "v": 1,
              "crown": "Я",
              "purpose": \(jsonString(p)),
              "level": { "id": "level-1", "width": 1280, "height": 720, "groundY": 640 },
              "spawns": [ { "who": "BLUEFACE", "x": 640, "y": 640, "facing": "right" } ]
            }
            """
        case "jsonschema":
            return """
            {
              "$schema": "https://json-schema.org/draft/2020-12/schema",
              "$id": "terraformya.save",
              "title": "terraformya.save v1",
              "description": \(jsonString(p)),
              "type": "object",
              "required": ["v", "name", "crown", "position", "facing", "action", "tool"],
              "properties": {
                "v": { "const": 1 },
                "name": { "const": "BLUEFACE" },
                "crown": { "const": "Я" },
                "position": { "type": "object", "required": ["x", "y"],
                  "properties": { "x": { "type": "number" }, "y": { "type": "number" } } },
                "facing": { "enum": ["left", "right"] },
                "action": { "enum": ["idle", "walk", "dig", "cheer", "takeThat"] },
                "tool": { "enum": ["axe-spade", "double-spade"] }
              },
              "additionalProperties": false
            }
            """
        case "glsl":
            return """
            // \(p) — GAMEWRITE starter · GLSL fragment (Phaser 4 filter/shader)
            precision mediump float;
            uniform sampler2D uMainSampler;
            uniform float uTime;
            varying vec2 outTexCoord;
            void main() {
              vec4 c = texture2D(uMainSampler, outTexCoord);
              vec3 clay = vec3(0.42, 0.29, 0.17);
              float pulse = 0.08 * sin(uTime * 0.002);
              gl_FragColor = vec4(mix(c.rgb, clay, 0.15 + pulse), c.a);
            }
            """
        case "markdown":
            return """
            # \(p)

            **Purpose / intent:** why this change helps the game.
            **Crown:** Я · **Gamewrite authors:** ЯBOT · ЯMAX

            ## What changes
            - …

            ## Save / API impact
            - BLUEFACE move list (idle, walk, dig, cheer, takeThat) and save format stay fixed.

            ## Proposal flow
            propose → Decider approves → apply (respawn snapshot first).
            """
        case "swift":
            return """
            // \(p)
            // GAMEWRITE starter · Swift wrapper (DRAFT ONLY — needs rebuild; cannot compile in-app)
            import Foundation

            /// Game → native bridge message. Game never signs: wallet actions arrive as proposals only.
            struct GameBridgeMessage: Codable {
                let kind: String      // "save" | "proposal"
                let payload: String   // JSON (terraformya.save v1 or a wallet-action proposal)
            }
            """
        default:
            return """
            // \(p)
            // GAMEWRITE starter · Kotlin wrapper (DRAFT ONLY — needs rebuild; cannot compile in-app)
            package io.github.rizaleon.abomega.game

            /** Game -> native bridge message. Game never signs: wallet actions arrive as proposals only. */
            data class GameBridgeMessage(val kind: String, val payload: String)
            """
        }
    }

    private static func jsonString(_ s: String) -> String {
        if let d = try? JSONSerialization.data(withJSONObject: [s], options: []),
           let t = String(data: d, encoding: .utf8) {
            return String(t.dropFirst().dropLast())
        }
        return "\"draft\""
    }
}
