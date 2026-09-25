package io.github.rizaleon.abomega

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Typeface
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.ScrollView
import android.widget.TextView
import java.nio.charset.Charset

/**
 * Offline clay landings for Lab / Wallet / Mind / Home / Bolte / Search.
 * Swaps middle content: slate image + asset text. Mode/Online is display toggle only.
 */
class OfflineLanding(
    private val context: Context,
    private val middle: FrameLayout,
    private val slate: ImageView,
    private val scroll: ScrollView,
    private val log: TextView
) {
    private var showingLanding: Boolean = false
    private var landingImage: ImageView? = null
    private var landingText: TextView? = null

    /** Swift ModeStore.isOnline (persisted; the ЯBAR switch shows it red/green). */
    fun isOnlineBonus(): Boolean = ModeStore.isOnline

    fun toggleOnlineLabel(): String = ModeStore.toggle()

    fun show(route: OfflineCommandRouter.BarRoute) {
        when (route) {
            OfflineCommandRouter.BarRoute.ONLINE -> {
                /* handled by toggle */
            }
            OfflineCommandRouter.BarRoute.HOME -> {
                hideLanding()
            }
            else -> showPanel(route)
        }
    }

    private fun showPanel(route: OfflineCommandRouter.BarRoute) {
        ensureViews()
        val img = landingImage!!
        val tv = landingText!!
        val assetImg = when (route) {
            OfflineCommandRouter.BarRoute.LAB -> "lab/LAB-CHAMBER-VOID.jpg"
            OfflineCommandRouter.BarRoute.WALLET -> null
            OfflineCommandRouter.BarRoute.MIND -> null
            OfflineCommandRouter.BarRoute.BOLTE -> null
            OfflineCommandRouter.BarRoute.SEARCH -> null
            else -> null
        }
        val textAsset = when (route) {
            OfflineCommandRouter.BarRoute.LAB -> "landings/lab.txt"
            OfflineCommandRouter.BarRoute.WALLET -> "landings/wallet.txt"
            OfflineCommandRouter.BarRoute.MIND -> "landings/mind.txt"
            OfflineCommandRouter.BarRoute.BOLTE -> "landings/bolte.txt"
            OfflineCommandRouter.BarRoute.SEARCH -> "landings/search.txt"
            OfflineCommandRouter.BarRoute.HOME -> "landings/home.txt"
            OfflineCommandRouter.BarRoute.ONLINE -> "landings/home.txt"
        }

        // Prefer chamber / landing bitmap; fall back to clayslate drawable
        var bound = false
        if (assetImg != null) {
            try {
                context.assets.open(assetImg).use { input ->
                    val bmp = BitmapFactory.decodeStream(input)
                    if (bmp != null) {
                        img.setImageBitmap(bmp)
                        img.scaleType = ImageView.ScaleType.CENTER_CROP
                        bound = true
                    }
                }
            } catch (_: Exception) {
            }
        }
        if (!bound) {
            img.setImageResource(R.drawable.clayslate)
            img.scaleType = ImageView.ScaleType.FIT_XY
            img.alpha = 0.85f
        } else {
            img.alpha = 1.0f
        }

        tv.text = readAsset(textAsset)
        slate.visibility = View.GONE
        scroll.visibility = View.GONE
        img.visibility = View.VISIBLE
        tv.visibility = View.VISIBLE
        showingLanding = true
    }

    fun hideLanding() {
        landingImage?.visibility = View.GONE
        landingText?.visibility = View.GONE
        slate.visibility = View.VISIBLE
        scroll.visibility = View.VISIBLE
        showingLanding = false
    }

    fun showing(): Boolean = showingLanding

    private fun ensureViews() {
        if (landingImage != null) return
        val img = ImageView(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            visibility = View.GONE
            contentDescription = "Offline landing"
        }
        val tv = TextView(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM
            ).also {
                it.setMargins(24, 24, 24, 24)
            }
            setTextColor(Color.parseColor("#F5F0E8"))
            setBackgroundColor(Color.parseColor("#99000000"))
            setPadding(28, 20, 28, 20)
            textSize = 15f
            typeface = Typeface.SANS_SERIF
            visibility = View.GONE
        }
        middle.addView(img)
        middle.addView(tv)
        landingImage = img
        landingText = tv
    }

    private fun readAsset(path: String): String {
        return try {
            context.assets.open(path).use { it.readBytes().toString(Charset.forName("UTF-8")).trim() }
        } catch (_: Exception) {
            path
        }
    }
}
