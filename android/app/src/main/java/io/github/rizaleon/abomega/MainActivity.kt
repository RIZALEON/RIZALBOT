package io.github.rizaleon.abomega

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.ScrollView
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import java.util.concurrent.Executors

/**
 * ЯBOT Android 0.3.1 — iPhone clay twin + OFFLINE PREMIER command brain + Heart seat.
 * 0.3.1 parity with Mac/iPhone: Я Game door (stone clay-face button) → Play · GAME BUILDERS WORKSHOP,
 * gamewrite drafts (ЯBOT · ЯMAX), Decider-only Approve & Apply with respawn snapshots, Garage roster
 * with faces, ЯMANUAL landing, honest `respawn`, naming law (Я = Machine Mind · U = human · bots by name).
 *
 * Scroll-to-bottom FAB mirrors Mac/iOS ContentView.messageList jump-to-latest.
 */
class MainActivity : AppCompatActivity() {
    private lateinit var log: TextView
    private lateinit var input: EditText
    private lateinit var scroll: ScrollView
    private lateinit var middle: FrameLayout
    private lateinit var slate: ImageView
    private lateinit var jumpFab: ImageButton
    private lateinit var heart: NativeHeart
    private lateinit var landing: OfflineLanding
    private lateinit var garage: GarageWorkshopLanding
    private lateinit var gameDoor: GameDoor
    private lateinit var manual: ManualLanding
    private val bg = Executors.newSingleThreadExecutor()
    /** gamewrite never waits behind a Heart load/generate. */
    private val writeBg = Executors.newSingleThreadExecutor()

    /** Parallel to Mac messages.count — used to gate FAB (need > 1). */
    private var messageCount: Int = 0

    /** Threshold mirrored from ContentView onScrollGeometryChange (56pt). */
    private val bottomSlopPx: Int by lazy { (56f * resources.displayMetrics.density).toInt() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = android.graphics.Color.TRANSPARENT
        window.navigationBarColor = android.graphics.Color.parseColor("#12001F")
        @Suppress("DEPRECATION")
        window.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS)

        setContentView(R.layout.activity_main)
        log = findViewById(R.id.log)
        input = findViewById(R.id.input)
        scroll = findViewById(R.id.scroll)
        middle = findViewById(R.id.middle)
        slate = findViewById(R.id.clayslate)
        jumpFab = findViewById(R.id.btn_jump_latest)

        BotRoster.init(this)
        ModeStore.init(this)
        heart = NativeHeart(this)
        landing = OfflineLanding(this, middle, slate, scroll, log)
        garage = GarageWorkshopLanding(this, middle, slate, scroll, log)
        gameDoor = GameDoor(this, middle, heart, { landing.isOnlineBonus() }, { goHome(announce = true) }) { who, msg -> append(who, msg) }
        manual = ManualLanding(this, middle) { goHome(announce = true) }

        val send = findViewById<ImageButton>(R.id.send)
        send.setOnClickListener { send() }
        send.alpha = 1.0f
        send.isEnabled = true

        findViewById<ImageButton>(R.id.btn_plus).setOnClickListener {
            append(BotRoster.SYSTEM, "+ attach stub · offline premier")
        }

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (anyOverlay()) {
                    goHome(announce = false)
                } else {
                    isEnabled = false
                    onBackPressedDispatcher.onBackPressed()
                    isEnabled = true
                }
            }
        })

        wireJumpToLatest()
        wireYabar()

        append(BotRoster.SYSTEM, "ЯBOT Android ${OfflineCommandRouter.VERSION} · clay face live. ${if (ModeStore.isOnline) "MODE: ONLINE (bonus) · offline seat still premier." else OfflineCommandRouter.MODE_LINE}")
        append(BotRoster.SYSTEM, "Я speaks for the Machine Mind · U = you · bots: ${BotRoster.namesLine()} · stone clay face = Я Game door")
        append(BotRoster.SYSTEM, "Heart: loading async…")

        bg.execute {
            try { GameWorkshop.ensureSeated(this) } catch (e: Exception) { Log.w("MainActivity", "workshop seat: ${e.message}") }
            val ok = heart.load()
            runOnUiThread {
                append(BotRoster.SYSTEM, if (ok) "Heart READY · ${heart.statusLine()}" else "Heart not ready · ${heart.statusLine()}")
            }
            Log.i("MainActivity", heart.statusLine())
        }
        handleDeepLink(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleDeepLink(intent)
    }

    private fun handleDeepLink(intent: Intent?) {
        val data = intent?.data ?: return
        if (data.scheme != "yabot") return
        when (data.host) {
            "lab" -> {
                showBar(OfflineCommandRouter.BarRoute.LAB)
                append("Lab", "Deep link yabot://lab/chamber · offline chamber")
            }
            "game" -> {
                val ws = data.pathSegments.firstOrNull()?.lowercase() == "workshop"
                openDoor(if (ws) OfflineCommandRouter.Door.WORKSHOP else OfflineCommandRouter.Door.GAME)
                append(BotRoster.MIND, if (ws) "Deep link yabot://game/workshop · GAME BUILDERS WORKSHOP" else "Deep link yabot://game · Я Game door")
            }
            "workshop" -> {
                openDoor(OfflineCommandRouter.Door.WORKSHOP)
                append(BotRoster.MIND, "Deep link yabot://workshop · GAME BUILDERS WORKSHOP")
            }
            "manual" -> {
                openDoor(OfflineCommandRouter.Door.MANUAL)
                append(BotRoster.MIND, "Deep link yabot://manual · ЯMANUAL")
            }
            "garage" -> {
                openDoor(OfflineCommandRouter.Door.GARAGE)
                append(BotRoster.MIND, "Deep link yabot://garage · Garage")
            }
            "cmd" -> {
                // yabot://cmd/ping  or  yabot://cmd?q=mode
                val q = data.getQueryParameter("q")
                    ?: data.pathSegments.joinToString(" ").trim()
                if (q.isNotEmpty()) {
                    append(BotRoster.USER, q)
                    dispatchUserLine(q)
                }
            }
        }
    }

    private fun anyOverlay(): Boolean = landing.showing() || garage.showing() || gameDoor.showing() || manual.showing()

    private fun hideOverlays() {
        landing.hideLanding()
        garage.hide()
        gameDoor.hide()
        manual.hide()
    }

    /** Back to the chat (Ghost Home). */
    private fun goHome(announce: Boolean) {
        hideOverlays()
        slate.visibility = View.VISIBLE
        scroll.visibility = View.VISIBLE
        jumpFab.bringToFront()
        updateJumpFab()
        if (announce) append("Ghost Home", "Ghost Heart Home · center magnet · OFFLINE PREMIER")
    }

    private fun showBar(route: OfflineCommandRouter.BarRoute) {
        garage.hide(); gameDoor.hide(); manual.hide()
        landing.show(route)
        jumpFab.bringToFront()
        updateJumpFab()
    }

    private fun openDoor(door: OfflineCommandRouter.Door, book: String? = null) {
        hideOverlays()
        slate.visibility = View.GONE
        scroll.visibility = View.GONE
        when (door) {
            OfflineCommandRouter.Door.GAME -> gameDoor.show(openWorkshop = false)
            OfflineCommandRouter.Door.WORKSHOP -> gameDoor.show(openWorkshop = true)
            OfflineCommandRouter.Door.MANUAL -> manual.show(book)
            OfflineCommandRouter.Door.GARAGE -> garage.show()
        }
        updateJumpFab()
    }

    private fun wireJumpToLatest() {
        jumpFab.setOnClickListener {
            scrollToBottom(animated = true)
            jumpFab.visibility = View.GONE
        }
        scroll.viewTreeObserver.addOnScrollChangedListener {
            updateJumpFab()
        }
        jumpFab.bringToFront()
        updateJumpFab()
    }

    /** Mac twin: show clay ↓ when scrolled away from latest; hide at bottom. */
    private fun updateJumpFab() {
        if (anyOverlay() || scroll.visibility != View.VISIBLE) {
            if (jumpFab.visibility != View.GONE) jumpFab.visibility = View.GONE
            return
        }
        val child = scroll.getChildAt(0)
        if (child == null || messageCount <= 1) {
            if (jumpFab.visibility != View.GONE) jumpFab.visibility = View.GONE
            return
        }
        val contentH = child.height
        val viewH = scroll.height
        if (contentH <= viewH + 8) {
            if (jumpFab.visibility != View.GONE) jumpFab.visibility = View.GONE
            return
        }
        val distanceFromBottom = contentH - (scroll.scrollY + viewH)
        val atBottom = distanceFromBottom <= bottomSlopPx
        val next = if (!atBottom) View.VISIBLE else View.GONE
        if (jumpFab.visibility != next) {
            jumpFab.visibility = next
            if (next == View.VISIBLE) jumpFab.bringToFront()
        }
    }

    private fun scrollToBottom(animated: Boolean) {
        scroll.post {
            if (animated) {
                val child = scroll.getChildAt(0)
                val target = (child?.bottom ?: 0) - scroll.height
                if (target > scroll.scrollY) {
                    scroll.smoothScrollTo(0, target.coerceAtLeast(0))
                } else {
                    scroll.fullScroll(ScrollView.FOCUS_DOWN)
                }
            } else {
                scroll.fullScroll(ScrollView.FOCUS_DOWN)
            }
        }
    }

    private fun wireYabar() {
        tap(R.id.yabar_bolte) {
            openDoor(OfflineCommandRouter.Door.MANUAL, "mind/books/YAMANUAL.md")
            append("Bolte", "Opened ЯMANUAL (sole fixed manual · offline assets · in-app)")
        }
        tap(R.id.yabar_lab) {
            showBar(OfflineCommandRouter.BarRoute.LAB)
            append("Lab", "Lab · chamber offline (yabot://lab/chamber)")
        }
        tap(R.id.yabar_search) {
            showBar(OfflineCommandRouter.BarRoute.SEARCH)
            append("Search", "Search · overlay stub (magnetic; Ghost Home stays)")
        }
        tap(R.id.yabar_home) { goHome(announce = true) }
        tap(R.id.yabar_wallet) {
            showBar(OfflineCommandRouter.BarRoute.WALLET)
            append("Wallet", "Wallet · offline landing · mint ${OfflineCommandRouter.MINT}")
        }
        // ClayModeButton twin: red OFFLINE ↔ green ONLINE, flipped immediately, persisted (ModeStore).
        val onlineSwitch = findViewById<ImageView>(R.id.yabar_online)
        ModeStore.addListener { _ ->
            runOnUiThread {
                onlineSwitch.setImageResource(ModeStore.iconRes())
                onlineSwitch.contentDescription = ModeStore.help()
            }
        }
        tap(R.id.yabar_online) {
            append(BotRoster.SYSTEM, landing.toggleOnlineLabel())
        }
        tap(R.id.yabar_mind) {
            showBar(OfflineCommandRouter.BarRoute.MIND)
            append("Mind", "Machine Mind · offline landing")
        }
        tap(R.id.yabar_garage) {
            openDoor(OfflineCommandRouter.Door.GARAGE)
            append("Garage", "Garage workshop · ${BotRoster.namesLine()} housed")
        }
        tap(R.id.yabar_clayface) {
            // 0.3.x: stone clay-face = Я Game door (Play · GAME BUILDERS WORKSHOP)
            openDoor(OfflineCommandRouter.Door.GAME)
            append(BotRoster.MIND, "Я Game door · Play · GAME BUILDERS WORKSHOP")
        }
    }

    private fun tap(id: Int, block: () -> Unit) {
        val v: View? = try {
            findViewById(id)
        } catch (_: Exception) {
            null
        }
        v?.setOnClickListener { block() }
    }

    private fun send() {
        val text = input.text?.toString()?.trim().orEmpty()
        if (text.isEmpty()) return
        input.setText("")
        append(BotRoster.USER, text)
        dispatchUserLine(text)
    }

    private fun dispatchUserLine(text: String) {
        // gamewrite drafts may ask the Heart → author off the UI thread; the bot speaks under its own name.
        if (OfflineCommandRouter.isGameWriteDraft(text)) {
            append(BotRoster.MIND, "gamewrite · drafting into the GAME BUILDERS WORKSHOP (Decider applies)…")
            writeBg.execute {
                val res = try {
                    GameWrite.handle(this, text, heart)
                } catch (e: Exception) {
                    GameWrite.Result("GAMEWRITE failed: ${e.message}", BotRoster.MIND)
                }
                runOnUiThread { append(res.speaker, res.reply) }
            }
            return
        }
        val route = try {
            OfflineCommandRouter.route(text, heart, this)
        } catch (e: Exception) {
            Log.w("MainActivity", "route: ${e.message}")
            OfflineCommandRouter.Route(true, "command failed: ${e.message}")
        }
        if (route.handled) {
            route.door?.let { door ->
                val book = if (route.reply?.startsWith("GAMEWRITE-FUNDAMENTALS") == true) "mind/books/GAMEWRITE-FUNDAMENTALS-0.1.md"
                    else if (door == OfflineCommandRouter.Door.MANUAL) "mind/books/YAMANUAL.md" else null
                openDoor(door, book)
            }
            route.bar?.let { bar ->
                when (bar) {
                    OfflineCommandRouter.BarRoute.ONLINE -> { /* display toggle via typed mode */ }
                    OfflineCommandRouter.BarRoute.HOME -> goHome(announce = false)
                    else -> showBar(bar)
                }
            }
            append(route.speaker, route.reply ?: "")
            return
        }
        if (heart.seated) {
            val who = BotRoster.assistantLabel()
            append(who, "…thinking (Heart)…")
            bg.execute {
                val out = heart.generate(text)
                runOnUiThread { append(who, out) }
            }
        } else {
            append(BotRoster.assistantLabel(), heart.offlinePremierFallback())
        }
    }

    private fun append(who: String, msg: String) {
        log.append("\n\n$who: $msg")
        messageCount += 1
        scrollToBottom(animated = true)
        jumpFab.visibility = View.GONE
    }
}
