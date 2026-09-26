package io.github.rizaleon.abomega

import android.app.Activity
import android.app.AlertDialog
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.io.File
import java.util.concurrent.Executors

/**
 * Я Game door — Android twin of Swift GameLandingView + GameWorkshopView (0.3.x).
 * Stone clay-face button on the ЯBAR opens this UNDER the sticky bar.
 * Game MENU (0.3.3: opened by the top-left Igorot Headaxe panel): Play (game/index.html: device copy first, then
 * bundled assets) · GAME BUILDERS WORKSHOP · ЯBROWSER (private, no bridge) · Igorot Headaxe (tool) · Home.
 * Workshop sections: Projects · Drafts · Preview (sandbox) · Respawn · Ledger.
 * Only the Decider applies (tap + confirm dialog). NonNuclear: door only — no spend / mint / signing.
 */
class GameDoor(
    private val activity: Activity,
    private val middle: FrameLayout,
    private val heart: NativeHeart,
    private val isOnline: () -> Boolean,
    private val onHome: () -> Unit,
    private val onChat: (who: String, msg: String) -> Unit
) {
    enum class Section(val title: String) { PROJECTS("Projects"), DRAFTS("Drafts"), PREVIEW("Preview"), RESPAWN("Respawn"), LEDGER("Ledger") }

    private val ctx = activity
    private val bg = Executors.newSingleThreadExecutor()
    private var root: FrameLayout? = null
    private var showing = false
    private var workshop = false
    private var section = Section.DRAFTS
    private var selectedProject = GameWorkshop.SEED_ID
    private var askBotId = ""
    private var note = ""
    private var previewTitle = "Nothing loaded"
    private var previewLoader: ((WebView) -> Unit)? = null
    private var previewWeb: WebView? = null
    private var playWeb: WebView? = null
    /** 0.3.3: Igorot Headaxe panel (top-left) = game MENU button · ЯBROWSER section. */
    private var menuOpen = false
    private var browser = false
    private var yaBrowser: YaBrowser? = null
    private var menuNote = ""

    fun showing(): Boolean = showing
    fun inWorkshop(): Boolean = showing && workshop

    fun show(openWorkshop: Boolean) {
        if (root == null) {
            root = FrameLayout(ctx).apply {
                layoutParams = FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
                isClickable = true   // swallow taps so chat under the door is not hit
            }
            middle.addView(root)
        }
        try { GameWorkshop.ensureSeated(ctx) } catch (e: Exception) { Log.w("GameDoor", "seat: ${e.message}") }
        workshop = openWorkshop
        showing = true
        root!!.visibility = View.VISIBLE
        root!!.bringToFront()
        render()
    }

    fun hide() {
        yaBrowser?.wipe(); yaBrowser = null
        menuOpen = false
        root?.visibility = View.GONE
        playWeb?.loadUrl("about:blank")
        previewWeb?.loadUrl("about:blank")
        showing = false
    }

    private fun dp(v: Int) = ClayUi.dp(ctx, v)

    private fun render() {
        val r = root ?: return
        r.removeAllViews()
        playWeb = null
        previewWeb = null
        if (!browser || workshop) { yaBrowser?.wipe(); yaBrowser = null }
        if (workshop) renderWorkshop(r) else renderPlay(r)
    }

    // MARK: Play

    private fun renderPlay(r: FrameLayout) {
        r.setBackgroundColor(Color.argb(235, 0, 0, 0))
        val col = ClayUi.column(ctx).apply { setPadding(dp(10), dp(10), dp(10), dp(10)) }
        val (url, source) = GameWorkshop.playUrl(ctx)

        val header = ClayUi.row(ctx, 10)
        header.addView(ImageView(ctx).apply {
            setImageResource(R.drawable.btn_headaxe_menu)   // Igorot Headaxe panel = MENU button
            scaleType = ImageView.ScaleType.FIT_CENTER
            adjustViewBounds = true
            contentDescription = "Igorot Headaxe — game menu"
            isClickable = true
            setOnClickListener { menuOpen = !menuOpen; render() }
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(46)))
        val titles = ClayUi.column(ctx)
        titles.addView(ClayUi.text(ctx, if (browser) "Я Game · ЯBROWSER" else "Я Game", 20f, bold = true))
        titles.addView(ClayUi.text(ctx, source, 10f, Color.argb(190, 245, 240, 232)).apply { maxLines = 2 })
        header.addView(titles, ClayUi.lp(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        header.addView(ClayUi.chip(ctx, if (isOnline()) "ONLINE" else "OFFLINE", active = isOnline(), tint = if (isOnline()) Color.GREEN else Color.GRAY))
        col.addView(header)

        if (browser) {
            val b = yaBrowser ?: YaBrowser(ctx, isOnline).also { yaBrowser = it }
            val v = b.view()
            col.addView(v, ClayUi.lp(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f).apply { topMargin = dp(8) })
            val bottomB = ClayUi.row(ctx, 10)
            bottomB.addView(ClayUi.chip(ctx, "Close ЯBROWSER (wipe)") { browser = false; render() })
            bottomB.addView(View(ctx), ClayUi.lp(0, 1, 1f))
            bottomB.addView(ClayUi.chip(ctx, "⌂ Home") { onHome() })
            col.addView(bottomB, ClayUi.lp().apply { topMargin = dp(8) })
            r.addView(col, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
            if (menuOpen) r.addView(menuPanel(), menuPanelLp())
            return
        }

        val web = ClayUi.sandboxWebView(ctx, allowFile = true, allowNet = isOnline)
        playWeb = web
        web.loadUrl(url)
        col.addView(web, ClayUi.lp(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f).apply { topMargin = dp(8) })

        val bottom = ClayUi.row(ctx, 10)
        bottom.addView(ClayUi.chip(ctx, "↻ Reload") { render() })
        bottom.addView(ClayUi.chip(ctx, "BLUEFACE v1 (Play live)") {
            val p = GameWorkshop.projects(ctx).firstOrNull { it.id == GameWorkshop.SEED_ID }
            if (p != null && p.entryFile.isFile) web.loadUrl("file://${p.entryFile.absolutePath}")
        })
        bottom.addView(View(ctx), ClayUi.lp(0, 1, 1f))
        bottom.addView(ClayUi.chip(ctx, "⌂ Home") { onHome() })
        col.addView(bottom, ClayUi.lp().apply { topMargin = dp(8) })
        r.addView(col, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        if (menuOpen) r.addView(menuPanel(), menuPanelLp())
    }

    // MARK: MENU (opened by the Igorot Headaxe panel) — carved plank buttons, gold lettering

    private val gold = Color.rgb(255, 214, 115)
    private val rim = Color.rgb(209, 153, 82)

    private fun plank(title: String, active: Boolean = false, onClick: () -> Unit): TextView = TextView(ctx).apply {
        text = title
        textSize = 14f
        setTextColor(gold)
        typeface = android.graphics.Typeface.create(android.graphics.Typeface.SERIF, android.graphics.Typeface.BOLD)
        setPadding(dp(14), dp(9), dp(14), dp(9))
        minWidth = dp(220)
        background = GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
            if (active) intArrayOf(Color.rgb(92, 133, 56), Color.rgb(51, 84, 31)) else intArrayOf(Color.rgb(125, 80, 44), Color.rgb(64, 38, 20))).apply {
            cornerRadius = dp(9).toFloat(); setStroke(dp(2), rim)
        }
        isClickable = true
        contentDescription = title
        setOnClickListener { onClick() }
    }

    private fun menuPanel(): View {
        val col = ClayUi.column(ctx).apply {
            setPadding(dp(12), dp(12), dp(12), dp(12))
            background = GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(Color.rgb(115, 74, 41), Color.rgb(64, 38, 20))).apply {
                cornerRadius = dp(14).toFloat(); setStroke(dp(3), rim)
            }
            elevation = dp(10).toFloat()
            isClickable = true
        }
        fun add(v: View) = col.addView(v, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { bottomMargin = dp(8) })
        add(plank("Play", active = !workshop && !browser) { browser = false; workshop = false; menuOpen = false; render() })
        add(plank("GAME BUILDERS WORKSHOP", active = workshop) { browser = false; workshop = true; menuOpen = false; render() })
        add(plank("🌐  ЯBROWSER", active = browser) { workshop = false; browser = true; menuOpen = false; render() })
        add(plank("⚒  Igorot Headaxe · tool") {
            menuNote = "Igorot Headaxe — TERAFORMЯ starter tool (dig · place). Equipped; tool select lives in the game."
            render()
        })
        add(plank("⌂  Home") { menuOpen = false; onHome() })
        if (menuNote.isNotEmpty()) col.addView(ClayUi.text(ctx, menuNote, 10f, gold).apply { maxWidth = dp(240) })
        return col
    }

    private fun menuPanelLp() = FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
        leftMargin = dp(10); topMargin = dp(64)
    }

    // MARK: Workshop

    private fun renderWorkshop(r: FrameLayout) {
        r.setBackgroundColor(Color.rgb(237, 237, 237))
        r.addView(ImageView(ctx).apply {
            setImageResource(R.drawable.workshop_room)
            scaleType = ImageView.ScaleType.CENTER_CROP
        }, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))

        val col = ClayUi.column(ctx).apply { setPadding(dp(8), dp(8), dp(8), dp(8)) }
        val header = ClayUi.row(ctx, 8)
        header.addView(ClayUi.chip(ctx, "◀ Play") { workshop = false; render() })
        val titles = ClayUi.column(ctx).apply {
            setPadding(dp(8), dp(4), dp(8), dp(4))
            background = GradientDrawable().apply { cornerRadius = dp(10).toFloat(); setColor(Color.argb(170, 255, 255, 255)) }
        }
        titles.addView(ClayUi.text(ctx, "Я / GAME BUILDERS WORKSHOP", 15f, Color.argb(220, 0, 0, 0), bold = true))
        titles.addView(ClayUi.text(ctx, "gamewrite bots: ${BotRoster.namesLine()} — drafts only · Decider applies", 10f, Color.argb(160, 0, 0, 0)).apply { maxLines = 2 })
        header.addView(titles, ClayUi.lp(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        header.addView(ClayUi.chip(ctx, "↻") { BotRoster.reload(); render() })
        col.addView(header)

        val chipsRow = ClayUi.row(ctx, 8)
        val pending = GameWorkshop.drafts(ctx).count { it.status == "proposed" }
        for (s in Section.values()) {
            val t = if (s == Section.DRAFTS && pending > 0) "Drafts ($pending)" else s.title
            chipsRow.addView(ClayUi.chip(ctx, t, active = section == s) { section = s; render() })
        }
        col.addView(HorizontalScrollView(ctx).apply {
            isHorizontalScrollBarEnabled = false
            addView(chipsRow)
        }, ClayUi.lp().apply { topMargin = dp(8); bottomMargin = dp(8) })

        val panel = FrameLayout(ctx).apply {
            background = ClayUi.panelBg(ctx)
            setPadding(dp(10), dp(10), dp(10), dp(10))
        }
        when (section) {
            Section.PROJECTS -> panel.addView(scrollOf(projectsSection()))
            Section.DRAFTS -> panel.addView(scrollOf(draftsSection()))
            Section.PREVIEW -> panel.addView(previewSection())
            Section.RESPAWN -> panel.addView(scrollOf(respawnSection()))
            Section.LEDGER -> panel.addView(scrollOf(ledgerSection()))
        }
        col.addView(panel, ClayUi.lp(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))

        if (note.isNotEmpty()) {
            col.addView(ClayUi.text(ctx, note, 11f).apply {
                setPadding(dp(12), dp(6), dp(12), dp(6))
                maxLines = 6
                background = GradientDrawable().apply { cornerRadius = dp(14).toFloat(); setColor(Color.argb(190, 0, 0, 0)) }
            }, ClayUi.lp().apply { topMargin = dp(6) })
        }
        r.addView(col, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
    }

    private fun scrollOf(v: View): View = ScrollView(ctx).apply { addView(v) }

    private fun label(s: String) = ClayUi.text(ctx, s, 10f, Color.argb(170, 245, 240, 232), bold = true)

    private fun projectsSection(): View {
        val col = ClayUi.column(ctx)
        col.addView(label("PROJECTS · ${GameWorkshop.projectsDir(ctx).absolutePath}"))
        for (p in GameWorkshop.projects(ctx)) {
            val row = ClayUi.column(ctx).apply { setPadding(0, dp(8), 0, dp(8)) }
            row.addView(ClayUi.text(ctx, p.name + if (p.id == selectedProject) "  ★" else "", 14f, bold = true))
            row.addView(ClayUi.text(ctx, "${p.id} · entry ${p.entry}", 10f, Color.argb(150, 245, 240, 232)))
            val chips = ClayUi.row(ctx, 8)
            chips.addView(ClayUi.chip(ctx, "Play live") {
                selectedProject = p.id
                previewTitle = "LIVE ${p.name} · ${p.entry}"
                previewLoader = { w -> if (p.entryFile.isFile) w.loadUrl("file://${p.entryFile.absolutePath}") else w.loadData("<p>missing ${p.entry}</p>", "text/html", "utf-8") }
                section = Section.PREVIEW; render()
            })
            chips.addView(ClayUi.chip(ctx, "Select") { selectedProject = p.id; note = "Selected ${p.id}"; render() })
            chips.addView(ClayUi.chip(ctx, "Respawn points") { selectedProject = p.id; section = Section.RESPAWN; render() })
            row.addView(chips, ClayUi.lp().apply { topMargin = dp(4) })
            col.addView(row)
        }
        val create = ClayUi.row(ctx, 8)
        val name = editText("new project name")
        create.addView(name, ClayUi.lp(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        create.addView(ClayUi.chip(ctx, "Create (Decider)") {
            val n = name.text.toString().trim()
            if (n.isNotEmpty()) { note = GameWorkshop.createProject(ctx, n); render() }
        })
        col.addView(create, ClayUi.lp().apply { topMargin = dp(10) })
        return col
    }

    private fun editText(hint: String): EditText = EditText(ctx).apply {
        this.hint = hint
        setHintTextColor(Color.argb(120, 245, 240, 232))
        setTextColor(ClayUi.OFF_WHITE)
        textSize = 13f
        background = GradientDrawable().apply { cornerRadius = dp(8).toFloat(); setColor(Color.argb(120, 255, 255, 255)) ; setStroke(1, Color.argb(90, 255, 255, 255)) }
        setPadding(dp(8), dp(6), dp(8), dp(6))
    }

    private fun faceView(bot: BotRoster.Bot?, size: Int): ImageView = ImageView(ctx).apply {
        setImageResource(bot?.faceRes() ?: R.drawable.btn_clayface)
        scaleType = ImageView.ScaleType.FIT_CENTER
        layoutParams = LinearLayout.LayoutParams(dp(size), dp(size))
        contentDescription = bot?.display ?: "Я"
    }

    private fun draftsSection(): View {
        val col = ClayUi.column(ctx)
        // Ask a bot (drafts only)
        col.addView(label("ASK A BOT · draft only (nothing goes live without the Decider)"))
        val bots = BotRoster.writers()
        if (bots.none { it.id == askBotId }) askBotId = BotRoster.defaultBot()?.id ?: ""
        val who = ClayUi.row(ctx, 8)
        for (b in bots) {
            val cell = ClayUi.row(ctx, 4)
            cell.addView(faceView(b, 30))
            cell.addView(ClayUi.chip(ctx, b.display, active = b.id == askBotId) { askBotId = b.id; render() })
            who.addView(cell)
        }
        col.addView(who, ClayUi.lp().apply { topMargin = dp(4) })
        val ask = editText("typescript src/scenes/Dig.ts mound grows where BLUEFACE digs")
        col.addView(ask, ClayUi.lp().apply { topMargin = dp(6) })
        col.addView(ClayUi.chip(ctx, "Draft it") {
            val t = ask.text.toString().trim()
            if (t.isEmpty()) return@chip
            val bot = BotRoster.resolve(askBotId) ?: BotRoster.defaultBot() ?: return@chip
            note = "${bot.display} is drafting…"; render()
            bg.execute {
                val res = try { GameWrite.handle(ctx, "gamewrite $t as ${bot.id}", heart) } catch (e: Exception) { GameWrite.Result("GAMEWRITE failed: ${e.message}", BotRoster.MIND) }
                activity.runOnUiThread { note = res.reply.lineSequence().take(3).joinToString("\n"); onChat(res.speaker, res.reply); render() }
            }
        }, ClayUi.lp(ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(6) })

        col.addView(label("DRAFTS · ${GameWorkshop.draftsDir(ctx).absolutePath}").apply { setPadding(0, dp(14), 0, dp(4)) })
        val ds = GameWorkshop.drafts(ctx)
        if (ds.isEmpty()) {
            col.addView(ClayUi.text(ctx, "No drafts yet. Ask a bot above, or in chat: gamewrite typescript src/scenes/Dig.ts mound grows where BLUEFACE digs", 12f, Color.argb(170, 245, 240, 232)))
        }
        for (d in ds) {
            val row = ClayUi.row(ctx, 10).apply { setPadding(0, dp(8), 0, dp(8)); gravity = Gravity.TOP }
            row.addView(faceView(BotRoster.lookup(d.authorDisplay), 40))
            val info = ClayUi.column(ctx)
            info.addView(ClayUi.text(ctx, "${d.language} · ${d.project}/${d.file}", 12f, bold = true))
            info.addView(ClayUi.text(ctx, "by ${d.authorDisplay} · ${d.status}${if (d.needsRebuild) " · needs rebuild" else ""} · ${d.bytes} B", 10f,
                when (d.status) { "applied" -> Color.rgb(140, 220, 140); "rejected" -> Color.rgb(220, 140, 140); else -> Color.rgb(240, 210, 120) }))
            info.addView(ClayUi.text(ctx, "purpose: ${d.purpose}", 11f, Color.argb(210, 245, 240, 232)))
            if (d.notes.isNotEmpty()) info.addView(ClayUi.text(ctx, "notes: " + d.notes.joinToString(" · "), 10f, Color.rgb(240, 220, 110)))
            d.snapshot?.let { info.addView(ClayUi.text(ctx, "applied ${d.appliedAt ?: ""} · respawn point $it", 10f, Color.rgb(140, 220, 140))) }
            val chips = ClayUi.row(ctx, 6)
            chips.addView(ClayUi.chip(ctx, "Preview") { previewDraft(d) })
            chips.addView(ClayUi.chip(ctx, "Diff") {
                previewTitle = "DIFF ${d.id}"
                val txt = GameWorkshop.diffText(ctx, d)
                previewLoader = { w -> w.loadDataWithBaseURL(null, ClayUi.preHtml("diff", txt), "text/html", "utf-8", null) }
                section = Section.PREVIEW; render()
            })
            if (d.status == "proposed") {
                chips.addView(ClayUi.chip(ctx, "Approve & Apply", tint = Color.rgb(90, 200, 110)) { confirmApply(d) })
                chips.addView(ClayUi.chip(ctx, "Reject", tint = Color.rgb(220, 90, 90)) { note = GameWorkshop.reject(ctx, d.id); render() })
            }
            info.addView(HorizontalScrollView(ctx).apply { isHorizontalScrollBarEnabled = false; addView(chips) }, ClayUi.lp().apply { topMargin = dp(4) })
            row.addView(info, ClayUi.lp(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            col.addView(row)
        }
        return col
    }

    private fun previewDraft(d: GameWorkshop.Draft) {
        previewTitle = "DRAFT ${d.id} · ${d.language} · by ${d.authorDisplay} (sandbox · local-only)"
        val body = GameWorkshop.content(ctx, d)
        previewLoader = { w ->
            if (d.language == "html") w.loadDataWithBaseURL(null, body, "text/html", "utf-8", null)
            else w.loadDataWithBaseURL(null, ClayUi.preHtml(d.file, body), "text/html", "utf-8", null)
        }
        section = Section.PREVIEW
        render()
    }

    private fun confirmApply(d: GameWorkshop.Draft) {
        AlertDialog.Builder(activity)
            .setTitle("Decider · Approve & Apply?")
            .setMessage("Apply ${d.id} by ${d.authorDisplay} → ${d.project}/${d.file}?\npurpose: ${d.purpose}\n\nThe current project is snapshotted into workshop/respawn/ first, so this can be respawned.")
            .setPositiveButton("Approve & Apply") { _, _ ->
                note = GameWorkshop.approveAndApply(ctx, d.id)
                onChat(BotRoster.MIND, note)
                render()
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun previewSection(): View {
        val col = ClayUi.column(ctx)
        col.addView(label("PREVIEW · $previewTitle"))
        val loader = previewLoader
        if (loader == null) {
            col.addView(ClayUi.text(ctx, "Pick a draft → Preview, or Projects → Play live.", 12f, Color.argb(160, 245, 240, 232)))
            return col
        }
        val web = ClayUi.sandboxWebView(ctx, allowFile = true)
        previewWeb = web
        loader(web)
        col.addView(web, ClayUi.lp(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT).apply { topMargin = dp(6) })
        return col
    }

    private fun respawnSection(): View {
        val col = ClayUi.column(ctx)
        col.addView(label("RESPAWN · project $selectedProject · ${GameWorkshop.respawnDir(ctx).absolutePath}"))
        val snaps = GameWorkshop.snapshots(ctx, selectedProject)
        if (snaps.isEmpty()) col.addView(ClayUi.text(ctx, "No snapshots for $selectedProject yet (the first Approve & Apply creates one).", 12f, Color.argb(170, 245, 240, 232)))
        for (s in snaps) {
            val row = ClayUi.column(ctx).apply { setPadding(0, dp(6), 0, dp(6)) }
            row.addView(ClayUi.text(ctx, s.id, 12f, bold = true))
            row.addView(ClayUi.text(ctx, "${s.createdAt} · ${s.reason}", 10f, Color.argb(170, 245, 240, 232)))
            row.addView(ClayUi.chip(ctx, "Respawn here (Decider)") {
                AlertDialog.Builder(activity)
                    .setTitle("Decider · Respawn project?")
                    .setMessage("Roll $selectedProject back to ${s.id}? The current state is snapshotted first, so this is undoable too.")
                    .setPositiveButton("Respawn") { _, _ ->
                        note = GameWorkshop.respawn(ctx, selectedProject, s.id)
                        onChat(BotRoster.MIND, note)
                        render()
                    }
                    .setNegativeButton("Cancel", null)
                    .show()
            }, ClayUi.lp(ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(4) })
            col.addView(row)
        }
        col.addView(ClayUi.text(ctx, "\n" + RespawnInfo.text(ctx), 10f, Color.argb(150, 245, 240, 232)))
        return col
    }

    private fun ledgerSection(): View {
        val col = ClayUi.column(ctx)
        col.addView(label("EVOLUTION LEDGER (append-only · newest first) · ${GameWorkshop.ledgerFile(ctx).absolutePath}"))
        val lines = GameWorkshop.ledgerTail(ctx)
        col.addView(ClayUi.text(ctx, if (lines.isEmpty()) "(empty)" else lines.joinToString("\n\n"), 10f, mono = true))
        return col
    }
}

/** `respawn` — honest list of respawn points (the app cannot reinstall itself). Points file bundled at build time. */
object RespawnInfo {
    fun text(ctx: android.content.Context): String {
        val points = try {
            ctx.assets.open("respawn/POINTS.txt").use { it.readBytes().toString(Charsets.UTF_8).trim() }
        } catch (_: Exception) {
            "(no respawn list bundled)"
        }
        val ws = File(GameWorkshop.respawnDir(ctx).absolutePath)
        val n = ws.listFiles()?.count { it.isDirectory } ?: 0
        return listOf(
            "RESPAWN · known-good seats. Android cannot reinstall its own build — the Decider runs it from the Mac.",
            points,
            "On the Mac (dry run first, then add --go):",
            "  bash ~/Library/Developer/ЯBOT-respawn/<point>/respawn.sh android   # adb install -r -d to connected devices",
            "Game projects have their own respawn inside the GAME BUILDERS WORKSHOP → Respawn ($n snapshot(s) on this device)."
        ).joinToString("\n")
    }
}
