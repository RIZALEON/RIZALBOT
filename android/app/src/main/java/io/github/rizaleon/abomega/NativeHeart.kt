package io.github.rizaleon.abomega

import android.content.Context
import android.util.Log
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Android Heart seat — GGUF from getFilesDir()/heart.gguf (NOT in APK).
 * Prefer ~1.5B coder on emulator RAM; 3B OK if device has headroom.
 */
class NativeHeart(private val context: Context) {
    companion object {
        private const val TAG = "NativeHeart"
        private const val HEART_NAME = "heart.gguf"
        private val baseSystemPrompt =
            "You are ЯBOT. One short offline reply."
    }

    private val loaded = AtomicBoolean(false)
    private var lastError: String = ""
    private var heartBytes: Long = 0
    private var modelLabel: String = "none"

    fun heartFile(): File = File(context.filesDir, HEART_NAME)

    val seated: Boolean
        get() = loaded.get() && LlamaBridge.nativeAvailable

    fun statusLine(): String {
        val f = heartFile()
        val bytes = if (f.exists()) f.length() else heartBytes
        val seatedFlag = if (seated) "yes" else "no"
        val eng = if (LlamaBridge.nativeAvailable) "libyabot_llama" else "none"
        var line =
            "heart engine=$eng seated=$seatedFlag heartBytes=$bytes mode=offline-premier path=${f.absolutePath}"
        if (!LlamaBridge.nativeAvailable) {
            line += " · HOW: build JNI libyabot_llama.so (see HEART-SEAT-ANDROID.txt)"
        } else if (!f.exists() || bytes < 1024L) {
            line += " · HOW: adb push heart.gguf into filesDir (prefer 1.5B coder on emu)"
        } else if (!seated) {
            line += " · HOW: load failed: ${lastError.ifEmpty { "not loaded yet" }}"
        }
        if (modelLabel != "none") line += " · model=$modelLabel"
        return line
    }

    fun load(): Boolean {
        if (!LlamaBridge.nativeAvailable) {
            lastError = "native lib not loaded"
            Log.w(TAG, statusLine())
            return false
        }
        val f = heartFile()
        if (!f.exists() || f.length() < 1024L) {
            lastError = "heart.gguf missing at ${f.absolutePath}"
            Log.w(TAG, lastError)
            return false
        }
        heartBytes = f.length()
        modelLabel = when {
            heartBytes in 900_000_000L..1_300_000_000L -> "qwen25-1.5b-coder-ish"
            heartBytes in 1_800_000_000L..2_300_000_000L -> "qwen25-3b-chat-ish"
            else -> "gguf-$heartBytes"
        }
        return try {
            val ok = LlamaBridge.loadModel(f.absolutePath)
            if (ok) {
                loaded.set(true)
                lastError = ""
                Log.i(TAG, "Heart loaded · $modelLabel · $heartBytes bytes")
            } else {
                lastError = LlamaBridge.lastError().ifEmpty { "loadModel returned false" }
                loaded.set(false)
                Log.e(TAG, "Heart load failed: $lastError")
            }
            ok
        } catch (t: Throwable) {
            lastError = t.message ?: t.toString()
            loaded.set(false)
            Log.e(TAG, "Heart load exception", t)
            false
        }
    }

    fun generate(prompt: String): String {
        val user = prompt.trim()
        if (user.isEmpty()) return "I am here."
        if (!seated) {
            return offlinePremierFallback()
        }
        return try {
            val full = "$baseSystemPrompt\nUser: $user\nAssistant:"
            val out = LlamaBridge.generate(full, 16).trim()
            if (out.isEmpty()) {
                "Function 0 · Heart returned empty. Engine ran; no usable reply."
            } else {
                out
            }
        } catch (t: Throwable) {
            "Function 0 · Heart invoke failed: ${t.message}"
        }
    }

    fun offlinePremierFallback(): String {
        return "OFFLINE PREMIER · local mouth seated. Heart status: ${statusLine()}. " +
            "Say help · ping · mode · heart. Online is bonus label only."
    }
}
