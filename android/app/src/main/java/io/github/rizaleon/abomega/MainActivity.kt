package io.github.rizaleon.abomega

import android.os.Bundle
import android.widget.EditText
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.button.MaterialButton

/**
 * ABOMEGA 0.1 Android trifecta seat — clay mouth shell.
 * Offline premier · self-update law · Heart wire next (llama.android / GGUF).
 */
class MainActivity : AppCompatActivity() {
    private lateinit var log: TextView
    private lateinit var input: EditText
    private lateinit var scroll: ScrollView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        log = findViewById(R.id.log)
        input = findViewById(R.id.input)
        scroll = findViewById(R.id.scroll)
        findViewById<MaterialButton>(R.id.send).setOnClickListener { send() }
        append("System", "Trifecta seat live. Mode: OFFLINE PREMIER. Heart Android next.")
    }

    private fun send() {
        val text = input.text?.toString()?.trim().orEmpty()
        if (text.isEmpty()) return
        input.setText("")
        append("You", text)
        append("ЯBOT", reply(text))
    }

    private fun reply(text: String): String {
        val lower = text.lowercase()
        return when {
            lower == "ping" || lower == "pong" -> "pong · ABOMEGA Android 0.1 · trifecta"
            lower == "mode" || lower.contains("offline") -> "MODE: OFFLINE. PREMIER PATH. LOCAL MOUTH ONLY."
            lower == "help" || lower == "commands" -> "ping · mode · help · heart · ghost · law — Heart engine seats next."
            lower.startsWith("heart") -> "Function 0 · Android Heart next (GGUF / llama.cpp Android). Mac Heart remains premier."
            lower.contains("law") || lower.contains("source") -> "ЯOS GIVES SOURCE VALUE. App updates from itself. NonNuclear."
            lower.startsWith("evolve") -> "Evolve is Decider-gated. I cannot grant myself permission."
            else -> "Heard. Android clay mouth seated for ABOMEGA trifecta. Fuller CoS/Heart parity coming on-device."
        }
    }

    private fun append(who: String, msg: String) {
        log.append("\n\n$who: $msg")
        scroll.post { scroll.fullScroll(ScrollView.FOCUS_DOWN) }
    }
}
