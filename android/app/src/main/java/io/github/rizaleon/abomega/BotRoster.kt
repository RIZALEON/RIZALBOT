package io.github.rizaleon.abomega

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * NAMING LAW (Decider 2026-09-24 17:12 MDT) — Android twin of Swift BotLabel (BotLabels.v3) + WorkshopAuthors v2.
 *   Я  = the MACHINE MIND itself, speaking with all of its components behind it — never numbered/renamed
 *   U  = the human (biological source)
 *   Bots = Я's extensions / digital robot kids. In chat a bot speaks with its DESIGNATED NAME exactly as the
 *          Garage presents it (today ЯBOT · ЯMAX). No ЯBOT#N numbers are shown.
 * Garage roster (single source of names/faces/aliases) = <ext>/ЯBOT/seat/BOT-LABELS.json (schema BotLabels.v3
 * `roster` + `bots` mirror + `currentGuestLabel`), seeded once from assets/seat/BOT-LABELS.json (copy of the Mac
 * seat file at build time). <ext>/ЯBOT/game/workshop/authors.json (v2) only says WHICH roster bots have gamewrite.
 * Both files are editable on the device without a rebuild. Reserved / numbered / 'Garage' / clashing names are REFUSED.
 * Garage → + Create new Bot (and `bot mint <Name>`) append to the roster with the typed name, verbatim.
 */
object BotRoster {
    const val MIND = "Я"
    const val USER = "U"
    const val SYSTEM = "system"
    const val SCHEMA = "BotLabels.v3"
    private const val LEGACY_PREFIX = "ЯBOT#"
    private val reserved = setOf("u", "user", "human", "system", "clay", "я", "ya", "machine mind")

    data class Bot(
        val id: String,
        val display: String,          // designated Garage name = chat label, verbatim
        val face: String?,
        val look: String,
        val aliases: List<String>,
        val formerNames: List<String>,
        val housed: Boolean,
        val shelf: String?,
        val gamewrite: Boolean,
        /** LEGACY TITLE RULE (Decider 17:43): pre-naming-law titles (e.g. ЯBOT#2) keep their name, bound to origin. */
        val legacy: Boolean = false,
        val origin: String? = null,
        val boundAt: String? = null
    ) {
        fun faceRes(): Int? = when (face?.lowercase()) {
            "botfaceyamax" -> R.drawable.botface_yamax
            "botfaceyabot" -> R.drawable.botface_yabot
            else -> when (id) { "yamax" -> R.drawable.botface_yamax; "yabot" -> R.drawable.botface_yabot; else -> null }
        }

        fun names(): List<String> = listOf(id, display) + aliases + formerNames
    }

    private val seedRoster = listOf(
        Bot("yabot", "ЯBOT", "BotFaceYaBot", "blue clay face · red horns · black bat wings",
            listOf("yabot", "ябот", "rbot", "я bot"), listOf("Scout"), true, "left", true),
        Bot("yamax", "ЯMAX", "BotFaceYaMax", "white Baymax-style clay face · shelf companion",
            listOf("yamax", "ямакс", "rmax", "я max"), emptyList(), true, "right", true)
    )
    private var defaultId = "yabot"
    private var cached: List<Bot>? = null
    private var appCtx: Context? = null
    private val lock = Any()

    /** Bot currently speaking for assistant stamps (its exact Garage name); null = Я. Persisted as currentGuestLabel. */
    @Volatile var speaking: String? = null
        private set

    fun init(ctx: Context) {
        appCtx = ctx.applicationContext
        cached = null
        speaking = try {
            ensureSeated(ctx)
            val o = JSONObject(seatFile(ctx).readText(Charsets.UTF_8))
            val g = if (o.isNull("currentGuestLabel")) "" else o.optString("currentGuestLabel", "")
            g.ifBlank { null }?.takeIf { name -> roster().any { it.display == name } }
        } catch (_: Exception) { null }
    }

    fun seatFile(ctx: Context): File = File(GameWorkshop.base(ctx), "seat/BOT-LABELS.json")
    fun authorsFile(ctx: Context): File = File(GameWorkshop.root(ctx), "authors.json")

    /** Seat roster + authors once from assets (never overwrites the Decider's edits). */
    fun ensureSeated(ctx: Context) {
        seedOnce(ctx, "seat/BOT-LABELS.json", seatFile(ctx))
        seedOnce(ctx, "game/workshop/authors.json", authorsFile(ctx))
    }

    private fun seedOnce(ctx: Context, asset: String, f: File) {
        if (f.exists()) return
        f.parentFile?.mkdirs()
        try {
            ctx.assets.open(asset).use { input -> f.outputStream().use { input.copyTo(it) } }
        } catch (_: Exception) {
        }
    }

    private fun strList(o: JSONObject, key: String): List<String> {
        val a = o.optJSONArray(key) ?: return emptyList()
        return (0 until a.length()).map { a.optString(it) }.filter { it.isNotBlank() }
    }

    fun norm(s: String) = s.trim().lowercase()

    private fun isoNow(): String = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        .apply { timeZone = TimeZone.getTimeZone("UTC") }.format(Date())

    /** Garage roster (all bots, incl. ones without gamewrite). */
    fun roster(): List<Bot> {
        cached?.let { return it }
        val ctx = appCtx ?: return seedRoster
        ensureSeated(ctx)
        // which ids have gamewrite (authors.json v2 `gamewrite` · v1 `authors[].id`)
        var gw: Set<String>? = null
        try {
            val a = JSONObject(authorsFile(ctx).readText(Charsets.UTF_8))
            defaultId = a.optString("defaultAuthor", "yabot").ifEmpty { "yabot" }
            if (a.has("gamewrite")) {
                gw = strList(a, "gamewrite").map { norm(it) }.toSet()
            } else if (a.has("authors")) {
                val arr = a.getJSONArray("authors")
                gw = (0 until arr.length()).map { arr.getJSONObject(it) }
                    .filter { it.optBoolean("gamewrite", true) }.map { norm(it.optString("id")) }.toSet()
            }
        } catch (_: Exception) {
        }
        val list = try {
            val o = JSONObject(seatFile(ctx).readText(Charsets.UTF_8))
            val arr = o.optJSONArray("roster")
            if (arr == null) emptyList() else (0 until arr.length()).map { i ->
                val b = arr.getJSONObject(i)
                val id = b.optString("id")
                Bot(
                    id = id,
                    display = b.optString("name"),
                    face = if (b.isNull("face")) null else b.optString("face", "").ifEmpty { null },
                    look = if (b.isNull("look")) "" else b.optString("look", ""),
                    aliases = strList(b, "aliases"),
                    formerNames = strList(b, "formerNames"),
                    housed = b.optBoolean("housed", true),
                    shelf = if (b.isNull("shelf")) null else b.optString("shelf", "").ifEmpty { null },
                    gamewrite = gw?.contains(norm(id)) ?: true,
                    legacy = b.optBoolean("legacy", false),
                    origin = if (b.isNull("origin")) null else (b.opt("origin")?.toString()?.ifEmpty { null }),
                    boundAt = if (b.isNull("boundAt")) null else b.optString("boundAt", "").ifEmpty { null }
                )
            }.filter { it.display.isNotBlank() && it.id.isNotBlank() }.let { r ->
                // `bots` names registered before the naming law with no roster row → legacy titles (not housed)
                val extra = mutableListOf<Bot>()
                val bm = o.optJSONObject("bots")
                if (bm != null) for (k in bm.keys()) {
                    val disp = bm.optString(k).trim()
                    if (disp.isEmpty()) continue
                    val known = (r + extra).any { b -> b.names().any { norm(it) == norm(disp) } }
                    if (!known) extra.add(Bot(slug(disp).ifEmpty { "legacy${r.size + extra.size + 1}" }, disp, null,
                        "registered before the naming law", emptyList(), emptyList(), false, null, false, legacy = true))
                }
                r + extra
            }
        } catch (_: Exception) {
            emptyList()
        }
        val out = list.ifEmpty { seedRoster.map { it.copy(gamewrite = gw?.contains(it.id) ?: true) } }
        cached = out
        return out
    }

    fun reload() { cached = null }

    fun housed(): List<Bot> = roster().filter { it.housed }

    /** Roster bots with gamewrite. */
    fun writers(): List<Bot> = roster().filter { it.gamewrite }

    fun defaultBot(): Bot? = writers().firstOrNull { norm(it.id) == norm(defaultId) || norm(it.display) == norm(defaultId) } ?: writers().firstOrNull()

    /** Any roster bot by id / Garage name / alias / former name (case-insensitive). */
    fun rosterBot(named: String): Bot? {
        val raw = named.trim()
        if (raw.isEmpty()) return null
        roster().firstOrNull { it.display == raw }?.let { return it }
        val l = norm(raw)
        return roster().firstOrNull { b -> b.names().any { norm(it) == l } }
    }

    /** Gamewrite author: empty → default; unknown or not-gamewrite → null (REFUSED). */
    fun resolve(raw: String): Bot? {
        if (raw.isBlank()) return defaultBot()
        val b = rosterBot(raw) ?: return null
        return writers().firstOrNull { it.id == b.id }
    }

    fun refusal(raw: String): String {
        val t = raw.trim()
        rosterBot(t)?.let { return "${it.display} is in the Garage but has no gamewrite (authors.json). Gamewrite authors: ${namesLine()}." }
        if (norm(t) == "garage") return "'garage' is the Garage (the workshop / bot builder), not a bot. Gamewrite authors: ${namesLine()}."
        if (isReserved(t)) return "'$t' is reserved (U / Я / system) — not a bot. Gamewrite authors: ${namesLine()}."
        return "'$t' is not a bot in the Garage roster. Gamewrite authors: ${namesLine()}."
    }

    /** For display incl. former names, so old drafts still show a face. */
    fun lookup(display: String): Bot? = rosterBot(display)

    fun namesLine(): String = writers().joinToString(" · ") { it.display }.ifEmpty { "(none — set gamewrite ids in authors.json)" }
    fun rosterNamesLine(): String = roster().joinToString(" · ") { it.display }.ifEmpty { "(none yet)" }

    fun aliasWords(): List<String> = roster().flatMap { it.names() }

    // MARK: naming rules (Swift BotLabel.nameProblem twin)

    private fun isReserved(name: String): Boolean {
        val n = name.trim()
        return n == MIND || norm(n) in reserved
    }

    private fun isBareBotToken(name: String): Boolean = norm(name) in setOf("bot", "a bot", "new bot")

    private fun parseCreatedSerial(label: String): Int? {
        val lower = norm(label)
        for (m in listOf("яbot#", "yabot#")) {
            if (lower.startsWith(m)) lower.substring(m.length).toIntOrNull()?.let { if (it > 0) return it }
        }
        return null
    }

    /** null = name is fine. Otherwise a REFUSED message. */
    fun nameProblem(name: String, excludingId: String?): String? {
        if (isReserved(name)) return "REFUSED · '$name' is reserved (U / Я / system). Pick the bot's own name."
        if (parseCreatedSerial(name) != null) return "REFUSED · numbered names like ${LEGACY_PREFIX}N are retired (naming law 2026-09-24). Give the bot its own name."
        if (name.length > 40) return "REFUSED · name too long (40 max)."
        if (norm(name) == "garage") return "REFUSED · Garage is the workshop place / bot builder, not a bot. (Only the Decider can house a bot called Garage, by adding it to the roster in seat/BOT-LABELS.json.)"
        val want = norm(name)
        for (b in roster()) {
            if (b.id == excludingId) continue
            if (b.names().any { norm(it) == want }) return "REFUSED · '$name' is already taken by ${b.display}. No two bots share a name."
        }
        return null
    }

    private fun slug(name: String): String {
        val map = mapOf('я' to "ya", 'ж' to "zh", 'ш' to "sh", 'ч' to "ch", 'ю' to "yu")
        val sb = StringBuilder()
        for (ch in name.lowercase()) {
            val m = map[ch]
            if (m != null) { sb.append(m); continue }
            if (ch.code < 128 && ch.isLetterOrDigit()) sb.append(ch)
        }
        return sb.toString()
    }

    // MARK: persistence (keeps every other key in the seat file; `bots` mirror = roster names, like Swift save())

    private fun readSeat(ctx: Context): JSONObject = try {
        JSONObject(seatFile(ctx).readText(Charsets.UTF_8))
    } catch (_: Exception) {
        JSONObject().put("schema", SCHEMA).put("claySeatLabel", MIND).put("roster", JSONArray())
            .put("rosterSeeded", false).put("nextCreatedSerial", 1)
    }

    private fun writeSeat(ctx: Context, o: JSONObject) {
        o.put("schema", SCHEMA)
        o.put("claySeatLabel", MIND)
        val arr = o.optJSONArray("roster") ?: JSONArray()
        // merge, never drop: older/legacy `bots` entries stay (LEGACY TITLE RULE), roster names are added
        val mirror = o.optJSONObject("bots") ?: JSONObject()
        for (i in 0 until arr.length()) {
            val n = arr.optJSONObject(i)?.optString("name").orEmpty()
            if (n.isNotBlank()) mirror.put(norm(n), n)
        }
        o.put("bots", mirror)
        o.put("updatedAt", isoNow())
        val f = seatFile(ctx)
        f.parentFile?.mkdirs()
        f.writeText(o.toString(2).replace("\\/", "/"), Charsets.UTF_8)
        cached = null
    }

    private fun persistGuest(name: String?) {
        val ctx = appCtx ?: return
        synchronized(lock) {
            try {
                val o = readSeat(ctx)
                if (name == null) o.put("currentGuestLabel", JSONObject.NULL) else o.put("currentGuestLabel", name)
                writeSeat(ctx, o)
            } catch (_: Exception) {
            }
        }
    }

    /** Garage → + Create new Bot (and `bot mint <Name>`). The given name is the designated name, verbatim. */
    fun createBot(raw: String): Pair<Bot?, String> {
        val name = raw.trim()
        if (name.isEmpty() || isBareBotToken(name)) {
            return null to "REFUSED · no anonymous bots. Give it the name it will speak with (Garage → + Create new Bot, or: bot mint <Name>)."
        }
        nameProblem(name, null)?.let { return null to it }
        val ctx = appCtx ?: return null to "REFUSED · Garage not ready yet; try again."
        synchronized(lock) {
            val o = readSeat(ctx)
            val arr = o.optJSONArray("roster") ?: JSONArray().also { o.put("roster", it) }
            var maxSerial = 0
            val ids = mutableSetOf<String>()
            for (i in 0 until arr.length()) {
                val b = arr.optJSONObject(i) ?: continue
                maxSerial = maxOf(maxSerial, b.optInt("serial", 0))
                ids.add(b.optString("id"))
            }
            val serial = maxOf(1, o.optInt("nextCreatedSerial", 1), maxSerial + 1)
            var id = slug(name).ifEmpty { "bot$serial" }
            val base = id
            var n = 2
            while (id in ids) { id = "$base$n"; n++ }
            arr.put(JSONObject()
                .put("id", id).put("name", name)
                .put("aliases", JSONArray()).put("formerNames", JSONArray())
                .put("housed", true).put("serial", serial).put("createdAt", isoNow())
                .put("createdOn", "android"))
            o.put("nextCreatedSerial", serial + 1)
            o.put("rosterSeeded", true)
            writeSeat(ctx, o)
        }
        val bot = rosterBot(name)
        return bot to "Created in the Garage · $name\nIt speaks in chat as $name. Я stays the Machine Mind." +
            "\n(gamewrite: add \"${bot?.id ?: name}\" to authors.json `gamewrite` — Decider)"
    }

    /** `bot mint` / `bot create` / `bot new` <Name> — create in the roster, then it speaks. */
    fun mint(optionalName: String?): String {
        val raw = optionalName?.trim().orEmpty()
        if (raw.isEmpty() || isBareBotToken(raw)) {
            return "REFUSED · no auto numbers and no anonymous bots (naming law 2026-09-24).\n" +
                "Name the bot as the Garage will present it: bot mint <Name> — or Garage → + Create new Bot.\n" +
                "Housed now: ${rosterNamesLine()}."
        }
        rosterBot(raw)?.let { return "'$raw' is already in the Garage as ${it.display}. To let it speak: bot enter ${it.display}" }
        val (bot, msg) = createBot(raw)
        if (bot == null) return msg
        speaking = bot.display
        persistGuest(bot.display)
        return msg + "\nAssistant stamps → ${bot.display} until `bot leave`."
    }

    /** `bot enter <Name>` — a Garage bot speaks (assistant stamps = its exact Garage name). Я / clay → Machine Mind. */
    fun enter(raw: String): String {
        val t = raw.trim()
        if (t.isEmpty() || isBareBotToken(t)) return "HOW: bot enter <Name> — a bot from the Garage roster: ${rosterNamesLine()}. No anonymous bots."
        if (t == MIND || norm(t) == "clay" || norm(t) == "machine mind") {
            speaking = null
            persistGuest(null)
            return "Я — the Machine Mind — speaks. Assistant stamps = Я."
        }
        if (isReserved(t)) return "REFUSED · '$t' is reserved (U / Я / system). Bots speak with their Garage names: ${rosterNamesLine()}."
        val b = rosterBot(t) ?: run {
            if (parseCreatedSerial(t) != null) return "REFUSED · numbered names like ${LEGACY_PREFIX}N are retired (naming law 2026-09-24) unless the Garage roster holds that legacy title. Garage bots: ${rosterNamesLine()}."
            if (norm(t) == "garage") return "REFUSED · Garage is the workshop place / bot builder, not a bot. Garage bots: ${rosterNamesLine()}."
            return "REFUSED · '$t' is not in the Garage roster (${rosterNamesLine()}). Create it first: Garage → + Create new Bot, or bot mint $t."
        }
        if (speaking == b.display) return "Already speaking · ${b.display}\nAssistant stamps → ${b.display}."
        speaking = b.display
        persistGuest(b.display)
        return "${b.display} speaks now (one of Я's bots).\nAssistant stamps → ${b.display} until `bot leave`."
    }

    fun leave(): String {
        val was = speaking
        speaking = null
        persistGuest(null)
        return if (was != null) "Left · $was\nЯ — the Machine Mind — speaks again." else "No bot speaking. Я — the Machine Mind — speaks."
    }

    /** Label for assistant turns (Heart replies etc.). */
    fun assistantLabel(): String = speaking ?: MIND

    fun whoStatus(): String {
        val lines = mutableListOf(
            "NAMING LAW (Decider 2026-09-24):",
            "  $USER  = biological source (human prompts)",
            "  $MIND  = the Machine Mind itself, with all of its components behind it — never numbered",
            "  bots = Я's extensions / digital robot kids — they speak with their Garage names",
            "  no anonymous bots · no two bots share a name · no ЯBOT#N numbers as names",
            "",
            "Machine Mind = $MIND",
            "human = $USER",
            "speaking bot = ${speaking ?: "(none — Я speaks)"}",
            "Garage roster:"
        )
        val r = roster()
        if (r.isEmpty()) lines.add("  (empty — Garage → + Create new Bot)")
        for (b in r) {
            val mark = if (b.display == speaking) " ★" else ""
            val look = if (b.look.isNotBlank()) " — ${b.look}" else ""
            lines.add("  ${b.display}$look$mark${if (b.gamewrite) " · gamewrite" else ""}${if (b.housed) "" else " · not housed"}${if (b.legacy) " · legacy title" + (b.origin?.let { " (bound to $it)" } ?: "") else ""}")
        }
        lines.add("verbs: bot enter <Name> · bot leave · bot mint <Name> · Garage → + Create new Bot")
        appCtx?.let { lines.add("roster file: ${seatFile(it).absolutePath}") }
        return lines.joinToString("\n")
    }
}
