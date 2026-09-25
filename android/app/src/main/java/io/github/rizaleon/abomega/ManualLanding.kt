package io.github.rizaleon.abomega

import android.app.Activity
import android.graphics.BitmapFactory
import android.graphics.Color
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout

/**
 * ЯMANUAL landing — Android twin of Swift ManualLandingView. `manual` / `yamanual` / Bolte open it.
 * Books bundled in assets/mind/books: YAMANUAL.md (the one fixed manual) + GAMEWRITE-FUNDAMENTALS-0.1.md.
 * Rendered in-app (no external PDF intent → no FileUriExposed crash on API 24+).
 */
class ManualLanding(
    private val activity: Activity,
    private val middle: FrameLayout,
    private val onHome: () -> Unit
) {
    private val ctx = activity
    private var root: FrameLayout? = null
    private var showing = false
    private var book = "mind/books/YAMANUAL.md"

    fun showing() = showing

    fun show(bookAsset: String? = null) {
        bookAsset?.let { book = it }
        if (root == null) {
            root = FrameLayout(ctx).apply {
                layoutParams = FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
                isClickable = true
                setBackgroundColor(Color.argb(240, 12, 8, 6))
            }
            middle.addView(root)
        }
        showing = true
        root!!.visibility = View.VISIBLE
        root!!.bringToFront()
        render()
    }

    fun hide() {
        root?.visibility = View.GONE
        showing = false
    }

    private fun dp(v: Int) = ClayUi.dp(ctx, v)

    private fun render() {
        val r = root ?: return
        r.removeAllViews()
        val col = ClayUi.column(ctx).apply { setPadding(dp(10), dp(10), dp(10), dp(10)) }
        val header = ClayUi.row(ctx, 10)
        val cover = ImageView(ctx).apply { scaleType = ImageView.ScaleType.FIT_CENTER }
        try {
            ctx.assets.open("mind/books/YAMANUAL-COVER.png").use { cover.setImageBitmap(BitmapFactory.decodeStream(it)) }
        } catch (_: Exception) {
            cover.setImageResource(R.drawable.bolte)
        }
        header.addView(cover, LinearLayout.LayoutParams(dp(44), dp(56)))
        val t = ClayUi.column(ctx)
        t.addView(ClayUi.text(ctx, "ЯMANUAL", 20f, bold = true))
        t.addView(ClayUi.text(ctx, "one fixed app manual · offline · assets/$book", 10f, Color.argb(180, 245, 240, 232)))
        header.addView(t, ClayUi.lp(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        header.addView(ClayUi.chip(ctx, "⌂ Home") { onHome() })
        col.addView(header)

        val chips = ClayUi.row(ctx, 8)
        chips.addView(ClayUi.chip(ctx, "ЯMANUAL", active = book.endsWith("YAMANUAL.md")) { book = "mind/books/YAMANUAL.md"; render() })
        chips.addView(ClayUi.chip(ctx, "GAMEWRITE-FUNDAMENTALS", active = book.contains("GAMEWRITE")) { book = "mind/books/GAMEWRITE-FUNDAMENTALS-0.1.md"; render() })
        col.addView(chips, ClayUi.lp().apply { topMargin = dp(8); bottomMargin = dp(8) })

        val text = try {
            ctx.assets.open(book).use { it.readBytes().toString(Charsets.UTF_8) }
        } catch (e: Exception) {
            "$book not seated in assets (${e.message})"
        }
        val web = ClayUi.sandboxWebView(ctx, allowFile = false)
        web.loadDataWithBaseURL(null, ClayUi.preHtml(book, text, light = true), "text/html", "utf-8", null)
        col.addView(web, ClayUi.lp(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        r.addView(col, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
    }
}
