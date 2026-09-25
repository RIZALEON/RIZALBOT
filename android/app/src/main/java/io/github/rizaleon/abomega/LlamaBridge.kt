package io.github.rizaleon.abomega

import android.util.Log

/**
 * JNI bridge to libyabot_llama.so (arm64-v8a).
 * Safe when .so missing — nativeAvailable=false; OfflineCommandRouter still works.
 */
object LlamaBridge {
    private const val TAG = "LlamaBridge"

    @Volatile
    var nativeAvailable: Boolean = false
        private set

    private var error: String = ""

    init {
        try {
            System.loadLibrary("yabot_llama")
            nativeAvailable = true
            Log.i(TAG, "libyabot_llama loaded")
        } catch (t: Throwable) {
            nativeAvailable = false
            error = "loadLibrary: ${t.message}"
            Log.w(TAG, "libyabot_llama not available: ${t.message}")
        }
    }

    fun lastError(): String = when {
        error.isNotEmpty() -> error
        nativeAvailable -> try {
            nativeLastError()
        } catch (_: Throwable) {
            error
        }
        else -> error
    }

    fun loadModel(path: String): Boolean {
        if (!nativeAvailable) return false
        return try {
            nativeLoad(path).also { ok -> if (!ok) error = nativeLastError() }
        } catch (t: Throwable) {
            error = t.message ?: "loadModel"
            false
        }
    }

    fun generate(prompt: String, nPredict: Int): String {
        if (!nativeAvailable) return ""
        return try {
            nativeGenerate(prompt, nPredict)
        } catch (t: Throwable) {
            error = t.message ?: "generate"
            ""
        }
    }

    fun unload() {
        if (!nativeAvailable) return
        try {
            nativeUnload()
        } catch (_: Throwable) {
        }
    }

    @JvmStatic external fun nativeLoad(path: String): Boolean
    @JvmStatic external fun nativeGenerate(prompt: String, nPredict: Int): String
    @JvmStatic external fun nativeLastError(): String
    @JvmStatic external fun nativeUnload()
}
