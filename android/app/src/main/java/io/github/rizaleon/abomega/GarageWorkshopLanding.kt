package io.github.rizaleon.abomega

import android.content.Context
import android.graphics.Color
import android.text.Editable
import android.text.TextWatcher
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast

/**
 * Garage workshop landing — Android twin of Swift GarageWorkshopLandingView (ЯBOT 0.3.3).
 * Room image + left sidebar. Housed bots = Garage roster (BotRoster · <ext>/ЯBOT/seat/BOT-LABELS.json v3),
 * with faces (BotFaceYaBot / BotFaceYaMax) and shelf↔list selection. + Create new Bot requires a name
 * (the designated name it speaks with; reserved / numbered / Garage / duplicate names refused).
 * Work strip: "Working with <Name>" · Speak (bot enter) / Я speaks (bot leave) · Clear.
 * Naming law 2026-09-24: Я = Machine Mind; the bots are its kids with their Garage names.
 * Hosted under sticky ЯBAR inside activity_main middle.
 */
class GarageWorkshopLanding(
    private val context: Context,
    private val middle: FrameLayout,
    private val slate: ImageView,
    private val scroll: ScrollView,
    private val log: TextView
) {
    private var root: View? = null
    private var selectedBotId: String? = null
    private var showing: Boolean = false
    private var lane: String = "bots"
    private var search: String = ""
    private var hint: String = ""

    fun showing(): Boolean = showing

    fun show() {
        ensure()
        val v = root!!
        slate.visibility = View.GONE
        scroll.visibility = View.GONE
        for (i in 0 until middle.childCount) {
            val child = middle.getChildAt(i)
            if (child !== v && child !== slate && child !== scroll && child.id != R.id.btn_jump_latest) {
                child.visibility = View.GONE
            }
        }
        v.visibility = View.VISIBLE
        v.bringToFront()
        showing = true
        BotRoster.reload()
        selectedBotId = null
        hint = ""
        refresh()
        Log.i("GarageWorkshop", "show garage · ${BotRoster.rosterNamesLine()} housed")
    }

    fun hide() {
        root?.visibility = View.GONE
        showing = false
        selectedBotId = null
        hideKeyboard()
    }

    private fun dp(n: Int) = (n * context.resources.displayMetrics.density).toInt()

    private fun ensure() {
        if (root != null) return
        val v = LayoutInflater.from(context).inflate(R.layout.garage_workshop_landing, middle, false)
        middle.addView(v, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
        root = v

        v.findViewById<EditText>(R.id.garage_search).addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
            override fun onTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
            override fun afterTextChanged(s: Editable?) { search = s?.toString().orEmpty(); refresh() }
        })
        v.findViewById<View>(R.id.garage_nav_create).setOnClickListener {
            lane = if (lane == "create") "bots" else "create"
            refresh()
            if (lane == "create") v.findViewById<EditText>(R.id.garage_create_name).requestFocus()
        }
        val nameField = v.findViewById<EditText>(R.id.garage_create_name)
        v.findViewById<View>(R.id.garage_create_go).setOnClickListener { createBot() }
        nameField.setOnEditorActionListener { _, id, _ ->
            if (id == EditorInfo.IME_ACTION_DONE) { createBot(); true } else false
        }
        v.findViewById<View>(R.id.garage_nav_bots).setOnClickListener { lane = "bots"; refresh() }
        v.findViewById<View>(R.id.garage_work_clear).setOnClickListener { selectedBotId = null; hint = ""; refresh() }
        v.findViewById<View>(R.id.garage_work_speak).setOnClickListener {
            val bot = selectedBot() ?: return@setOnClickListener
            hint = if (BotRoster.speaking == bot.display) {
                BotRoster.leave()
                "${bot.display} left the chat · Я — the Machine Mind — speaks"
            } else {
                BotRoster.enter(bot.display).lineSequence().first()
            }
            refresh()
        }
        val stubs = mapOf(
            R.id.garage_nav_marketplace to "market",
            R.id.garage_nav_stats to "stats",
            R.id.garage_nav_data to "data"
        )
        // 0.3.3 · Training lane = CLASSROOM (lessons · submit · scores)
        v.findViewById<View>(R.id.garage_nav_training)?.setOnClickListener { openTraining() }
        for ((id, key) in stubs) {
            v.findViewById<View>(id)?.setOnClickListener {
                lane = key
                val label = (it as? TextView)?.text?.toString() ?: key
                Toast.makeText(context, "Garage · $label stub", Toast.LENGTH_SHORT).show()
                refresh()
            }
        }
    }

    /** Garage → Training: classroom lessons for the selected bot (else the speaking bot, else ЯBOT). */
    fun openTraining() {
        lane = "training"
        refresh()
        val learner = selectedBot()?.display ?: BotRoster.speaking ?: BotRoster.housed().firstOrNull()?.display ?: "ЯBOT"
        Log.i("GarageWorkshop", "training lane · classroom · learner=$learner")
        ClassroomStore.showTraining(context, learner)
    }

    private fun selectedBot(): BotRoster.Bot? = BotRoster.housed().firstOrNull { it.id == selectedBotId }

    private fun pick(id: String) {
        if (selectedBotId == id) { selectedBotId = null; hint = "" } else { selectedBotId = id; lane = "bots"; hint = "" }
        refresh()
        Log.i("GarageWorkshop", "selectedBotId=$selectedBotId")
    }

    private fun createBot() {
        val v = root ?: return
        val field = v.findViewById<EditText>(R.id.garage_create_name)
        val (bot, msg) = BotRoster.createBot(field.text?.toString().orEmpty())
        val note = v.findViewById<TextView>(R.id.garage_create_note)
        note.text = msg.lineSequence().first()
        note.visibility = View.VISIBLE
        if (bot != null) {
            field.setText("")
            selectedBotId = bot.id
            lane = "bots"
            hint = "Created · ${bot.display} — Я's newest bot"
            hideKeyboard()
        }
        refresh()
    }

    private fun hideKeyboard() {
        val v = root ?: return
        (context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager)?.hideSoftInputFromWindow(v.windowToken, 0)
    }

    private fun filtered(): List<BotRoster.Bot> {
        val q = search.trim().lowercase()
        val all = BotRoster.housed()
        if (q.isEmpty()) return all
        return all.filter { b -> (b.names() + b.look).any { it.lowercase().contains(q) } }
    }

    private fun faceView(bot: BotRoster.Bot, sizeDp: Int): View {
        val res = bot.faceRes()
        return if (res != null) ImageView(context).apply {
            setImageResource(res)
            scaleType = ImageView.ScaleType.FIT_CENTER
            layoutParams = LinearLayout.LayoutParams(dp(sizeDp), dp(sizeDp))
            contentDescription = bot.display
        } else TextView(context).apply {
            // no face asset yet (Garage-created bot): clay initial
            text = bot.display.take(1)
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#F5F0E8"))
            textSize = (sizeDp / 2.4f)
            setBackgroundColor(Color.parseColor("#5538A8C8"))
            layoutParams = LinearLayout.LayoutParams(dp(sizeDp), dp(sizeDp))
        }
    }

    private fun refresh() {
        val v = root ?: return
        val speaking = BotRoster.speaking
        v.findViewById<View>(R.id.garage_create_panel).visibility = if (lane == "create") View.VISIBLE else View.GONE

        // roster rows
        val list = v.findViewById<LinearLayout>(R.id.garage_bot_list)
        list.removeAllViews()
        val bots = filtered()
        if (bots.isEmpty()) {
            list.addView(TextView(context).apply {
                text = if (search.isBlank()) "No housed bots yet · + Create new Bot" else "no match"
                setTextColor(Color.parseColor("#8A7C70")); textSize = 11f
            })
        }
        for (b in bots) {
            val row = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(6), dp(6), dp(4), dp(6))
                setBackgroundColor(Color.parseColor(if (selectedBotId == b.id) "#55C9A227" else "#00000000"))
                isClickable = true
                contentDescription = "${b.display}, ${b.look}"
                setOnClickListener { pick(b.id) }
            }
            row.addView(faceView(b, 28))
            row.addView(TextView(context).apply {
                text = b.display + (if (speaking == b.display) " · speaking" else "") + (if (b.look.isNotBlank()) "\n${b.look}" else "")
                setTextColor(Color.parseColor("#F5F0E8")); textSize = 12f
                setPadding(dp(6), 0, 0, 0)
            })
            list.addView(row)
        }

        // shelf faces (bots with a shelf spot: left first, then right, then others)
        val shelf = v.findViewById<LinearLayout>(R.id.garage_shelf)
        shelf.removeAllViews()
        val order = mapOf("left" to 0, "center" to 1, "right" to 2)
        BotRoster.housed().filter { it.shelf != null }.sortedBy { order[it.shelf] ?: 3 }.forEachIndexed { i, b ->
            val f = faceView(b, 72)
            (f.layoutParams as LinearLayout.LayoutParams).marginStart = if (i == 0) 0 else dp(12)
            f.setPadding(dp(4), dp(4), dp(4), dp(4))
            f.setBackgroundColor(Color.parseColor(if (selectedBotId == b.id) "#66C9A227" else "#33FFFFFF"))
            f.isClickable = true
            f.setOnClickListener { pick(b.id) }
            shelf.addView(f)
        }

        // work strip
        val strip = v.findViewById<View>(R.id.garage_work_strip)
        val bot = selectedBot()
        if (bot == null) {
            strip.visibility = View.GONE
        } else {
            v.findViewById<TextView>(R.id.garage_work_title).text = "Working with ${bot.display}"
            v.findViewById<TextView>(R.id.garage_work_hint).text = hint.ifEmpty {
                "speaks in chat as ${bot.display}" + (if (bot.gamewrite) " · gamewrite … as ${bot.id}" else " · no gamewrite (authors.json)")
            }
            v.findViewById<TextView>(R.id.garage_work_speak).text = if (speaking == bot.display) "Я speaks" else "Speak"
            strip.visibility = View.VISIBLE
        }

        v.findViewById<TextView>(R.id.garage_lane_hint).text = when {
            bot != null && speaking == bot.display -> "${bot.display} is speaking in chat (Я's bot)"
            bot != null -> if (bot.shelf != null) "Working with ${bot.display} — shelf linked" else "Working with ${bot.display}"
            lane == "create" -> "Name it as it will speak in chat · Я's new bot"
            lane == "market" -> "Stub · marketplace later"
            lane == "stats" -> "Stub · bot stats later"
            lane == "data" -> "Stub · bot data later"
            lane == "training" -> "Classroom · lessons · submit writes inbox/ only"
            else -> BotRoster.housed().map { it.display }.let {
                if (it.isEmpty()) "No housed bots yet · + Create new Bot" else "Я's bots · select " + it.joinToString(" or ")
            }
        }
    }
}
