package io.github.rizaleon.abomega

import android.content.Context
import android.content.SharedPreferences

/**
 * Android twin of Swift ModeStore (green nerve / ONLINE gate — Decider 2026-09-22) + ClayModeButton.
 * isOnline is persisted (like UserDefaults "YaBOT.ModeStore.isOnline") and the ЯBAR switch shows
 * BtnOffline (red OFFLINE lit) when false and BtnOnline (green ONLINE lit) when true — flipped immediately on tap.
 * The switch press is the Decider's way-out flip (same as Swift toggle()); home stays offline premier.
 * Like Apple, the switch does not probe reachability: it is the Decider's mode gate, not a network meter.
 */
object ModeStore {
    private const val PREFS = "YaBOT.ModeStore"
    private const val K_ONLINE = "YaBOT.ModeStore.isOnline"
    private const val K_BY = "YaBOT.ModeStore.lastOnlineBy"
    private const val K_CTX = "YaBOT.ModeStore.lastOnlineContext"
    private var prefs: SharedPreferences? = null
    private val listeners = mutableListOf<(Boolean) -> Unit>()

    @Volatile var isOnline: Boolean = false
        private set
    private var lastOnlineBy = ""
    private var lastOnlineContext = ""

    fun init(ctx: Context) {
        val p = ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs = p
        listeners.clear()   // one Activity at a time; a recreated Activity re-registers its switch
        isOnline = p.getBoolean(K_ONLINE, false)
        lastOnlineBy = p.getString(K_BY, "") ?: ""
        lastOnlineContext = p.getString(K_CTX, "") ?: ""
    }

    fun addListener(l: (Boolean) -> Unit) { listeners.add(l); l(isOnline) }

    private fun set(v: Boolean) {
        isOnline = v
        prefs?.edit()?.putBoolean(K_ONLINE, v)?.putString(K_BY, lastOnlineBy)?.putString(K_CTX, lastOnlineContext)?.apply()
        listeners.forEach { it(v) }
    }

    val label: String
        get() {
            val gate = "Gate: US + Lab-resident bots only · flip ON only on the way out"
            return if (isOnline) "Mode: ONLINE link allowed as bonus. Offline seat still premier.\n$gate\nLast flip: $lastOnlineBy · $lastOnlineContext"
            else "Mode: OFFLINE premier. Green nerve off.\n$gate"
        }

    /** Decider way-out flip (the switch press, or typed `online` / `go online`). */
    fun goOnline(): String {
        lastOnlineBy = "US-Decider"
        lastOnlineContext = "way_out"
        set(true)
        return "ONLINE · way-out flip by $lastOnlineBy.\n$label"
    }

    fun goOffline(reason: String = "home"): String {
        set(false)
        return "OFFLINE premier ($reason).\n$label"
    }

    /** ClayModeButton tap: isOnline.toggle() — returns the Swift `mode` reply (ModeStore.label). */
    fun toggle(): String {
        if (isOnline) goOffline("toggle") else goOnline()
        return label
    }

    fun iconRes(): Int = if (isOnline) R.drawable.btnonline else R.drawable.btnoffline
    fun help(): String = if (isOnline) "ONLINE — tap for offline" else "OFFLINE — tap for online"
}
