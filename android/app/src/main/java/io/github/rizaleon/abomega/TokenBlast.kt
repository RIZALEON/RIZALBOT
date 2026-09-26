package io.github.rizaleon.abomega

import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * TOKENBLAST (Android 0.3.3) — Kotlin port of the Mac/iOS TokenBlastProbe. READ-ONLY probe:
 * Solana RPC getAccountInfo + getTokenSupply · Jupiter lite · Dexscreener · GeckoTerminal →
 * PERFECTION / PECULIARITY / STRANGENESS + VERDICT. No wallet, no signing, no transfer, no keys.
 * Run it OFF the UI thread (network). Explorers are mirrors — clay owns source.
 */
object TokenBlast {
    const val MINT = "BB9uA5BuacDnWyDf5Npc9nMb9yFbyThsNrQPBYJ5Q1Lv"
    const val AUTHORITY = "BwpVNk1Rtncpv5HMTLwxB4Yfjkfv6mFaBQUTpjneH1F9"
    const val ATA = "8bCnr63CTdC2YbELK3x4vxJYNt6cueGBbEvRURFZc9Q1"
    const val MINT_TX = "2Lxr2mEZnFnwwBMQjCgRt8EJLaJbwEp61K51mdx16z8oncWg2JCXzCKnisMi78V3L4w7w2pizQ8P1p2H5XMLvx94"
    const val DECIMALS = 9
    const val SUPPLY_UI = "1000000"
    private const val RPC = "https://api.mainnet-beta.solana.com"

    private val verbs = listOf("tokenblast", "token blast", "blast token", "blast twin", "twin blast")

    fun matches(lower: String): Boolean = verbs.any { lower == it || lower.startsWith("$it ") }

    fun argFrom(text: String): String? {
        val lower = text.lowercase()
        for (v in verbs) if (lower.startsWith("$v ")) return text.substring(v.length).trim().ifEmpty { null }
        return null
    }

    fun run(mintArg: String?, online: Boolean): String {
        val mint = mintArg?.trim()?.takeIf { it.isNotEmpty() } ?: MINT
        val purpose = "Purpose: shove the twin through live digital plumbing and read every mirror."
        val intent = "Intent: track·trace·verify — report perfection / peculiarity / strangeness on the way back. No spend."
        if (mint.length !in 32..44) return "TOKENBLAST FAIL\n$purpose\n$intent\nMint looks wrong: $mint\nHOW: tokenblast   OR   tokenblast <mintAddress>"
        val lines = mutableListOf("TOKENBLAST · Solana mainnet (Android)", purpose, intent, "Target mint: $mint", "Crown seat: Я / Я",
            "Mode: ${if (online) "ONLINE (live pipes)" else "OFFLINE (hardcoded twin + local seats only)"}", "")
        val perfect = mutableListOf<String>(); val peculiar = mutableListOf<String>(); val strange = mutableListOf<String>()
        if (mint == MINT) perfect += "Mint matches hardcoded crown seat." else peculiar += "Blast mint ≠ seated crown twin. Citing Decider-pasted mint."

        if (!online) {
            lines += "PIPE · offline"
            lines += "  Skipped live RPC/Dex/Jupiter — flip ONLINE to blast the rails."
            lines += "  Local twin: supply $SUPPLY_UI · decimals $DECIMALS · status finalized"
            lines += "  ATA $ATA"
            lines += "  Mint tx $MINT_TX"
            strange += "Blast ran offline — mirrors not queried this turn."
            return finish(lines, perfect, peculiar, strange)
        }

        val acct = rpc("getAccountInfo", JSONArray().put(mint).put(JSONObject().put("encoding", "jsonParsed")))
        val value = acct?.optJSONObject("result")?.optJSONObject("value")
        if (value != null) {
            val owner = value.optString("owner", "?")
            if (owner.contains("Token")) perfect += "RPC: mint account live under SPL Token program."
            else strange += "RPC: account owner is not Token program (${owner.take(16)}…)."
            val info = value.optJSONObject("data")?.optJSONObject("parsed")?.optJSONObject("info")
            if (info != null) {
                val dec = info.optInt("decimals", -1)
                val supply = info.optString("supply", "?")
                val mintAuth = if (info.isNull("mintAuthority")) "null" else info.optString("mintAuthority")
                val freeze = if (info.isNull("freezeAuthority")) "null" else info.optString("freezeAuthority")
                lines += "PIPE · Solana RPC (getAccountInfo)"
                lines += "  decimals $dec · supply_raw $supply"
                lines += "  mintAuthority $mintAuth"
                lines += "  freezeAuthority $freeze"
                if (dec == DECIMALS) perfect += "RPC decimals match crown seat ($dec)." else peculiar += "RPC decimals $dec ≠ crown $DECIMALS."
                when {
                    mintAuth == AUTHORITY -> perfect += "Mint authority matches crown seat."
                    mintAuth == "null" -> peculiar += "Mint authority renounced (null) — supply locked."
                    else -> peculiar += "Mint authority differs from crown seat."
                }
                if (freeze != "null") peculiar += "Freeze authority still set." else perfect += "Freeze authority null."
            }
        } else if (acct?.has("error") == true) {
            strange += "RPC getAccountInfo error: ${acct.opt("error")}"
            lines += "PIPE · Solana RPC — FAIL"
        } else {
            strange += "RPC returned no mint account — explorers may say not found."
            lines += "PIPE · Solana RPC — account NULL"
        }

        val sup = rpc("getTokenSupply", JSONArray().put(mint))?.optJSONObject("result")?.optJSONObject("value")
        if (sup != null) {
            val ui = sup.optString("uiAmountString", "?")
            lines += "PIPE · Solana RPC (getTokenSupply) → $ui"
            if (ui.startsWith(SUPPLY_UI)) perfect += "Supply $ui matches crown seat." else peculiar += "Supply $ui ≠ crown $SUPPLY_UI."
        } else strange += "getTokenSupply empty/fail."

        lines += "PIPE · Jupiter lite search"
        val jup = get("https://lite-api.jup.ag/tokens/v2/search?query=$mint")
        val arr = jup?.let { runCatching { JSONArray(it) }.getOrNull() }
        if (arr != null) {
            var hit: JSONObject? = null
            for (i in 0 until arr.length()) { val o = arr.optJSONObject(i); if (o?.optString("id") == mint) { hit = o; break } }
            if (hit == null && arr.length() > 0) hit = arr.optJSONObject(0)
            if (hit != null) {
                val name = hit.optString("name", ""); val sym = hit.optString("symbol", "")
                val holders = hit.opt("holderCount")
                lines += "  name '$name' · symbol '$sym' · supply ${hit.opt("circSupply") ?: hit.opt("totalSupply") ?: "?"} · holders ${holders ?: "?"}"
                lines += "  organicScore ${hit.opt("organicScore") ?: "?"}"
                when {
                    name == "Я" -> perfect += "Jupiter shows crown name Я."
                    name.isEmpty() -> peculiar += "Jupiter indexes mint but name/symbol blank (URI empty or lag)."
                    else -> strange += "Jupiter name '$name' ≠ crown Я."
                }
                val h = (holders as? Number)?.toInt()
                if (h == 1) {
                    perfect += "Single holder — full supply on seat ATA (pre-pool)."
                } else if (h != null && h > 1) {
                    peculiar += "Holder count $h — twin moved beyond single seat."
                }
            } else { peculiar += "Jupiter returned no exact mint hit yet."; lines += "  (no exact hit)" }
        } else { strange += "Jupiter lite unreachable from this seat."; lines += "  unreachable" }

        lines += "PIPE · Dexscreener"
        val dex = get("https://api.dexscreener.com/latest/dex/tokens/$mint")?.let { runCatching { JSONObject(it) }.getOrNull() }
        if (dex != null) {
            val pairs = dex.optJSONArray("pairs")
            if (pairs == null || pairs.length() == 0) { lines += "  pairs: null/empty"; perfect += "Dexscreener quiet — no pool yet (expected)." }
            else { lines += "  pairs: ${pairs.length()}"; peculiar += "Dexscreener has ${pairs.length()} pair(s) — market plumbing awake." }
        } else { strange += "Dexscreener unreachable."; lines += "  unreachable" }

        lines += "PIPE · GeckoTerminal"
        val gecko = get("https://api.geckoterminal.com/api/v2/networks/solana/tokens/$mint")?.let { runCatching { JSONObject(it) }.getOrNull() }
        if (gecko != null) {
            if (gecko.has("errors")) { lines += "  not listed / errors"; perfect += "GeckoTerminal unlisted — fine pre-pool." }
            else { lines += "  listed"; peculiar += "GeckoTerminal already lists this mint." }
        } else { lines += "  no clean payload (often 404)"; peculiar += "GeckoTerminal did not return a clean token payload." }

        lines += "PIPE · Clay seat (WalletCard)"
        lines += "  ATA $ATA"
        lines += "  mint tx $MINT_TX"
        return finish(lines, perfect, peculiar, strange)
    }

    private fun finish(lines: MutableList<String>, perfect: List<String>, peculiar: List<String>, strange: List<String>): String {
        lines += ""
        lines += "ALONG THE WAY"
        lines += "  PERFECTION (${perfect.size})"; if (perfect.isEmpty()) lines += "    — none noted" else perfect.forEach { lines += "    ✓ $it" }
        lines += "  PECULIARITY (${peculiar.size})"; if (peculiar.isEmpty()) lines += "    — none noted" else peculiar.forEach { lines += "    ~ $it" }
        lines += "  STRANGENESS (${strange.size})"; if (strange.isEmpty()) lines += "    — none noted" else strange.forEach { lines += "    ! $it" }
        val verdict = when {
            strange.isNotEmpty() && perfect.isEmpty() -> "VERDICT: strange — twin may be missing or pipes clogged."
            strange.isNotEmpty() -> "VERDICT: mixed — live on rail, some mirrors clogged or lagging."
            peculiar.isNotEmpty() -> "VERDICT: peculiar-but-alive — on rail; oddities mostly index/pool lag."
            else -> "VERDICT: perfection path — mint live, seats agree, quiet markets as expected."
        }
        lines += ""; lines += verdict
        lines += "Law: explorers are mirrors — clay owns source. Crown Я."
        return lines.joinToString("\n")
    }

    private fun rpc(method: String, params: JSONArray): JSONObject? {
        val body = JSONObject().put("jsonrpc", "2.0").put("id", 1).put("method", method).put("params", params).toString()
        return http(RPC, body)?.let { runCatching { JSONObject(it) }.getOrNull() }
    }

    private fun get(url: String): String? = http(url, null)

    private fun http(url: String, postBody: String?): String? = try {
        val c = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 12000; readTimeout = 12000
            setRequestProperty("User-Agent", "YaBOT-TOKENBLAST/1.0 (Android)")
            if (postBody != null) {
                requestMethod = "POST"; doOutput = true
                setRequestProperty("Content-Type", "application/json")
                outputStream.use { it.write(postBody.toByteArray()) }
            }
        }
        val code = c.responseCode
        val s = (if (code in 200..299) c.inputStream else c.errorStream)?.bufferedReader()?.use { it.readText() }
        c.disconnect()
        s
    } catch (e: Exception) { null }
}
