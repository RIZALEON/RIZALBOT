package io.github.rizaleon.abomega

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.LinearLayout
import android.widget.TextView
import java.io.ByteArrayInputStream

/** Small clay UI helpers shared by the Game door, Workshop and Manual landings (Android twin of GameMenuChip). */
object ClayUi {
    val OFF_WHITE: Int = Color.parseColor("#F5F0E8")
    val ORANGE: Int = Color.parseColor("#E08A2E")

    fun dp(ctx: Context, v: Int): Int = (v * ctx.resources.displayMetrics.density).toInt()

    fun chip(ctx: Context, title: String, active: Boolean = false, tint: Int = ORANGE, onClick: (() -> Unit)? = null): TextView {
        return TextView(ctx).apply {
            text = title
            setTextColor(if (active) OFF_WHITE else Color.argb(220, 245, 240, 232))
            textSize = 12f
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(ctx, 12), dp(ctx, 6), dp(ctx, 12), dp(ctx, 6))
            background = GradientDrawable().apply {
                cornerRadius = dp(ctx, 16).toFloat()
                setColor(if (active) Color.argb(115, Color.red(tint), Color.green(tint), Color.blue(tint)) else Color.argb(140, 0, 0, 0))
                setStroke(dp(ctx, 1), Color.argb(if (active) 204 else 90, Color.red(tint), Color.green(tint), Color.blue(tint)))
            }
            gravity = Gravity.CENTER
            isClickable = onClick != null
            contentDescription = title
            onClick?.let { cb -> setOnClickListener { cb() } }
        }
    }

    fun text(ctx: Context, s: String, size: Float = 12f, color: Int = OFF_WHITE, bold: Boolean = false, mono: Boolean = false): TextView =
        TextView(ctx).apply {
            text = s
            textSize = size
            setTextColor(color)
            typeface = when {
                mono -> Typeface.MONOSPACE
                bold -> Typeface.DEFAULT_BOLD
                else -> Typeface.SANS_SERIF
            }
        }

    fun row(ctx: Context, spacingDp: Int = 8): LinearLayout = LinearLayout(ctx).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        showDividers = LinearLayout.SHOW_DIVIDER_MIDDLE
        dividerDrawable = GradientDrawable().apply { setSize(dp(ctx, spacingDp), 1); setColor(Color.TRANSPARENT) }
    }

    fun column(ctx: Context): LinearLayout = LinearLayout(ctx).apply { orientation = LinearLayout.VERTICAL }

    fun panelBg(ctx: Context, alpha: Int = 190): GradientDrawable = GradientDrawable().apply {
        cornerRadius = dp(ctx, 16).toFloat()
        setColor(Color.argb(alpha, 0, 0, 0))
        setStroke(dp(ctx, 1), Color.argb(110, 224, 138, 46))
    }

    fun lp(w: Int = ViewGroup.LayoutParams.MATCH_PARENT, h: Int = ViewGroup.LayoutParams.WRAP_CONTENT, weight: Float = 0f) =
        LinearLayout.LayoutParams(w, h, weight)

    fun escapeHtml(s: String): String = s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

    fun preHtml(title: String, body: String, light: Boolean = false): String {
        val bg = if (light) "#f7f3ea" else "#140e0a"
        val fg = if (light) "#1c140e" else "#efe6d6"
        return "<!DOCTYPE html><html><head><meta charset='utf-8'/><meta name='viewport' content='width=device-width,initial-scale=1'/>" +
            "<title>${escapeHtml(title)}</title><style>body{margin:0;background:$bg;color:$fg;font:13px/1.45 monospace;padding:12px}" +
            "pre{white-space:pre-wrap;word-wrap:break-word;margin:0}</style></head><body><pre>${escapeHtml(body)}</pre></body></html>"
    }

    /**
     * Sandbox WebView: JS on (game code needs it), every http/https request answered with an empty 403,
     * no navigation away, no content:// access. Local-only preview (same law as the Apple Workshop preview).
     */
    @SuppressLint("SetJavaScriptEnabled")
    fun sandboxWebView(ctx: Context, allowFile: Boolean, allowNet: () -> Boolean = { false }): WebView = WebView(ctx).apply {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.allowFileAccess = allowFile
        settings.allowContentAccess = false
        settings.mediaPlaybackRequiresUserGesture = true
        setBackgroundColor(Color.parseColor("#140e0a"))
        webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(view: WebView?, request: WebResourceRequest?): WebResourceResponse? {
                val scheme = request?.url?.scheme?.lowercase() ?: return null
                if (!allowNet() && (scheme == "http" || scheme == "https" || scheme == "ws" || scheme == "wss")) {
                    return WebResourceResponse("text/plain", "utf-8", 403, "Blocked", emptyMap(), ByteArrayInputStream(ByteArray(0)))
                }
                return null
            }

            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                val scheme = request?.url?.scheme?.lowercase() ?: return true
                if (allowNet() && (scheme == "http" || scheme == "https")) return false
                return !(scheme == "file" || scheme == "about" || scheme == "data")
            }
        }
    }

    fun gone(vararg vs: View?) { vs.forEach { it?.visibility = View.GONE } }
}
