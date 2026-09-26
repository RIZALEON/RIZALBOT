package io.github.rizaleon.abomega

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebStorage
import android.webkit.WebView
import android.webkit.WebViewClient
import android.webkit.WebViewDatabase
import android.widget.EditText
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * ЯBROWSER (Android 0.3.3) — private full browser bar opened from the Я Game MENU (Igorot Headaxe panel).
 * PRIVATE: no addJavascriptInterface (no save / wallet / chain.propose bridge), no form data / passwords saved,
 * no cache (LOAD_NO_CACHE), and on close: history, cache, cookies, Web Storage and form data are cleared.
 * Quick buttons: offline game/index.html · https://rizal.info/game/ · https://rizal.pw/classroom/.
 */
class YaBrowser(private val ctx: Context, private val isOnline: () -> Boolean) {
    companion object {
        const val GAME = "https://rizal.info/game/"
        const val CLASSROOM = "https://rizal.pw/classroom/"
        const val CLASSROOM_FALLBACK = "https://rizaleon.github.io/rizal-pw/classroom/"

        fun resolve(raw: String): String? {
            val s = raw.trim()
            if (s.isEmpty()) return null
            val sc = Uri.parse(s).scheme?.lowercase()
            if (sc == "http" || sc == "https" || sc == "file") return s
            if (!s.contains(' ') && s.contains('.')) return "https://$s"
            return "https://duckduckgo.com/?q=" + Uri.encode(s)
        }
    }

    private var web: WebView? = null
    private var address: EditText? = null
    private var status: TextView? = null
    private fun dp(v: Int) = ClayUi.dp(ctx, v)
    private fun offlineGame() = GameWorkshop.playUrl(ctx).first

    private var root: View? = null

    /** Same browser view across re-renders (menu toggles keep the page); detached from any old parent first. */
    fun view(): View {
        val v = root ?: build().also { root = it }
        (v.parent as? ViewGroup)?.removeView(v)
        return v
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun build(): View {
        val col = ClayUi.column(ctx)
        val w = WebView(ctx).apply {
            settings.javaScriptEnabled = true           // modern sites need JS; NO JS interface is ever added
            settings.domStorageEnabled = true           // wiped on close
            settings.cacheMode = WebSettings.LOAD_NO_CACHE
            @Suppress("DEPRECATION") settings.saveFormData = false
            @Suppress("DEPRECATION") settings.savePassword = false
            settings.allowFileAccess = true             // offline game/index.html only
            settings.allowContentAccess = false
            @Suppress("DEPRECATION") settings.allowFileAccessFromFileURLs = false
            @Suppress("DEPRECATION") settings.allowUniversalAccessFromFileURLs = false
            settings.setGeolocationEnabled(false)
            settings.setSupportMultipleWindows(false)   // target=_blank opens here
            setBackgroundColor(Color.parseColor("#140e0a"))
            webChromeClient = WebChromeClient()
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                    val sc = request?.url?.scheme?.lowercase() ?: return true
                    return !(sc == "http" || sc == "https" || sc == "file" || sc == "about" || sc == "data")  // no app-scheme hand-offs
                }
                override fun onPageFinished(view: WebView?, url: String?) {
                    address?.setText(url ?: "")
                    status?.text = "private · nothing saved · no bridge"
                }
            }
        }
        web = w
        CookieManager.getInstance().setAcceptThirdPartyCookies(w, false)

        val bar = ClayUi.row(ctx, 6)
        bar.addView(ClayUi.chip(ctx, "◀") { if (w.canGoBack()) w.goBack() })
        bar.addView(ClayUi.chip(ctx, "▶") { if (w.canGoForward()) w.goForward() })
        bar.addView(ClayUi.chip(ctx, "↻") { w.reload() })
        bar.addView(ClayUi.chip(ctx, "⌂") { open(offlineGame()) })
        val addr = EditText(ctx).apply {
            hint = "ЯBROWSER · address or search"
            setHintTextColor(Color.argb(120, 245, 240, 232))
            setTextColor(ClayUi.OFF_WHITE)
            textSize = 12f
            isSingleLine = true
            imeOptions = EditorInfo.IME_ACTION_GO
            inputType = android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_VARIATION_URI or
                android.text.InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
            background = GradientDrawable().apply { cornerRadius = dp(8).toFloat(); setColor(Color.argb(120, 255, 255, 255)) }
            setPadding(dp(8), dp(4), dp(8), dp(4))
            setOnEditorActionListener { v, id, ev ->
                if (id == EditorInfo.IME_ACTION_GO || ev?.keyCode == KeyEvent.KEYCODE_ENTER) { resolve(v.text.toString())?.let { open(it) }; true } else false
            }
        }
        address = addr
        bar.addView(addr, ClayUi.lp(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        bar.addView(ClayUi.chip(ctx, "Go") { resolve(addr.text.toString())?.let { open(it) } })
        col.addView(bar)

        val quick = ClayUi.row(ctx, 6)
        quick.addView(ClayUi.chip(ctx, "Offline game") { open(offlineGame()) })
        quick.addView(ClayUi.chip(ctx, "rizal.info/game", tint = Color.CYAN) { open(GAME) })
        quick.addView(ClayUi.chip(ctx, "rizal.pw/classroom", tint = Color.CYAN) { open(CLASSROOM) })
        col.addView(HorizontalScrollView(ctx).apply { isHorizontalScrollBarEnabled = false; addView(quick) },
            ClayUi.lp().apply { topMargin = dp(6) })
        status = ClayUi.text(ctx, if (isOnline()) "private · nothing saved · no bridge" else "OFFLINE · web links need ONLINE", 10f,
            Color.argb(170, 245, 240, 232))
        col.addView(status, ClayUi.lp().apply { topMargin = dp(4) })
        col.addView(w, ClayUi.lp(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f).apply { topMargin = dp(6) })

        open(if (isOnline()) GAME else offlineGame())
        return col
    }

    fun open(url: String) {
        address?.setText(url)
        web?.loadUrl(url)
    }

    /** Close = wipe: history, cache, cookies, Web Storage, form data; then destroy the WebView. */
    fun wipe() {
        val w = web ?: return
        web = null
        root = null
        w.stopLoading()
        w.loadUrl("about:blank")
        w.clearHistory()
        w.clearCache(true)
        w.clearFormData()
        WebStorage.getInstance().deleteAllData()
        CookieManager.getInstance().removeAllCookies(null)
        CookieManager.getInstance().flush()
        @Suppress("DEPRECATION") WebViewDatabase.getInstance(ctx).clearFormData()
        WebViewDatabase.getInstance(ctx).clearHttpAuthUsernamePassword()
        (w.parent as? ViewGroup)?.removeView(w)
        w.destroy()
    }
}
