package app.shieldpal.shieldpal

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject
import java.util.Locale

/** Loud, clear warnings: notification + alarm sound + spoken voice. */
object Alerts {
    private const val CH_ALARM = "threats_alarm"
    private const val CH_QUIET = "threats_quiet"
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private val pendingSpeech = ArrayList<String>()

    private fun ensureChannels(ctx: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = ctx.getSystemService(NotificationManager::class.java)
        val name = NativeStore.text(ctx, "txt_channel", "Threat alerts")
        if (nm.getNotificationChannel(CH_ALARM) == null) {
            val ch = NotificationChannel(CH_ALARM, name, NotificationManager.IMPORTANCE_HIGH)
            ch.enableVibration(true)
            ch.vibrationPattern = longArrayOf(0, 400, 200, 400, 200, 600)
            ch.setSound(
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
            )
            nm.createNotificationChannel(ch)
        }
        if (nm.getNotificationChannel(CH_QUIET) == null) {
            nm.createNotificationChannel(NotificationChannel(CH_QUIET, "$name (quiet)", NotificationManager.IMPORTANCE_HIGH))
        }
    }

    fun show(ctx: Context, id: Int, title: String, body: String) {
        ensureChannels(ctx)
        val cfg = NativeStore.config(ctx)
        val channel = if (cfg.optBoolean("alarm", true)) CH_ALARM else CH_QUIET
        val open = Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val pi = PendingIntent.getActivity(ctx, id, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val n = NotificationCompat.Builder(ctx, channel)
            .setSmallIcon(R.drawable.ic_stat_shield)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setColor(0xFFEF4444.toInt())
            .setAutoCancel(true)
            .setContentIntent(pi)
            .build()
        try {
            NotificationManagerCompat.from(ctx).notify(id, n)
        } catch (e: SecurityException) {
            // POST_NOTIFICATIONS not granted - the threat is still saved in the log.
        }
    }

    /** Pet voice chosen in Settings: exact voice, tone and speed. */
    private fun applyVoice(cfg: JSONObject) {
        val t = tts ?: return
        try {
            val name = cfg.optString("ttsVoice", "")
            if (name.isNotEmpty()) {
                t.voices?.firstOrNull { it.name == name }?.let { t.voice = it }
            }
        } catch (e: Exception) {
        }
        t.setPitch(cfg.optDouble("ttsPitch", 1.25).toFloat())
        t.setSpeechRate(cfg.optDouble("ttsRate", 0.48).toFloat() * 2f)
    }

    /** Called when the language changes so the next warning uses the new voice. */
    fun resetVoice() {
        Handler(Looper.getMainLooper()).post {
            tts?.shutdown()
            tts = null
            ttsReady = false
        }
    }

    fun speak(ctx: Context, text: String) {
        val cfg = NativeStore.config(ctx)
        if (!cfg.optBoolean("voice", true)) return
        Handler(Looper.getMainLooper()).post {
            if (tts == null) {
                tts = TextToSpeech(ctx.applicationContext) { status ->
                    ttsReady = status == TextToSpeech.SUCCESS
                    if (ttsReady) {
                        val tag = cfg.optString("tts", "en-US")
                        val r = tts?.setLanguage(Locale.forLanguageTag(tag))
                        if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) {
                            tts?.setLanguage(Locale.ENGLISH)
                        }
                        applyVoice(cfg)
                        pendingSpeech.forEach { tts?.speak(it, TextToSpeech.QUEUE_ADD, null, "sp") }
                        pendingSpeech.clear()
                    }
                }
                pendingSpeech.add(text)
            } else if (ttsReady) {
                tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "sp")
            } else {
                pendingSpeech.add(text)
            }
        }
    }

    /** Saves the threat, alerts the user and tells the app (if it is open). */
    fun raise(ctx: Context, threat: JSONObject, title: String, body: String, speech: String) {
        NativeStore.addThreat(ctx, threat)
        show(ctx, (threat.optString("id").hashCode() and 0x7fffffff), title, body)
        speak(ctx, speech)
        MainActivity.sendThreat(threat.toString())
    }
}
