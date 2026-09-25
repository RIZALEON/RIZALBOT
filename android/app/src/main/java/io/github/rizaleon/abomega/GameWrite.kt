package io.github.rizaleon.abomega

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener

/**
 * GAMEWRITE — Android twin of Swift GameWrite (0.3.x).
 * gamewrite <language> <file> <purpose> [as <bot>] [in project X] [```code```]
 * Languages: TypeScript · JavaScript · HTML · CSS · JSON · JSON Schema · GLSL · Markdown
 *            + Swift / Kotlin drafts only (flagged "needs rebuild").
 * Validation on save AND before apply: language/extension, 256 KB cap, JSON parses, no secrets /
 * keys / seed phrases, no signing endpoints / wallet signing calls. Unknown bot names REFUSED.
 */
object GameWrite {
    const val SIZE_CAP = 256 * 1024
    const val BOOK = "GAMEWRITE-FUNDAMENTALS-0.1"

    data class Lang(val id: String, val display: String, val extensions: List<String>, val defaultDir: String, val draftOnly: Boolean)

    val languages = listOf(
        Lang("typescript", "TypeScript", listOf("ts"), "src", false),
        Lang("javascript", "JavaScript", listOf("js", "mjs"), "live", false),
        Lang("html", "HTML", listOf("html", "htm"), "live", false),
        Lang("css", "CSS", listOf("css"), "live", false),
        Lang("json", "JSON", listOf("json"), "data", false),
        Lang("jsonschema", "JSON Schema", listOf("json"), "schema", false),
        Lang("glsl", "GLSL (Phaser shaders)", listOf("glsl", "frag", "vert"), "shaders", false),
        Lang("markdown", "Markdown (design docs)", listOf("md"), "docs", false),
        Lang("swift", "Swift (wrapper · draft only)", listOf("swift"), "native/apple", true),
        Lang("kotlin", "Kotlin (wrapper · draft only)", listOf("kt", "kts"), "native/android", true)
    )

    private val aliases = mapOf(
        "ts" to "typescript", "typescript" to "typescript", "tsx" to "typescript",
        "js" to "javascript", "javascript" to "javascript", "mjs" to "javascript",
        "html" to "html", "htm" to "html", "css" to "css", "json" to "json",
        "schema" to "jsonschema", "jsonschema" to "jsonschema", "json-schema" to "jsonschema", "json_schema" to "jsonschema",
        "glsl" to "glsl", "shader" to "glsl", "frag" to "glsl", "vert" to "glsl",
        "md" to "markdown", "markdown" to "markdown", "doc" to "markdown", "design" to "markdown",
        "swift" to "swift", "kotlin" to "kotlin", "kt" to "kotlin"
    )

    fun lang(raw: String): Lang? {
        val id = aliases[raw.lowercase()] ?: return null
        return languages.firstOrNull { it.id == id }
    }

    data class Check(
        var ok: Boolean = false,
        var language: String? = null,
        var file: String? = null,
        var needsRebuild: Boolean = false,
        val problems: MutableList<String> = mutableListOf(),
        val warnings: MutableList<String> = mutableListOf()
    )

    fun validate(rawLang: String, rawFile: String, content: String): Check {
        val c = Check()
        val L = lang(rawLang)
        if (L == null) {
            c.problems.add("language '$rawLang' not allowed. Allowed: " + languages.joinToString(", ") { it.display })
            return c
        }
        c.language = L.id
        c.needsRebuild = L.draftOnly
        var file = rawFile.trim()
        if (file.isEmpty()) file = defaultFile(L)
        if (!file.contains("/")) file = L.defaultDir + "/" + file
        val parts = file.split("/")
        if (file.startsWith("/") || file.startsWith("~") || parts.contains("..") || parts.any { it.startsWith(".") } || file.contains("\\")) {
            c.problems.add("file must be a plain relative path inside the project (no /, ~, .., dotfiles)")
        }
        if (file == "project.json") c.problems.add("project.json is Decider-owned")
        val ext = file.substringAfterLast('.', "").lowercase()
        if (ext !in L.extensions) {
            c.problems.add("extension .$ext does not match ${L.display} (${L.extensions.joinToString(" ") { ".$it" }})")
        }
        c.file = file
        val bytes = content.toByteArray().size
        if (bytes == 0) c.problems.add("empty draft")
        if (bytes > SIZE_CAP) c.problems.add("draft is $bytes bytes; cap is $SIZE_CAP")
        if (L.id == "json" || L.id == "jsonschema") {
            try {
                val tk = JSONTokener(content)
                val v = tk.nextValue()
                if (tk.nextClean() != 0.toChar()) throw IllegalArgumentException("trailing data")
                if (v is String && !content.trim().startsWith("\"")) throw IllegalArgumentException("bare word")
                if (L.id == "jsonschema") {
                    val o = v as? JSONObject
                    if (o == null || (!o.has("\$schema") && !o.has("type"))) {
                        c.problems.add("JSON Schema needs an object with \"\$schema\" or \"type\"")
                    }
                }
            } catch (_: Exception) {
                c.problems.add("JSON does not parse")
            }
        }
        val (p, w) = securityProblems(content, L.id)
        c.problems.addAll(p)
        c.warnings.addAll(w)
        if (content.contains("eval(") || content.contains("new Function(")) c.warnings.add("uses eval/new Function — Decider review")
        if (L.draftOnly) c.warnings.add("${L.display}: needs rebuild; cannot compile in-app")
        c.ok = c.problems.isEmpty()
        return c
    }

    /** No secrets / keys / seed phrases; no signing endpoints; no wallet signing calls. Game never signs. */
    fun securityProblems(text: String, language: String = ""): Pair<List<String>, List<String>> {
        val out = mutableListOf<String>()
        val warn = mutableListOf<String>()
        val lower = text.lowercase()
        val patterns = listOf(
            "-----BEGIN [A-Z ]*PRIVATE KEY-----" to "private key block",
            "\\b(sk|rk)_(live|test)_[A-Za-z0-9]{16,}" to "API secret key",
            "\\bAKIA[0-9A-Z]{16}\\b" to "cloud access key",
            "\\bgh[pousr]_[A-Za-z0-9]{30,}" to "GitHub token",
            "\\bxox[abprs]-[A-Za-z0-9-]{10,}" to "Slack token",
            "\\b[1-9A-HJ-NP-Za-km-z]{85,90}\\b" to "base58 secret-key-length string",
            "\\[\\s*(\\d{1,3}\\s*,\\s*){31,}\\d{1,3}\\s*\\]" to "raw keypair byte array",
            "\\b0x[0-9a-fA-F]{64}\\b" to "32-byte hex secret"
        )
        for ((p, name) in patterns) if (Regex(p).containsMatchIn(text)) out.add("looks like a secret: $name")
        val words = listOf("seed phrase", "seedphrase", "mnemonic", "secret key", "secretkey", "private key", "privatekey",
            "recovery phrase", "api_key", "apikey")
        for (w in words) if (lower.contains(w)) {
            if (language == "markdown") warn.add("mentions '$w' (doc) — make sure no real key is inside")
            else out.add("mentions '$w' — keys and seed phrases never go in game code")
        }
        val signing = listOf("signtransaction", "signalltransactions", "signmessage", "signandsendtransaction",
            "sendtransaction", "sendrawtransaction", "keypair.fromsecretkey", "keypair.generate",
            "keypair.fromseed", "nacl.sign", "createkeypairsignerfrom", "generatekeypairsigner",
            "createsignerfromkeypair", "signtransactionmessagewithsigners", "window.solana",
            "window.phantom", "window.solflare", "requestairdrop", "wallet.sign", "signer.sign")
        for (s in signing) if (lower.contains(s)) out.add("wallet/signing call '$s' — game never signs; propose a wallet action instead")
        val endpoints = listOf("mainnet-beta.solana.com", "api.devnet.solana.com", "api.testnet.solana.com", "rpc.helius",
            "helius-rpc.com", "quiknode.pro", "alchemy.com/v2", "rpcpool.com", "phantom.app/ul",
            "solflare.com/ul", "walletconnect", "jup.ag/swap", "/rpc")
        for (e in endpoints) if (lower.contains(e)) out.add("network URL to a signing/RPC endpoint '$e'")
        return out to warn
    }

    fun defaultFile(L: Lang): String = when (L.id) {
        "typescript" -> "src/scenes/NewScene.ts"
        "javascript" -> "live/mod.js"
        "html" -> "live/draft.html"
        "css" -> "live/style.css"
        "json" -> "data/level.json"
        "jsonschema" -> "schema/terraformya.save.schema.json"
        "glsl" -> "shaders/clay.frag"
        "markdown" -> "docs/DESIGN.md"
        "swift" -> "native/apple/GameBridge.swift"
        else -> "native/android/GameBridge.kt"
    }

    fun help(): String = """
        GAMEWRITE · bots draft Я Game code into the GAME BUILDERS WORKSHOP (Drafts — never live without Decider)
        bots: ${BotRoster.namesLine()} (default ${BotRoster.defaultBot()?.display ?: "none"}; names = Garage roster seat/BOT-LABELS.json · gamewrite ids = game/workshop/authors.json)
        gamewrite <language> <file> <purpose> [as <bot>]
          e.g. gamewrite typescript src/scenes/Dig.ts mound grows where BLUEFACE digs
               gamewrite glsl shaders/clay.frag warm clay tint as yamax
               gamewrite json data/level1.json first terraform level in blueface
        add ```code``` after the purpose to submit exact code.
        languages: TypeScript · JavaScript · HTML · CSS · JSON · JSON Schema · GLSL · Markdown · Swift* · Kotlin* (*draft only, needs rebuild)
        also: gamewrite languages · gamewrite list · gamewrite show <draftId> · workshop
        apply / reject / respawn: Decider taps them in the Workshop (yabot://game/workshop). Book: $BOOK
    """.trimIndent()

    fun languagesLine(): String = "GAMEWRITE languages:\n" +
        languages.joinToString("\n") { "· ${it.display} — .${it.extensions.joinToString(" .")} → ${it.defaultDir}/" }

    fun listDrafts(ctx: Context): String {
        val ds = GameWorkshop.drafts(ctx)
        if (ds.isEmpty()) return "No workshop drafts yet. Try: gamewrite typescript src/scenes/Dig.ts mound grows where BLUEFACE digs"
        return "WORKSHOP DRAFTS (newest first):\n" + ds.take(20).joinToString("\n") {
            "· ${it.id} · ${it.status} · ${it.language} · ${it.project}/${it.file} · by ${it.authorDisplay} — ${it.purpose}"
        }
    }

    fun show(ctx: Context, id: String): String {
        val d = GameWorkshop.draft(ctx, id) ?: return "No draft $id. Try: gamewrite list"
        val head = GameWorkshop.content(ctx, d).split("\n").take(60).joinToString("\n")
        return "${d.id} · ${d.status} · ${d.language} · ${d.project}/${d.file} · by ${d.authorDisplay}\npurpose: ${d.purpose}\n```\n$head\n```"
    }

    data class Result(val reply: String, val speaker: String)

    /** Parse `gamewrite …`; returns reply + who speaks it (bot name on success, Я on refusal). */
    fun handle(ctx: Context, text: String, heart: NativeHeart?): Result {
        var body = text.trim()
        var inline: String? = null
        val fence = body.indexOf("```")
        if (fence >= 0) {
            val after = body.substring(fence + 3)
            val nl = after.indexOf('\n').let { if (it < 0) 0 else it + 1 }
            val rest = after.substring(nl)
            val end = rest.indexOf("```")
            inline = (if (end >= 0) rest.substring(0, end) else rest).trim('\n')
            body = body.substring(0, fence).trim()
        }
        for (p in listOf("gamewrite:", "gamewrite ", "game write:", "game write ", "write game code:", "write game code ",
            "draft game code:", "draft game code ", "write game ", "draft game ")) {
            if (body.lowercase().startsWith(p)) { body = body.substring(p.length).trim(); break }
        }
        // author: "as <word>" — any word after `as` is taken as a bot name; unknown → REFUSED
        var authorRaw = ""
        val known = BotRoster.aliasWords().map { Regex.escape(it) }.sortedByDescending { it.length }.joinToString("|")
        val asKnown = Regex("(?:^|\\s)as\\s+($known)(?=\\s|$)", RegexOption.IGNORE_CASE).find(body)
        // Swift twin: any other trailing "as <name>" (end of text, or right before "in project …") names an
        // author too — resolved against the Garage roster and REFUSED if unknown (no silent fallback, e.g. "as garage").
        val asAny = asKnown ?: Regex("(?:^|\\s)as\\s+(\\S+)\\s*(?=$|\\s+in\\s+project\\b|\\s+in\\s+blueface\\b)", RegexOption.IGNORE_CASE).find(body)
        if (asAny != null) {
            authorRaw = asAny.groupValues[1]
            body = body.removeRange(asAny.range).trim()
        }
        if (authorRaw.isNotEmpty() && BotRoster.resolve(authorRaw) == null) {
            GameWorkshop.ledger(ctx, mapOf("event" to "refused", "author" to authorRaw, "reasons" to listOf("unknown bot name"), "device" to "android"))
            return Result("GAMEWRITE refused (nothing saved) · " + BotRoster.refusal(authorRaw) +
                "\nIf \"as $authorRaw\" was part of the purpose, rephrase it (e.g. \"like $authorRaw\").", BotRoster.MIND)
        }
        var project = GameWorkshop.SEED_ID
        Regex("\\bin\\s+project\\s+([A-Za-z0-9_-]+)|\\bin\\s+(blueface)\\b", RegexOption.IGNORE_CASE).find(body)?.let { m ->
            project = (m.groupValues[1].ifEmpty { m.groupValues[2] }).lowercase()
            body = body.removeRange(m.range).trim()
        }
        val tokens = body.split(Regex("\\s+")).filter { it.isNotEmpty() }
        var L: Lang? = null
        var file = ""
        val rest = mutableListOf<String>()
        val fileRe = Regex("^[A-Za-z0-9_./-]+\\.[A-Za-z0-9]+$")
        for (t in tokens) {
            val clean = t.trim(',', ';', ':')
            if (L == null && lang(clean) != null) { L = lang(clean); continue }
            if (file.isEmpty() && clean.contains(".") && !clean.endsWith(".") && fileRe.matches(clean)) { file = clean; continue }
            rest.add(t)
        }
        if (L == null && file.isNotEmpty()) {
            L = if (file.lowercase().endsWith(".schema.json")) lang("jsonschema") else lang(file.substringAfterLast('.'))
        }
        if (L == null) {
            val low = body.lowercase()
            L = when {
                low.contains("phaser") || low.contains("scene") -> lang("typescript")
                low.contains("shader") -> lang("glsl")
                low.contains("level") || low.contains("data") -> lang("json")
                low.contains("design") || low.contains("doc") -> lang("markdown")
                else -> null
            }
        }
        val lg = L ?: return Result("GAMEWRITE needs a language.\n" + help(), BotRoster.MIND)
        val purpose = rest.joinToString(" ").trim()
        if (file.isEmpty()) file = defaultFile(lg)
        return authorDraft(ctx, lg, file, purpose, project, authorRaw, inline, heart)
    }

    private fun authorDraft(
        ctx: Context, L: Lang, file: String, purpose: String, project: String,
        authorRaw: String, inline: String?, heart: NativeHeart?
    ): Result {
        var code: String
        var source: String
        if (!inline.isNullOrEmpty()) {
            code = inline; source = "inline"
        } else {
            // Android Heart is capped at 16 new tokens (NativeHeart) — too short for a fenced code block,
            // and a 3B prompt decode blocks for minutes on phones. So Android drafts start from the
            // fundamentals starter (or exact ```inline``` code); the Apple builds may use the Heart.
            code = starter(L.id, file, purpose); source = "starter"
        }
        val (d, msg) = GameWorkshop.propose(ctx, project, file, L.id, code, purpose, authorRaw, source)
        val speaker = d?.authorDisplay ?: BotRoster.MIND
        if (d != null && source == "starter") {
            return Result(msg + "\n(Android: seeded the ${L.display} starter from $BOOK — edit it or submit exact code in ``` fences. Still a draft.)", speaker)
        }
        return Result(msg, speaker)
    }

    private fun heartPrompt(L: Lang, file: String, purpose: String): String = """
        You are a Я Game builder bot (TeraformЯ, Phaser 4 + TypeScript in a WebView). Write ${L.display} for file $file.
        Purpose: ${purpose.ifEmpty { "small useful piece for the BLUEFACE game" }}
        Rules: one ${L.id} code block in ``` fences only; short (under 40 lines); no network; no wallets, keys or signing (game never signs);
        BLUEFACE moves are fixed: idle walk dig cheer takeThat; save = {v:1,name:'BLUEFACE',crown:'Я',position,facing,action,tool}.
    """.trimIndent()

    fun extractFence(raw: String): String? {
        val s = raw.indexOf("```")
        if (s < 0) return null
        val after = raw.substring(s + 3)
        val nl = after.indexOf('\n').let { if (it < 0) 0 else it + 1 }
        val rest = after.substring(nl)
        val e = rest.indexOf("```")
        return (if (e >= 0) rest.substring(0, e) else rest).trim()
    }

    private fun jsonString(s: String): String = JSONObject.quote(s)

    fun starter(language: String, file: String, purpose: String): String {
        val p = purpose.ifEmpty { "Я Game draft" }
        return when (language) {
            "typescript" -> {
                val cls = file.substringAfterLast('/').substringBeforeLast('.').filter { it.isLetterOrDigit() }
                val name = cls.ifEmpty { "DraftScene" }
                """
                // $p
                // GAMEWRITE starter · TypeScript + Phaser 4 · NonNuclear draft (Decider applies)
                import Phaser from 'phaser';

                export class $name extends Phaser.Scene {
                  private moundCount = 0;
                  constructor() { super('${name.lowercase()}'); }

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
                """.trimIndent()
            }
            "javascript" -> """
                // $p
                // GAMEWRITE starter · JavaScript (runs in the game WebView) · no network, no wallets
                (function () {
                  'use strict';
                  const game = window.__BF;              // BLUEFACE automation hook (scene, hero, state)
                  if (!game) { console.log('BLUEFACE not loaded'); return; }
                  const s = game.state();                // {v:1,name:'BLUEFACE',crown:'Я',position,facing,action,tool}
                  console.log('BLUEFACE at', s.position.x, s.position.y, 'doing', s.action);
                })();
                """.trimIndent()
            "html" -> """
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
                  <!-- $p -->
                  <main><h1>TeraformЯ · draft</h1></main>
                </body>
                </html>
                """.trimIndent()
            "css" -> """
                /* $p — GAMEWRITE starter · CSS */
                :root { --clay: #6b4a2b; --cream: #efe6d6; --gold: #c9a227; }
                html, body { margin: 0; height: 100%; background: #140e0a; color: var(--cream); }
                #game { display: flex; align-items: center; justify-content: center; height: 100%; }
                canvas { max-width: 100%; max-height: 100%; image-rendering: auto; }
                """.trimIndent()
            "json" -> """
                {
                  "v": 1,
                  "crown": "Я",
                  "purpose": ${jsonString(p)},
                  "level": { "id": "level-1", "width": 1280, "height": 720, "groundY": 640 },
                  "spawns": [ { "who": "BLUEFACE", "x": 640, "y": 640, "facing": "right" } ]
                }
                """.trimIndent()
            "jsonschema" -> """
                {
                  "${'$'}schema": "https://json-schema.org/draft/2020-12/schema",
                  "${'$'}id": "terraformya.save",
                  "title": "terraformya.save v1",
                  "description": ${jsonString(p)},
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
                """.trimIndent()
            "glsl" -> """
                // $p — GAMEWRITE starter · GLSL fragment (Phaser 4 filter/shader)
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
                """.trimIndent()
            "markdown" -> """
                # $p

                **Purpose / intent:** why this change helps the game.
                **Crown:** Я · **Gamewrite bots:** ${BotRoster.namesLine()}

                ## What changes
                - …

                ## Save / API impact
                - BLUEFACE move list (idle, walk, dig, cheer, takeThat) and save format stay fixed.

                ## Proposal flow
                propose → Decider approves → apply (respawn snapshot first).
                """.trimIndent()
            "swift" -> """
                // $p
                // GAMEWRITE starter · Swift wrapper (DRAFT ONLY — needs rebuild; cannot compile in-app)
                import Foundation

                /// Game → native bridge message. Game never signs: wallet actions arrive as proposals only.
                struct GameBridgeMessage: Codable {
                    let kind: String      // "save" | "proposal"
                    let payload: String   // JSON (terraformya.save v1 or a wallet-action proposal)
                }
                """.trimIndent()
            else -> """
                // $p
                // GAMEWRITE starter · Kotlin wrapper (DRAFT ONLY — needs rebuild; cannot compile in-app)
                package io.github.rizaleon.abomega.game

                /** Game -> native bridge message. Game never signs: wallet actions arrive as proposals only. */
                data class GameBridgeMessage(val kind: String, val payload: String)
                """.trimIndent()
        }
    }
}
