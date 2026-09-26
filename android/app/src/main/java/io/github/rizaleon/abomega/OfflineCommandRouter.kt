package io.github.rizaleon.abomega

import android.content.Context
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.InetAddress
import java.util.concurrent.TimeUnit

/**
 * Offline premier command surface — Android twin of Mac CompanionRouter + PingPongNetTest.
 * Routes BEFORE Heart. Mode is always OFFLINE PREMIER (online is display-only bonus).
 */
object OfflineCommandRouter {
    const val MINT = "BB9uA5BuacDnWyDf5Npc9nMb9yFbyThsNrQPBYJ5Q1Lv"
    const val MODE_LINE = "MODE: OFFLINE. PREMIER PATH. LOCAL MOUTH ONLY."
    private const val MAX_PING = 5
    private const val DEFAULT_PING = 3
    private const val PROC_TIMEOUT_SEC = 12L

    const val VERSION = "0.3.3"
    const val VERSION_CODE = 5

    data class Route(
        val handled: Boolean,
        val reply: String? = null,
        val bar: BarRoute? = null,
        /** 0.3.1 doors opened under the sticky ЯBAR. */
        val door: Door? = null,
        /** Who speaks the reply (naming law): default Я; bots speak under their Garage names. */
        val speaker: String = BotRoster.assistantLabel()  // Swift resolveSpeaker(.assistant): speaking bot else Я
    )

    enum class BarRoute { LAB, WALLET, MIND, HOME, BOLTE, SEARCH, ONLINE }

    enum class Door { GAME, WORKSHOP, MANUAL, GARAGE, CLASSROOM }

    private val gameWritePrefixes = listOf(
        "gamewrite ", "gamewrite:", "game write ", "game write:", "write game code", "draft game code", "write game ", "draft game "
    )
    private val gameWriteInfo = setOf(
        "gamewrite", "game write", "gamewrite help", "gamewrite languages", "gamewrite list", "game drafts", "workshop drafts", "gamewrite fundamentals"
    )

    /** `gamewrite <language> <file> <purpose>` — authored off the UI thread by MainActivity. */
    fun isGameWriteDraft(raw: String): Boolean {
        val lower = raw.trim().lowercase()
        if (lower in gameWriteInfo || lower.startsWith("gamewrite show ")) return false
        return gameWritePrefixes.any { lower.startsWith(it) }
    }

    fun route(raw: String, heart: NativeHeart, ctx: Context): Route {
        val text = raw.trim()
        if (text.isEmpty()) return Route(false)

        val lower = text.lowercase()

        // ---- 0.3.1 parity with Mac/iPhone: manual · game door · workshop · gamewrite · respawn · naming law ----
        when {
            lower == "manual" || lower == "yamanual" || lower == "яmanual" || lower == "open manual" || lower == "giver manual" || lower == "user giver" ->
                return Route(true, "ЯMANUAL · one fixed app manual · opened (assets/mind/books/YAMANUAL.md)", door = Door.MANUAL)
            lower == "gamewrite fundamentals" || lower == "fundamentals" ->
                return Route(true, "GAMEWRITE-FUNDAMENTALS-0.1 · opened", door = Door.MANUAL)
            lower == "workshop" || lower == "game workshop" || lower == "game builders workshop" || lower == "builders workshop" || lower == "workshop status" ->
                return Route(true, GameWorkshop.status(ctx) + "\nOpening GAME BUILDERS WORKSHOP…", door = Door.WORKSHOP)
            lower == "gamewrite" || lower == "game write" || lower == "gamewrite help" ->
                return Route(true, GameWrite.help())
            lower == "gamewrite languages" ->
                return Route(true, GameWrite.languagesLine())
            lower == "gamewrite list" || lower == "game drafts" || lower == "workshop drafts" ->
                return Route(true, GameWrite.listDrafts(ctx))
            lower.startsWith("gamewrite show ") ->
                return Route(true, GameWrite.show(ctx, text.substring("gamewrite show ".length).trim()))
            lower.startsWith("game approve") || lower.startsWith("game apply") || lower.startsWith("game reject") ||
                lower.startsWith("game respawn") || lower.startsWith("workshop respawn") ->
                return Route(true, "Decider only: Approve & Apply, Reject and Respawn are taps inside the GAME BUILDERS WORKSHOP (not chat words), so no bot, inbox line or link can apply game code. Opening the Workshop…", door = Door.WORKSHOP)
            lower == "game" || lower == "teraform" || lower == "teraformя" || lower == "я game" || lower == "yagame" || lower == "play" ->
                return Route(true, "Я Game door · Play: device copy ${GameWorkshop.base(ctx).absolutePath}/game/index.html else bundled assets/game/index.html · GAME BUILDERS WORKSHOP: yabot://game/workshop (say: workshop)\nNonNuclear: door only — no spend / auto-rewards / mint.\nCrown Я · mint ref $MINT", door = Door.GAME)
            // 0.3.3 · CLASSROOM → Garage Training lane
            lower == "classroom" || lower == "lessons" || lower == "training" || lower == "classroom status" || lower.startsWith("lesson ") ->
                return Route(true, ClassroomStore.status(ctx, BotRoster.speaking ?: BotRoster.housed().firstOrNull()?.display ?: "ЯBOT") + "\nOpening Garage → Training…", door = Door.CLASSROOM)
            lower == "garage" ->
                return Route(true, "Garage · housed bots: ${BotRoster.housed().joinToString(" · ") { it.display }} · + Create new Bot (name required) · Speak / Я speaks", door = Door.GARAGE)
            lower == "respawn" || lower == "command: respawn" || lower == "command respawn" || lower == "respawn points" || lower == "respawn list" ->
                return Route(true, RespawnInfo.text(ctx))
            lower == "who" || lower == "who am i" || lower == "labels" || lower == "label" || lower == "bots" ->
                return Route(true, BotRoster.whoStatus())
            lower == "bot leave" || lower == "leave bot" || lower == "label clear" ->
                return Route(true, BotRoster.leave())
            lower.startsWith("bot enter ") || lower == "bot enter" || lower == "bot" ->
                return Route(true, BotRoster.enter(if (lower.startsWith("bot enter ")) text.substring("bot enter ".length) else ""))
            lower.startsWith("bot mint") || lower.startsWith("bot create") || lower.startsWith("bot new") ->
                return Route(true, BotRoster.mint(text.trim().split(Regex("\\s+"), limit = 3).getOrNull(2)))
            lower == "version" || lower == "about" ->
                return Route(true, "ЯBOT Android $VERSION (versionCode $VERSION_CODE) · ALL-OS SYNC with Mac/iPhone $VERSION · mint $MINT")
            lower == "mint" ->
                return Route(true, "Mint (WalletCard): $MINT · read-only reference · the app never signs")
        }

        // Explicit bar / landing keywords
        when {
            lower == "lab" || lower.startsWith("lab ") || lower == "chamber" ->
                return Route(true, "Lab · chamber offline landing (yabot://lab/chamber)", BarRoute.LAB)
            lower == "wallet" ->
                return Route(true, "Wallet · offline landing", BarRoute.WALLET)
            lower == "mind" || lower == "machine mind" ->
                return Route(true, "Machine Mind · offline landing", BarRoute.MIND)
            lower == "home" || lower == "ghost" || lower == "ghost home" ->
                return Route(true, "Ghost Heart Home · center magnet · OFFLINE PREMIER", BarRoute.HOME)
            lower == "bolte" ->
                return Route(true, "Bolte · ЯMANUAL sole manual (in-app)", door = Door.MANUAL)
            lower == "search" ->
                return Route(true, "Search · overlay stub (offline premier; Ghost Home stays)", BarRoute.SEARCH)
            lower == "mode" || lower == "what mode" || lower == "what's the mode" || lower == "whats the mode" ->
                return Route(true, ModeStore.label, BarRoute.ONLINE, speaker = BotRoster.SYSTEM)
            lower == "online" || lower == "go online" || lower == "mode online" ->
                return Route(true, ModeStore.goOnline(), BarRoute.ONLINE, speaker = BotRoster.SYSTEM)
            lower == "offline" || lower == "go offline" || lower == "mode offline" ->
                return Route(true, ModeStore.goOffline("decider"), BarRoute.ONLINE, speaker = BotRoster.SYSTEM)
        }

        // Companion heartbeat (bare ping / pong) — NOT ICMP
        if (lower == "ping" || lower == "pong" || lower == "utah ping") {
            return Route(true, "pong · ЯBOT Android $VERSION · OFFLINE PREMIER · local mouth")
        }

        if (lower == "help" || lower == "commands" || lower == "functions" || lower == "?") {
            return Route(true, helpText(heart))
        }

        if (lower == "heart" || lower.startsWith("heart ") || lower == "heart status" || lower == "status") {
            return Route(true, heart.statusLine())
        }

        if (lower.contains("law") || lower.contains("source") || lower == "nonnuclear") {
            return Route(
                true,
                "ЯOS GIVES SOURCE VALUE. App updates from itself. NonNuclear. Offline premier is standard; online is bonus."
            )
        }

        if (lower.startsWith("evolve")) {
            return Route(true, "Evolve is Decider-gated. I cannot grant myself permission.")
        }

        // PingPong net-test tree (before Heart)
        PingPongNetTest.handleClay(text)?.let { return Route(true, it) }

        return Route(false)
    }

    fun helpText(heart: NativeHeart): String {
        return """
            |ЯBOT Android $VERSION · BASE COMMANDS (one word) · Rbot proficiency 0–10
            |HARDCODE: base = exactly one word · multi-word = extension under that base
            |Aliases: commands · functions · ? → help
            |Contract: BASE-COMMANDS-ONE-WORD-0.1.md
            |
            |SEATED HERE (Android) · word — blurb — N/10
|1  ping — companion heartbeat (bare ≠ ICMP) — 9/10
|2  pong — companion heartbeat reply — 9/10
|3  help — this list + extension hints — 8/10
|5  mind — mind loop / Machine Mind — 6/10
|8  bolte — ЯMANUAL sole manual face — 7/10
|12  respawn — list respawn points honestly (app cannot reinstall itself) — 6/10
|13  evolve — Decider-gated (never self-granted) — 4/10
|15  mode — ONLINE / OFFLINE premier status — 8/10
|16  online — online path (bonus only) — 5/10
|17  offline — affirm offline premier — 8/10
|18  search — web search (ONLINE bonus) — 5/10
|30  heart — ${heart.statusLine()} — 8/10
|31  ghost — Я GHOST CHAIN tape — 7/10
|37  lab — Lab / chamber landing — 6/10
|38  wallet — Wallet landing — 5/10
|39  home — Ghost Heart Home — 7/10
|43  who — naming law: Я Machine Mind · U human · ЯBOT/ЯMAX kids — 8/10
|44  bot — bot enter <Garage name> / bot leave (Я speaks again) / bot mint <Name> (Garage → + Create new Bot) — 8/10
|45  labels — same as who — 8/10
|46  game — Я Game door (Play · GAME BUILDERS WORKSHOP) — 6/10
|47  workshop — GAME BUILDERS WORKSHOP (Decider applies) — 6/10
|48  gamewrite — bots ЯBOT + ЯMAX draft game code (TS · JS · HTML · CSS · JSON/Schema · GLSL · MD · Swift*/Kotlin*) — 5/10
|49  manual — ЯMANUAL + GAMEWRITE-FUNDAMENTALS — 7/10
|50  garage — Garage roster (ЯBOT · ЯMAX) — 6/10
|51  classroom — Garage Training: lessons · submit (local inbox/ only) — 5/10
|52  tokenblast — read-only Я pipe probe (RPC · Jupiter · Dex · Gecko → VERDICT) — 6/10
|53  trueblast · bangrang — send legs are Mac/iOS only in 0.3.3 (probe runs here) — 2/10
            |
            |EXTENSIONS seated
            |· pingpong · PING -C N host · NSLOOKUP · host (bare ping stays heartbeat)
            |· heart status · law / source / nonnuclear
            |· gamewrite <language> <file> <purpose> [as yabot|as yamax] · gamewrite list|languages|show <id>
            |
            |MAC/iOS SEATED · NOT ON ANDROID YET (no fake handler) · N/10 from contract
| 4 think 6/10 · 6 tongue 7/10 · 7 teachings 7/10 · 9 rzl 6/10
| 10 revert 5/10 · 11 reform 5/10 · 14 snapshot 5/10
| 19 nearby 5/10 · 20 place 6/10 · 21 research 4/10 · 22 read 4/10
| 23 token 6/10 · 24 coin 6/10 · 25 mint 6/10 · 26 yacode 7/10
| 27 cos 7/10 · 28 voice 7/10 · 29 triangle 7/10 · 32 essence 6/10
| 33 teach 7/10 · 34 lock 7/10 · 35 remember 7/10 · 36 transcript 7/10
| 40 scout 6/10 · 41 shot 6/10 · 42 walis 5/10 · 44 bot mint (enter/leave seated) 8/10
            |
            |Chat with Heart when seated; else offline seat reply.
            |Offline premier is standard; online is bonus only.
        """.trimMargin()
    }

    /** Run a short ProcessBuilder command; returns stdout/stderr or FAIL. */
    fun runShell(label: String, argv: List<String>): String {
        return try {
            val pb = ProcessBuilder(argv)
                .redirectErrorStream(true)
            val proc = pb.start()
            val out = StringBuilder()
            BufferedReader(InputStreamReader(proc.inputStream)).use { br ->
                var line: String?
                while (br.readLine().also { line = it } != null) {
                    out.appendLine(line)
                }
            }
            val finished = proc.waitFor(PROC_TIMEOUT_SEC, TimeUnit.SECONDS)
            if (!finished) {
                proc.destroyForcibly()
                return "$label\nFAIL · timed out after ${PROC_TIMEOUT_SEC}s"
            }
            val body = out.toString().trim().ifEmpty { "(no output · exit ${proc.exitValue()})" }
            val status = if (proc.exitValue() == 0) "OK" else "EXIT ${proc.exitValue()}"
            "$label · $status\n$body"
        } catch (e: Exception) {
            "$label\nFAIL · ${e.message}"
        }
    }
}

/**
 * Android twin of PingPongNetTest.swift — ping / nslookup / host via Runtime where allowed.
 * Bare companion `ping` is NOT handled here (OfflineCommandRouter keeps heartbeat).
 */
object PingPongNetTest {
    const val commandName = "PINGPONG"
    const val schema = "PingPongNetTest.v1"
    private const val maxPingCount = 5
    private const val defaultPingCount = 3

    fun handleClay(raw: String): String? {
        val text = raw.trim()
        if (text.isEmpty()) return null
        val lower = text.lowercase()

        if (lower == "pingpong" || lower == "ping pong" ||
            lower == "pingpong help" || lower == "ping pong help"
        ) {
            return helpText()
        }
        if (lower.startsWith("pingpong ") || lower.startsWith("ping pong ")) {
            var rest = text
            for (p in listOf("pingpong ", "PINGPONG ", "ping pong ", "PING PONG ")) {
                if (rest.lowercase().startsWith(p.lowercase())) {
                    rest = rest.drop(p.length).trim()
                    break
                }
            }
            if (rest.isEmpty()) return helpText()
            return runBlock(rest)
        }
        if (!looksLikeNetTest(text)) return null
        return runBlock(text)
    }

    fun looksLikeNetTest(raw: String): Boolean {
        val lines = raw.lines().map { it.trim() }.filter { it.isNotEmpty() }
        if (lines.isEmpty()) return false
        if (lines.size == 1) return classifyLine(lines[0]) != null
        if (lines.any { it.lowercase().startsWith("pingpong") || it.lowercase().startsWith("ping pong") }) {
            return true
        }
        val hits = lines.count { classifyLine(it) != null }
        return hits >= 1 && hits * 2 >= lines.size
    }

    private sealed class Verb {
        data class Ping(val host: String, val count: Int) : Verb()
        data class Nslookup(val host: String) : Verb()
        data class Host(val host: String) : Verb()
    }

    private fun classifyLine(line: String): Verb? {
        val trimmed = line.trim()
        if (trimmed.isEmpty()) return null
        val lower = trimmed.lowercase()
        // Bare companion heartbeat — NEVER steal
        if (lower == "ping" || lower == "utah ping") return null

        if (lower.startsWith("pingpong ") || lower.startsWith("ping pong ")) {
            val rest = trimmed.substringAfter(' ').trim().let {
                if (lower.startsWith("ping pong ")) trimmed.drop(9).trim() else it
            }
            return classifyLine(rest)
        }

        val tokens = trimmed.split(Regex("\\s+"))
        val head = tokens.firstOrNull()?.lowercase() ?: return null
        when (head) {
            "ping" -> return parsePing(tokens.drop(1))
            "nslookup" -> {
                if (tokens.size < 2) return null
                val h = sanitizeHost(tokens[1])
                return if (h.isEmpty()) null else Verb.Nslookup(h)
            }
            "host", "dig" -> {
                if (tokens.size < 2) return null
                val h = sanitizeHost(tokens[1])
                return if (h.isEmpty()) null else Verb.Host(h)
            }
        }
        return null
    }

    private fun parsePing(tokens: List<String>): Verb? {
        var count = defaultPingCount
        var host: String? = null
        var i = 0
        while (i < tokens.size) {
            val t = tokens[i]
            val tl = t.lowercase()
            if (tl == "-c" || tl == "-n" || tl == "--count") {
                if (i + 1 < tokens.size) {
                    tokens[i + 1].toIntOrNull()?.let { count = it.coerceIn(1, maxPingCount) }
                    i += 2
                    continue
                }
            }
            if (tl.startsWith("-c") && tl.length > 2) {
                tl.drop(2).toIntOrNull()?.let { count = it.coerceIn(1, maxPingCount) }
                i++
                continue
            }
            if (t.startsWith("-")) {
                i++
                continue
            }
            if (host == null) host = sanitizeHost(t)
            i++
        }
        val h = host ?: return null
        if (h.isEmpty()) return null
        return Verb.Ping(h, count)
    }

    private fun sanitizeHost(raw: String): String {
        var s = raw.trim()
        while (s.isNotEmpty() && s.first() in "!.,;:\"'()[]{}") s = s.drop(1)
        while (s.isNotEmpty() && s.last() in "!.,;:\"'()[]{}") s = s.dropLast(1)
        if (s.isEmpty() || s.contains("://") || s.contains("/") || s.contains(" ")) return ""
        if (s.any { !(it.isLetterOrDigit() || it in ".-:_") }) return ""
        return s
    }

    private fun runBlock(text: String): String {
        val lines = text.lines().map { it.trim() }.filter { it.isNotEmpty() }
        val out = mutableListOf("$commandName · $schema · local net-test (not Heart)")
        var any = false
        for (line in lines) {
            val verb = classifyLine(line)
            if (verb == null) {
                out.add("SKIP · not a net-test verb: $line")
                continue
            }
            any = true
            out.add(runVerb(verb))
        }
        if (!any) return helpText() + "\n(no runnable net-test line in input)"
        return out.joinToString("\n\n")
    }

    private fun runVerb(verb: Verb): String = when (verb) {
        is Verb.Ping -> ping(verb.host, verb.count)
        is Verb.Nslookup -> dnsLookup(verb.host, digStyle = false)
        is Verb.Host -> dnsLookup(verb.host, digStyle = true)
    }

    private fun ping(host: String, count: Int): String {
        val n = count.coerceIn(1, maxPingCount)
        // Android emulator usually has /system/bin/ping
        val tryPaths = listOf(
            listOf("ping", "-c", "$n", "-W", "2", host),
            listOf("/system/bin/ping", "-c", "$n", "-W", "2", host)
        )
        for (argv in tryPaths) {
            val r = OfflineCommandRouter.runShell("PING · $host · count $n", argv)
            if (!r.contains("FAIL ·") || r.contains("EXIT")) return r
            if (!r.contains("No such file") && !r.contains("error=2") && !r.contains("Cannot run")) {
                return r
            }
        }
        // Fallback: InetAddress.isReachable (ICMP if permitted, else TCP echo heuristic)
        return try {
            val lines = mutableListOf("PING · $host · count $n · InetAddress fallback")
            var ok = 0
            repeat(n) { i ->
                val start = System.currentTimeMillis()
                val reachable = InetAddress.getByName(host).isReachable(2000)
                val ms = System.currentTimeMillis() - start
                if (reachable) {
                    ok++
                    lines.add("seq ${i + 1}: ok · ${ms}ms")
                } else {
                    lines.add("seq ${i + 1}: fail · unreachable/${ms}ms")
                }
            }
            lines.add("--- $n probes, $ok ok · $schema")
            lines.joinToString("\n")
        } catch (e: Exception) {
            "PING · $host · FAIL · ${e.message}"
        }
    }

    private fun dnsLookup(host: String, digStyle: Boolean): String {
        val label = if (digStyle) "DIG/HOST" else "NSLOOKUP"
        // Prefer getaddrinfo via InetAddress (always available offline-capable for local/cache)
        return try {
            val addrs = InetAddress.getAllByName(host)
            if (addrs.isEmpty()) {
                "$label · $host · FAIL · no addresses"
            } else {
                "$label · $host · OK\n" + addrs.joinToString("\n") { it.hostAddress ?: it.toString() }
            }
        } catch (e: Exception) {
            // Optional shell fallback
            val shell = OfflineCommandRouter.runShell(label, listOf("nslookup", host))
            if (!shell.contains("FAIL ·")) shell else "$label · $host · FAIL · ${e.message}"
        }
    }

    fun helpText(): String = """
        |$commandName · $schema
        |Local device network TEST (offline-premier companion stays Heart; these are Decider test probes).
        |Verbs:
        |  ping [-c N] <host>     count capped $maxPingCount (default $defaultPingCount)
        |  nslookup <host>
        |  host / dig <host>
        |  pingpong <verb…>       explicit tree root
        |Examples:
        |  PING -C 3 1.1.1.1
        |  NSLOOKUP EXAMPLE.COM
        |  pingpong ping -c 2 127.0.0.1
        |Note: bare `ping` still means companion heartbeat → pong (not ICMP).
    """.trimMargin()
}
