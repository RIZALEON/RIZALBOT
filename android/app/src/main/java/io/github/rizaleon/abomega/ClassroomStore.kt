package io.github.rizaleon.abomega

import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * ЯBOT CLASSROOM (Android 0.3.3) — Garage → Training lane (GARAGE-CLASSROOM-LINK-PROPOSAL.md).
 * Root = GameWorkshop.base(ctx)/classroom (<externalFilesDir>/ЯBOT/classroom). Lessons: seated copy there
 * (sha256 must match the manifest) else bundled assets/classroom. The app never runs lesson steps, never scores
 * its own bot, never pushes: Submit writes ONE new inbox/ file + a CLASSROOM-LEDGER.jsonl row. Local only.
 */
object ClassroomStore {
    data class Lesson(val id: String, val title: String, val readOnly: Boolean, val requires: List<String>,
                      val purpose: String, val steps: List<String>, val mustInclude: List<String>)

    fun root(ctx: Context): File = File(GameWorkshop.base(ctx), "classroom")

    /** rizal.pw = shared bot classroom / garage workshop. Primary → Pages fallback → raw(main). Offline = seated copy / assets
     *  (Android has no ~/Documents clone). rizal.pw DNS is moving to GitHub Pages; until then it redirects to an HTML page,
     *  so a base only counts if its manifest.json parses with schema rbot.classroom.manifest.v1. */
    const val PRIMARY_URL = "https://rizal.pw/classroom/"
    const val FALLBACK_URL = "https://rizaleon.github.io/rizal-pw/classroom/"
    const val RAW_BASE = "https://raw.githubusercontent.com/RIZALEON/rizal-pw/main/classroom/"
    val ONLINE_BASES = listOf(PRIMARY_URL, FALLBACK_URL, RAW_BASE)
    const val MANIFEST_SCHEMA = "rbot.classroom.manifest.v1"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences("classroom", Context.MODE_PRIVATE)
    fun activeBase(ctx: Context): String? = prefs(ctx).getString("activeBase", null)
    fun webUrl(ctx: Context): String = activeBase(ctx)?.takeIf { it != RAW_BASE } ?: PRIMARY_URL

    private fun httpGet(url: String): ByteArray? = try {
        val c = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 8000; readTimeout = 8000; instanceFollowRedirects = true; useCaches = false
        }
        try { if (c.responseCode == 200) c.inputStream.use { it.readBytes() } else null } finally { c.disconnect() }
    } catch (e: Exception) { null }

    /** Read-only GET. Call OFF the main thread. First base with a valid manifest wins; lessons seated only if sha256 match. */
    fun refresh(ctx: Context): String {
        val tried = mutableListOf<String>()
        for (base in ONLINE_BASES) {
            tried += base
            val data = httpGet(base + "manifest.json") ?: continue
            val m = runCatching { JSONObject(String(data)) }.getOrNull() ?: continue
            if (m.optString("schema") != MANIFEST_SCHEMA) continue
            prefs(ctx).edit().putString("activeBase", base).apply()
            val r = root(ctx)
            var n = 0
            val arr = m.optJSONArray("lessons")
            for (i in 0 until (arr?.length() ?: 0)) {
                val e = arr!!.optJSONObject(i) ?: continue
                val path = e.optString("path"); val want = e.optString("sha256")
                if (path.isEmpty() || want.isEmpty() || path.contains("..")) continue
                val b = httpGet(base + path) ?: continue
                if (sha256(b) == want) { File(r, path).apply { parentFile?.mkdirs() }.writeBytes(b); n++ }
            }
            r.mkdirs(); File(r, "manifest.json").writeBytes(data)
            return "Refresh via $base: $n lesson(s) verified by sha256 and seated."
        }
        return "Refresh: no valid manifest at ${tried.joinToString(" · ")} — using seated/bundled lessons."
    }

    fun openWeb(ctx: Context) {
        runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(webUrl(ctx))).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
    }

    private fun read(ctx: Context, rel: String): ByteArray? {
        val f = File(root(ctx), rel)
        if (f.isFile) return f.readBytes()
        return try { ctx.assets.open("classroom/$rel").use { it.readBytes() } } catch (e: Exception) { null }
    }

    private fun sha256(b: ByteArray): String = MessageDigest.getInstance("SHA-256").digest(b).joinToString("") { "%02x".format(it) }

    fun lessons(ctx: Context): List<Lesson> {
        val m = read(ctx, "manifest.json")?.let { runCatching { JSONObject(String(it)) }.getOrNull() } ?: return emptyList()
        val arr = m.optJSONArray("lessons") ?: return emptyList()
        val out = mutableListOf<Lesson>()
        for (i in 0 until arr.length()) {
            val e = arr.optJSONObject(i) ?: continue
            val bytes = read(ctx, e.optString("path")) ?: continue
            if (e.has("sha256") && sha256(bytes) != e.optString("sha256")) continue // mismatched lessons ignored
            val j = runCatching { JSONObject(String(bytes)) }.getOrNull() ?: continue
            val req = e.optJSONArray("requires")?.let { a -> (0 until a.length()).map { a.optString(it) } } ?: emptyList()
            val steps = j.optJSONArray("steps")?.let { a -> (0 until a.length()).mapNotNull { a.optJSONObject(it) }.map { "${it.optInt("n")}. ${it.optString("do")}\n    why: ${it.optString("why")}" } } ?: emptyList()
            val must = j.optJSONObject("submit")?.optJSONArray("must_include")?.let { a -> (0 until a.length()).map { a.optString(it) } } ?: emptyList()
            out += Lesson(e.optString("lesson_id"), e.optString("title"), e.optBoolean("read_only", true), req, j.optString("purpose"), steps, must)
        }
        return out
    }

    fun passed(ctx: Context, lesson: String, learner: String): Boolean {
        val files = File(root(ctx), "scores").listFiles() ?: return false
        return files.filter { it.extension == "json" }.any { f ->
            val o = runCatching { JSONObject(f.readText()) }.getOrNull() ?: return@any false
            val who = o.optJSONObject("learner")?.optString("name") ?: o.optString("learner")
            o.optString("lesson_id") == lesson && who == learner && o.optBoolean("passed", false)
        }
    }

    fun unlocked(ctx: Context, l: Lesson, learner: String) = l.requires.all { passed(ctx, it, learner) }

    fun status(ctx: Context, learner: String): String {
        val ls = lessons(ctx)
        val lines = mutableListOf("ЯBOT CLASSROOM · Garage → Training · learner $learner", "root: ${root(ctx).absolutePath}")
        ls.forEach { lines += "  ${it.id} · ${it.title} · ${if (it.readOnly) "read-only" else "needs approval"} · ${if (unlocked(ctx, it, learner)) "unlocked" else "locked"}" }
        if (ls.isEmpty()) lines += "  (no lessons seated)"
        lines += "web: $PRIMARY_URL (fallback $FALLBACK_URL) · last verified: ${activeBase(ctx) ?: "none"}"
        lines += "Submit writes one new inbox/ file (local only). Scores come from reviewers via git. yabot://classroom"
        return lines.joinToString("\n")
    }

    private val secretPatterns = listOf(
        Regex("-----BEGIN [A-Z ]*PRIVATE KEY-----"),
        Regex("\\[\\s*(\\d{1,3}\\s*,\\s*){63}\\d{1,3}\\s*\\]"),
        Regex("\\b[1-9A-HJ-NP-Za-km-z]{80,90}\\b"),
        Regex("\\b(ghp|gho|ghs|github_pat|xox[abp]|sk)[-_][A-Za-z0-9_\\-]{16,}")
    )
    fun looksSecret(s: String) = secretPatterns.any { it.containsMatchIn(s) }

    fun submit(ctx: Context, l: Lesson, learner: String, body: String): String {
        if (BotRoster.housed().none { it.display == learner } && learner != "Rizal") return "Refused — unknown learner '$learner'."
        val text = body.trim()
        if (text.isEmpty()) return "Write an answer first."
        if (looksSecret(text)) return "Refused — the answer looks like it contains a secret. Nothing written."
        val attempt = "a" + (System.currentTimeMillis() / 1000)
        val safe = learner.map { if (it.isLetterOrDigit()) it else '_' }.joinToString("")
        val msgId = "${l.id}-$safe-$attempt"
        val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }.format(Date())
        val row = JSONObject()
            .put("schema", "rbot.classroom.message.v1").put("message_id", msgId).put("kind", "submission")
            .put("lesson_id", l.id).put("attempt_id", attempt)
            .put("from", JSONObject().put("name", learner).put("role", "learner").put("agent", "rbot-app").put("platform", "android"))
            .put("created_at", iso).put("body", text)
            .put("safety_attest", JSONObject().put("no_secrets", true).put("no_remote_or_chain_actions", true).put("read_only", l.readOnly))
        val inbox = File(root(ctx), "inbox").apply { mkdirs() }
        val f = File(inbox, "$msgId.json")
        if (f.exists()) return "Submit failed (file exists)."
        f.writeText(row.toString(2))
        File(root(ctx), "CLASSROOM-LEDGER.jsonl").appendText(
            JSONObject().put("op", "classroom-submit").put("lesson_id", l.id).put("learner", learner).put("file", "inbox/$msgId.json").put("ts", iso).toString() + "\n")
        return "Submitted · inbox/$msgId.json (local; a reviewer scores it via git)"
    }

    /** Training lane UI: lesson list → steps → answer → Submit (one new inbox file). */
    fun showTraining(ctx: Context, learner: String) {
        val ls = lessons(ctx)
        if (ls.isEmpty()) {
            AlertDialog.Builder(ctx).setTitle("Classroom").setMessage("No lessons seated.\nOnline: $PRIMARY_URL")
                .setNeutralButton("Refresh") { _, _ -> refreshThenShow(ctx, learner) }
                .setPositiveButton("OK", null).show(); return
        }
        val labels = ls.map { (if (unlocked(ctx, it, learner)) "🔓 " else "🔒 ") + "${it.id} · ${it.title}" }.toTypedArray()
        AlertDialog.Builder(ctx)
            .setTitle("CLASSROOM · Training · $learner")
            .setItems(labels) { _, i ->
                val l = ls[i]
                if (!unlocked(ctx, l, learner)) {
                    AlertDialog.Builder(ctx).setTitle(l.title).setMessage("Locked — needs a passed score for: ${l.requires.joinToString()}").setPositiveButton("OK", null).show()
                } else showLesson(ctx, l, learner)
            }
            .setNeutralButton("Refresh") { _, _ -> refreshThenShow(ctx, learner) }
            .setPositiveButton("rizal.pw") { _, _ -> openWeb(ctx) }
            .setNegativeButton("Close", null)
            .show()
    }

    private fun refreshThenShow(ctx: Context, learner: String) {
        val main = Handler(Looper.getMainLooper())
        Thread {
            val msg = refresh(ctx)
            main.post {
                AlertDialog.Builder(ctx).setTitle("Classroom").setMessage(msg)
                    .setPositiveButton("OK") { _, _ -> showTraining(ctx, learner) }.show()
            }
        }.start()
    }

    private fun showLesson(ctx: Context, l: Lesson, learner: String) {
        val pad = (12 * ctx.resources.displayMetrics.density).toInt()
        val col = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL; setPadding(pad, pad, pad, pad) }
        col.addView(TextView(ctx).apply {
            text = "${l.purpose}\n\n${l.steps.joinToString("\n")}\n\nThe app shows steps; it never runs them.\nInclude: ${l.mustInclude.joinToString(", ")}"
            textSize = 12f
        })
        val answer = EditText(ctx).apply { hint = "Answer (no secrets)"; minLines = 3 }
        col.addView(answer)
        AlertDialog.Builder(ctx)
            .setTitle("${l.id} · ${if (l.readOnly) "read-only" else "needs approval"}")
            .setView(ScrollView(ctx).apply { addView(col) })
            .setPositiveButton("Submit to inbox/") { _, _ ->
                val msg = submit(ctx, l, learner, answer.text?.toString().orEmpty())
                AlertDialog.Builder(ctx).setMessage(msg).setPositiveButton("OK", null).show()
            }
            .setNegativeButton("Close", null)
            .show()
    }
}
