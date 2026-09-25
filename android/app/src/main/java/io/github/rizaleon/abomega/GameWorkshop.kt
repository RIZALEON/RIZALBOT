package io.github.rizaleon.abomega

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

/**
 * GAME BUILDERS WORKSHOP — Android twin of Swift GameWorkshop (0.3.x).
 * Bots (ЯBOT · ЯMAX) propose drafts → Decider previews → Decider taps Approve & Apply (confirm) →
 * previous project state is snapshotted into respawn/<ts>-<project>/ first → draft copied in.
 * Every step appended to EVOLUTION-LEDGER.jsonl (append-only). NOTHING a bot writes goes live
 * without the Decider. Root: <external files>/ЯBOT/game/workshop (adb-pushable), else filesDir.
 */
object GameWorkshop {
    const val SCHEMA = "GameWorkshop.v1"
    const val SEED_ID = "blueface"
    const val SEED_NAME = "BLUEFACE v1"
    const val LEDGER = "EVOLUTION-LEDGER.jsonl"

    data class Project(val id: String, val name: String, val entry: String, val dir: File) {
        val entryFile: File get() = File(dir, entry)
    }

    data class Draft(
        val id: String,
        val project: String,
        val file: String,
        val language: String,
        val author: String,
        val authorDisplay: String,
        val purpose: String,
        val createdAt: String,
        var status: String,          // proposed | applied | rejected
        val needsRebuild: Boolean,
        val source: String,          // heart | starter | inline
        val bytes: Int,
        val notes: List<String>,
        var appliedAt: String? = null,
        var snapshot: String? = null
    ) {
        fun toJson(): JSONObject = JSONObject().apply {
            put("id", id); put("project", project); put("file", file); put("language", language)
            put("author", author); put("authorDisplay", authorDisplay); put("purpose", purpose)
            put("createdAt", createdAt); put("status", status); put("needsRebuild", needsRebuild)
            put("source", source); put("bytes", bytes); put("notes", JSONArray(notes))
            appliedAt?.let { put("appliedAt", it) }
            snapshot?.let { put("snapshot", it) }
        }

        companion object {
            fun from(o: JSONObject): Draft {
                val n = o.optJSONArray("notes")
                return Draft(
                    o.getString("id"), o.optString("project"), o.optString("file"), o.optString("language"),
                    o.optString("author"), o.optString("authorDisplay"), o.optString("purpose"),
                    o.optString("createdAt"), o.optString("status", "proposed"), o.optBoolean("needsRebuild"),
                    o.optString("source"), o.optInt("bytes"),
                    if (n == null) emptyList() else (0 until n.length()).map { n.getString(it) },
                    if (o.has("appliedAt")) o.getString("appliedAt") else null,
                    if (o.has("snapshot")) o.getString("snapshot") else null
                )
            }
        }
    }

    data class Snapshot(val id: String, val project: String, val createdAt: String, val reason: String, val dir: File)

    // MARK: paths

    fun base(ctx: Context): File = File(ctx.getExternalFilesDir(null) ?: ctx.filesDir, "ЯBOT")
    fun root(ctx: Context): File = File(base(ctx), "game/workshop")
    fun projectsDir(ctx: Context) = File(root(ctx), "projects")
    fun draftsDir(ctx: Context) = File(root(ctx), "drafts")
    fun respawnDir(ctx: Context) = File(root(ctx), "respawn")
    fun ledgerFile(ctx: Context) = File(root(ctx), LEDGER)
    fun projectDir(ctx: Context, id: String) = File(projectsDir(ctx), safeName(id))

    /** Play lookup order: device documents copy (<ext>/ЯBOT/game/index.html) → bundled assets. */
    fun playUrl(ctx: Context): Pair<String, String> {
        val local = File(base(ctx), "game/index.html")
        return if (local.isFile) {
            "file://${local.absolutePath}" to "device copy · ${local.absolutePath}"
        } else {
            "file:///android_asset/game/index.html" to "bundled · assets/game/index.html (push a Decider page to ${local.absolutePath})"
        }
    }

    // MARK: seat

    fun ensureSeated(ctx: Context): String {
        for (d in listOf(root(ctx), projectsDir(ctx), draftsDir(ctx), respawnDir(ctx))) d.mkdirs()
        val led = ledgerFile(ctx)
        if (!led.exists()) led.writeText("")
        BotRoster.ensureSeated(ctx)
        val seed = projectDir(ctx, SEED_ID)
        var note = "workshop seated · ${root(ctx).absolutePath}"
        val live = File(seed, "live/index.html")
        if (!live.exists()) {
            live.parentFile?.mkdirs()
            copyAsset(ctx, "game/workshop-seed/BLUEFACE-v1.html", live)
            for (doc in listOf("README-BLUEFACE.md", "AGENTS-BLUEFACE.md", "package.json", "tsconfig.json", "vite.config.ts", "blueface-ts-src.zip")) {
                val t = File(seed, doc)
                if (!t.exists()) copyAsset(ctx, "game/workshop-seed/$doc", t)
            }
            for (doc in listOf("README.md", "AGENTS.md")) {
                val t = File(root(ctx), doc)
                if (!t.exists()) copyAsset(ctx, "game/workshop/$doc", t)
            }
            writeProjectMeta(ctx, SEED_ID, SEED_NAME, "live/index.html")
            note += " · seeded BLUEFACE v1 from bundle"
            ledger(ctx, mapOf("event" to "seed", "project" to SEED_ID, "by" to "system", "note" to note, "device" to "android"))
        }
        return note
    }

    private fun copyAsset(ctx: Context, asset: String, to: File): Boolean = try {
        ctx.assets.open(asset).use { i -> to.outputStream().use { i.copyTo(it) } }
        true
    } catch (_: Exception) {
        false
    }

    fun writeProjectMeta(ctx: Context, id: String, name: String, entry: String) {
        val f = File(projectDir(ctx, id), "project.json")
        if (f.exists()) return
        f.parentFile?.mkdirs()
        val o = JSONObject().apply {
            put("schema", SCHEMA); put("id", id); put("name", name); put("entry", entry)
            put("crown", "Я"); put("createdAt", isoNow())
        }
        f.writeText(o.toString(2))
    }

    fun projects(ctx: Context): List<Project> {
        ensureSeated(ctx)
        val dirs = projectsDir(ctx).listFiles()?.filter { it.isDirectory && !it.name.startsWith(".") }?.sortedBy { it.name } ?: emptyList()
        return dirs.map { d ->
            var name = d.name
            var entry = "live/index.html"
            try {
                val o = JSONObject(File(d, "project.json").readText())
                name = o.optString("name", name)
                entry = o.optString("entry", entry)
            } catch (_: Exception) {
            }
            Project(d.name, name, entry, d)
        }
    }

    fun createProject(ctx: Context, raw: String): String {
        val id = safeName(raw.lowercase())
        if (id.isEmpty()) return "HOW: name the project"
        val dir = projectDir(ctx, id)
        if (dir.exists()) return "Project $id already exists."
        File(dir, "live").mkdirs()
        File(dir, "live/index.html").writeText(GameWrite.starter("html", "live/index.html", "New Я Game project $raw"))
        writeProjectMeta(ctx, id, raw, "live/index.html")
        ledger(ctx, mapOf("event" to "project-create", "project" to id, "by" to "Decider", "note" to raw))
        return "Project $id created."
    }

    // MARK: drafts

    fun propose(
        ctx: Context, rawProject: String, rawFile: String, rawLang: String,
        content: String, purpose: String, author: String, source: String
    ): Pair<Draft?, String> {
        ensureSeated(ctx)
        val project = safeName(rawProject.ifEmpty { SEED_ID })
        if (!projectDir(ctx, project).exists()) {
            return null to "GAMEWRITE refused · no project '$project'. Projects: ${projects(ctx).joinToString(", ") { it.id }}"
        }
        val check = GameWrite.validate(rawLang, rawFile, content)
        val who = BotRoster.resolve(author)
        val authorLabel = who?.display ?: author.trim()
        val cLang = check.language
        val cFile = check.file
        if (!check.ok || cLang == null || cFile == null) {
            ledger(ctx, mapOf("event" to "refused", "project" to project, "file" to rawFile, "language" to rawLang,
                "author" to authorLabel, "purpose" to purpose, "reasons" to check.problems))
            return null to ("GAMEWRITE refused (nothing saved):\n• " + check.problems.joinToString("\n• "))
        }
        if (who == null) {
            ledger(ctx, mapOf("event" to "refused", "project" to project, "file" to cFile, "author" to authorLabel,
                "reasons" to listOf("author not in authors.json — gamewrite authors: ${BotRoster.namesLine()}")))
            return null to ("GAMEWRITE refused (nothing saved) · " + BotRoster.refusal(authorLabel))
        }
        val id = "d${compactStamp()}-${UUID.randomUUID().toString().take(4).lowercase()}"
        val dir = File(draftsDir(ctx), id)
        try {
            dir.mkdirs()
            File(dir, contentName(cFile)).writeText(content)
        } catch (e: Exception) {
            return null to "GAMEWRITE write failed: ${e.message}"
        }
        val d = Draft(id, project, cFile, cLang, who.display, who.display,
            purpose.ifEmpty { "(no purpose given)" }, isoNow(), "proposed", check.needsRebuild,
            source, content.toByteArray().size, check.warnings)
        saveMeta(ctx, d)
        ledger(ctx, mapOf("event" to "propose", "draft" to id, "project" to project, "file" to d.file,
            "language" to d.language, "author" to d.authorDisplay, "purpose" to d.purpose, "source" to source,
            "bytes" to d.bytes, "needsRebuild" to d.needsRebuild, "device" to "android"))
        var msg = """
            GAMEWRITE draft proposed · $id
            author: ${d.authorDisplay} · language: ${d.language} · file: $project/${d.file} · source: $source
            purpose: ${d.purpose}
            status: proposed — NOT live. Decider: open GAME BUILDERS WORKSHOP (yabot://game/workshop) → Drafts → Preview → Approve & Apply.
        """.trimIndent()
        if (d.needsRebuild) msg += "\nflag: needs rebuild (${d.language} wrapper code cannot compile in-app)."
        if (check.warnings.isNotEmpty()) msg += "\nnotes: " + check.warnings.joinToString(" · ")
        return d to msg
    }

    fun drafts(ctx: Context): List<Draft> {
        val dirs = draftsDir(ctx).listFiles()?.filter { it.isDirectory && !it.name.startsWith(".") } ?: return emptyList()
        return dirs.mapNotNull { d ->
            try { Draft.from(JSONObject(File(d, "draft.json").readText())) } catch (_: Exception) { null }
        }.sortedByDescending { it.createdAt + it.id }
    }

    fun draft(ctx: Context, id: String): Draft? = drafts(ctx).firstOrNull { it.id == id || it.id.startsWith(id) }

    fun contentFile(ctx: Context, d: Draft) = File(File(draftsDir(ctx), d.id), contentName(d.file))
    fun content(ctx: Context, d: Draft): String = try { contentFile(ctx, d).readText() } catch (_: Exception) { "" }
    fun liveContent(ctx: Context, d: Draft): String? = try { File(projectDir(ctx, d.project), d.file).readText() } catch (_: Exception) { null }

    /** Simple line diff (draft vs live): removed/added lines by set membership, capped. */
    fun diffText(ctx: Context, d: Draft, maxLines: Int = 300): String {
        val new = content(ctx, d).split("\n")
        val live = liveContent(ctx, d) ?: return "NEW FILE ${d.project}/${d.file}\n" + new.take(maxLines).joinToString("\n") { "+ $it" }
        val old = live.split("\n")
        if (old.size > 6000 || new.size > 6000) return "(large file: ${old.size} → ${new.size} lines; showing draft head)\n" + new.take(maxLines).joinToString("\n")
        val oldSet = old.toHashSet()
        val newSet = new.toHashSet()
        val out = mutableListOf<String>()
        old.forEachIndexed { i, l -> if (l !in newSet) out.add("- [${i + 1}] $l") }
        new.forEachIndexed { i, l -> if (l !in oldSet) out.add("+ [${i + 1}] $l") }
        if (out.isEmpty()) return "(no changes vs live)"
        return "DIFF ${d.project}/${d.file}\n" + out.take(maxLines).joinToString("\n") + if (out.size > maxLines) "\n… (truncated)" else ""
    }

    fun reject(ctx: Context, id: String): String {
        val d = draft(ctx, id) ?: return "No draft $id."
        if (d.status != "proposed") return "Draft ${d.id} is ${d.status}."
        d.status = "rejected"
        saveMeta(ctx, d)
        ledger(ctx, mapOf("event" to "reject", "draft" to d.id, "project" to d.project, "file" to d.file, "by" to "Decider", "author" to d.authorDisplay))
        return "Rejected ${d.id}. Kept on disk for the record."
    }

    /** Decider-only (Workshop UI tap + confirm dialog; never a chat word). Snapshot first, then copy. */
    fun approveAndApply(ctx: Context, id: String): String {
        val d = draft(ctx, id) ?: return "No draft $id."
        if (d.status != "proposed") return "Draft ${d.id} is already ${d.status}."
        val re = GameWrite.validate(d.language, d.file, content(ctx, d))
        if (!re.ok) return "Apply refused — draft no longer validates:\n• " + re.problems.joinToString("\n• ")
        ledger(ctx, mapOf("event" to "approve", "draft" to d.id, "project" to d.project, "file" to d.file, "by" to "Decider", "author" to d.authorDisplay, "purpose" to d.purpose))
        val snap = snapshot(ctx, d.project, "before apply ${d.id} → ${d.file}")
            ?: return "Apply stopped — could not snapshot ${d.project} first (nothing changed)."
        val dest = File(projectDir(ctx, d.project), d.file)
        try {
            dest.parentFile?.mkdirs()
            contentFile(ctx, d).copyTo(dest, overwrite = true)   // prior version lives in the snapshot
        } catch (e: Exception) {
            return "Apply failed after snapshot ${snap.id}: ${e.message}. Respawn it from the Respawn tab."
        }
        d.status = "applied"
        d.appliedAt = isoNow()
        d.snapshot = snap.id
        saveMeta(ctx, d)
        ledger(ctx, mapOf("event" to "apply", "draft" to d.id, "project" to d.project, "file" to d.file, "by" to "Decider",
            "author" to d.authorDisplay, "purpose" to d.purpose, "snapshot" to snap.id, "needsRebuild" to d.needsRebuild))
        var msg = "Applied ${d.id} → ${d.project}/${d.file}\nrespawn point: ${snap.id} (roll back any time)"
        if (d.needsRebuild) msg += "\n${d.language} wrapper: rebuild the app to use it."
        return msg
    }

    fun snapshot(ctx: Context, project: String, reason: String): Snapshot? {
        val src = projectDir(ctx, project)
        if (!src.exists()) return null
        val id = "${compactStamp()}-${safeName(project)}"
        var dir = File(respawnDir(ctx), id)
        var n = 1
        while (dir.exists()) { dir = File(respawnDir(ctx), "$id-${n++}") }
        return try {
            dir.mkdirs()
            if (!src.copyRecursively(File(dir, "project"), overwrite = false)) return null
            val meta = JSONObject().apply {
                put("schema", SCHEMA); put("id", dir.name); put("project", project); put("reason", reason); put("createdAt", isoNow())
            }
            File(dir, "SNAPSHOT.json").writeText(meta.toString(2))
            ledger(ctx, mapOf("event" to "snapshot", "project" to project, "snapshot" to dir.name, "reason" to reason))
            Snapshot(dir.name, project, isoNow(), reason, dir)
        } catch (_: Exception) {
            null
        }
    }

    fun snapshots(ctx: Context, project: String? = null): List<Snapshot> {
        val dirs = respawnDir(ctx).listFiles()?.filter { it.isDirectory && !it.name.startsWith(".") } ?: return emptyList()
        return dirs.mapNotNull { d ->
            try {
                val o = JSONObject(File(d, "SNAPSHOT.json").readText())
                val p = o.getString("project")
                if (project != null && p != project) null
                else Snapshot(d.name, p, o.optString("createdAt"), o.optString("reason"), d)
            } catch (_: Exception) {
                null
            }
        }.sortedByDescending { it.id }
    }

    /** Decider-only: roll a project back. Current state snapshotted first (undoable). */
    fun respawn(ctx: Context, project: String, snapshotId: String): String {
        val snap = snapshots(ctx, project).firstOrNull { it.id == snapshotId } ?: return "No snapshot $snapshotId for $project."
        val pre = snapshot(ctx, project, "before respawn → $snapshotId") ?: return "Respawn stopped — could not snapshot current $project first."
        val live = projectDir(ctx, project)
        val parked = File(pre.dir, "project")
        return try {
            live.deleteRecursively()   // live state is already copied into `pre`
            File(snap.dir, "project").copyRecursively(live, overwrite = true)
            ledger(ctx, mapOf("event" to "respawn", "project" to project, "to" to snapshotId, "by" to "Decider", "undo" to pre.id))
            "Respawned $project → $snapshotId. Undo point: ${pre.id}."
        } catch (e: Exception) {
            if (!live.exists()) parked.copyRecursively(live, overwrite = true)
            "Respawn failed: ${e.message}. Live project restored from ${pre.id}."
        }
    }

    // MARK: ledger (append-only jsonl)

    fun ledger(ctx: Context, fields: Map<String, Any?>) {
        try {
            val o = JSONObject()
            for ((k, v) in fields.toSortedMap()) {
                o.put(k, when (v) {
                    is List<*> -> JSONArray(v)
                    null -> JSONObject.NULL
                    else -> v
                })
            }
            o.put("ts", isoNow())
            o.put("crown", "Я")
            root(ctx).mkdirs()
            ledgerFile(ctx).appendText(o.toString() + "\n")
        } catch (_: Exception) {
        }
    }

    fun ledgerTail(ctx: Context, n: Int = 80): List<String> = try {
        ledgerFile(ctx).readLines().filter { it.isNotBlank() }.takeLast(n).reversed()
    } catch (_: Exception) {
        emptyList()
    }

    fun status(ctx: Context): String {
        ensureSeated(ctx)
        val ds = drafts(ctx)
        val pending = ds.count { it.status == "proposed" }
        return """
            GAME BUILDERS WORKSHOP · ${root(ctx).absolutePath}
            projects: ${projects(ctx).joinToString(", ") { "${it.name} (${it.id})" }}
            drafts: ${ds.size} ($pending waiting on Decider) · respawn points: ${snapshots(ctx).size}
            gamewrite bots: ${BotRoster.namesLine()} · roster: ${BotRoster.seatFile(ctx).absolutePath} · gamewrite ids: ${BotRoster.authorsFile(ctx).absolutePath}
            open: yabot://game/workshop · write: gamewrite <language> <file> <purpose> [as <bot>]
        """.trimIndent()
    }

    // MARK: helpers

    fun saveMeta(ctx: Context, d: Draft) {
        val dir = File(draftsDir(ctx), d.id)
        dir.mkdirs()
        File(dir, "draft.json").writeText(d.toJson().toString(2))
    }

    fun contentName(file: String) = "content-" + file.substringAfterLast('/')

    fun safeName(raw: String): String {
        val mapped = raw.map { if (it.isLetterOrDigit() || it in "-_.") it else '-' }.joinToString("")
        var s = mapped
        while (s.contains("--")) s = s.replace("--", "-")
        s = s.trim('-', '.')
        return s.take(64)
    }

    fun isoNow(): String {
        val f = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        f.timeZone = TimeZone.getTimeZone("UTC")
        return f.format(Date())
    }

    fun compactStamp(): String = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
}
