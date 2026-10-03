package app.shieldpal.shieldpal

import android.app.Notification
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * "Live Guard". Android hands ShieldPal every new notification after the user
 * grants Notification access. The text is checked right here on the phone; if
 * a scam message or a dangerous link shows up, ShieldPal alerts immediately and
 * names the app and chat it came from - before the user taps the link.
 * It also watches for newly installed risky apps.
 */
class ShieldNotificationListener : NotificationListenerService() {

    private val worker = Executors.newSingleThreadExecutor()
    private var installReceiver: BroadcastReceiver? = null

    // Apps whose notifications are chats, so a scary text without a link is still worth a warning.
    private val messagingApps = setOf(
        "com.whatsapp", "com.whatsapp.w4b", "org.telegram.messenger", "org.thunderdog.challegram",
        "com.facebook.orca", "com.facebook.katana", "com.instagram.android", "com.snapchat.android",
        "com.google.android.apps.messaging", "com.samsung.android.messaging", "com.android.mms",
        "com.android.messaging", "com.viber.voip", "com.imo.android.imoim", "jp.naver.line.android",
        "com.discord", "com.google.android.gm", "com.microsoft.office.outlook", "org.thoughtcrime.securesms",
        "com.zhiliaoapp.musically", "com.ss.android.ugc.trill", "com.twitter.android", "com.truecaller",
        "com.miui.smsextra", "com.oneplus.mms", "com.coloros.mms", "com.google.android.apps.googlevoice",
    )

    override fun onListenerConnected() {
        super.onListenerConnected()
        // Watch for new apps while Live Guard runs (manifest receivers can't on Android 8+).
        if (installReceiver == null) {
            installReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    if (intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)) return
                    val pkg = intent.data?.schemeSpecificPart ?: return
                    worker.execute { checkNewApp(pkg) }
                }
            }
            val f = IntentFilter(Intent.ACTION_PACKAGE_ADDED).apply { addDataScheme("package") }
            ContextCompat.registerReceiver(this, installReceiver, f, ContextCompat.RECEIVER_EXPORTED)
        }
    }

    override fun onListenerDisconnected() {
        installReceiver?.let { runCatching { unregisterReceiver(it) } }
        installReceiver = null
        super.onListenerDisconnected()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val pkg = sbn.packageName ?: return
        if (pkg == packageName || pkg == "android" || pkg == "com.android.systemui") return
        val n = sbn.notification ?: return
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val ex = n.extras ?: return
        val (chat, text) = readMessage(ex)
        if (text.isBlank()) return
        if (!NativeStore.firstTime("$pkg|$text")) return
        worker.execute { analyze(pkg, chat, text) }
    }

    /** Pulls sender / chat name and message text out of a notification. */
    private fun readMessage(ex: Bundle): Pair<String, String> {
        val title = ex.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val convo = ex.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)?.toString().orEmpty()
        var text = ""
        var sender = ""
        // MessagingStyle (WhatsApp, Telegram, Messages...): take the newest message.
        val msgs = ex.getParcelableArray(Notification.EXTRA_MESSAGES)
        if (msgs != null && msgs.isNotEmpty()) {
            val last = msgs.last() as? Bundle
            text = last?.getCharSequence("text")?.toString().orEmpty()
            sender = last?.getCharSequence("sender")?.toString().orEmpty()
        }
        if (text.isBlank()) {
            text = (ex.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: ex.getCharSequence(Notification.EXTRA_TEXT))
                ?.toString().orEmpty()
        }
        val lines = ex.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
        if (text.isBlank() && lines != null) text = lines.lastOrNull()?.toString().orEmpty()
        val chat = when {
            convo.isNotEmpty() && sender.isNotEmpty() -> "$convo · $sender"
            convo.isNotEmpty() -> convo
            sender.isNotEmpty() -> sender
            else -> title
        }
        return chat to text
    }

    private fun appLabel(pkg: String): String = try {
        packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
    } catch (e: Exception) {
        pkg
    }

    private fun analyze(pkg: String, chat: String, text: String) {
        val app = appLabel(pkg)
        val urls = ScamHeuristics.extractUrls(text)
        var worstUrl = ""
        var worst = 0
        for (u in urls) {
            var s = ScamHeuristics.scoreUrl(u)
            if (s in 20..59 && googleFlags(u)) s = 100
            if (s < 60 && cloudFlags(u)) s = 95
            if (s > worst) {
                worst = s
                worstUrl = u
            }
        }
        val textScore = ScamHeuristics.scoreText(text)
        val now = System.currentTimeMillis()
        val pet = NativeStore.config(this).optString("petName", "Pip")
        val args = mapOf("app" to app, "chat" to chat.ifEmpty { app }, "url" to worstUrl, "pet" to pet)
        val linkRisk = maxOf(worst, if (worst >= 25) worst + textScore / 2 else 0).coerceAtMost(100)

        if (linkRisk >= 60) {
            val t = threat("link", now, app, chat, text, worstUrl, linkRisk)
            Alerts.raise(
                this, t,
                NativeStore.text(this, "txt_link_title", "⚠️ Dangerous link in {app}", args),
                NativeStore.text(this, "txt_link_body", "From \"{chat}\": {url} — don't open it!", args),
                NativeStore.text(this, "txt_speak_link", "Warning! Dangerous link. Do not open it!", args),
            )
        } else if (pkg in messagingApps && textScore >= 60) {
            val t = threat("message", now, app, chat, text, "", textScore)
            Alerts.raise(
                this, t,
                NativeStore.text(this, "txt_msg_title", "⚠️ Scam message in {app}", args),
                NativeStore.text(this, "txt_msg_body", "From \"{chat}\": this looks like a scam.", args),
                NativeStore.text(this, "txt_speak_msg", "Warning! This message looks like a scam.", args),
            )
        }
    }

    private fun threat(kind: String, time: Long, app: String, chat: String, text: String, url: String, score: Int) =
        JSONObject()
            .put("id", "n_${time}_${(text + url).hashCode()}")
            .put("time", time)
            .put("kind", kind)
            .put("app", app)
            .put("chat", chat)
            .put("text", text.take(1000))
            .put("url", url)
            .put("score", score)

    /**
     * Free, keyless reputation check: does Cloudflare's security DNS block this
     * website as malware / phishing? Only the website name is sent.
     */
    private fun cloudFlags(url: String): Boolean {
        if (!NativeStore.config(this).optBoolean("cloudCheck", true)) return false
        return try {
            val host = java.net.URI(if (url.contains("://")) url else "http://$url").host ?: return false
            if (host.matches(Regex("^[\\d.:]+$"))) return false
            val c = URL("https://security.cloudflare-dns.com/dns-query?name=${java.net.URLEncoder.encode(host, "UTF-8")}&type=A")
                .openConnection() as HttpURLConnection
            c.connectTimeout = 5000
            c.readTimeout = 5000
            c.setRequestProperty("accept", "application/dns-json")
            val j = JSONObject(c.inputStream.bufferedReader().readText())
            val answers = j.optJSONArray("Answer")
            var sink = false
            if (answers != null) {
                for (i in 0 until answers.length()) {
                    if (answers.getJSONObject(i).optString("data") == "0.0.0.0") sink = true
                }
            }
            val comment = j.optJSONArray("Comment")?.join(" ")?.lowercase() ?: ""
            sink || comment.contains("censored") || comment.contains("blocked")
        } catch (e: Exception) {
            false
        }
    }

    /** Optional Google Safe Browsing lookup when the user added a key. */
    private fun googleFlags(url: String): Boolean {
        val key = NativeStore.config(this).optString("safeBrowsingKey", "")
        if (key.isEmpty()) return false
        return try {
            val body = JSONObject()
                .put("client", JSONObject().put("clientId", "shieldpal").put("clientVersion", "1.0.0"))
                .put(
                    "threatInfo", JSONObject()
                        .put("threatTypes", org.json.JSONArray(listOf("MALWARE", "SOCIAL_ENGINEERING", "UNWANTED_SOFTWARE")))
                        .put("platformTypes", org.json.JSONArray(listOf("ANY_PLATFORM")))
                        .put("threatEntryTypes", org.json.JSONArray(listOf("URL")))
                        .put("threatEntries", org.json.JSONArray().put(JSONObject().put("url", url)))
                )
            val c = URL("https://safebrowsing.googleapis.com/v4/threatMatches:find?key=$key").openConnection() as HttpURLConnection
            c.requestMethod = "POST"
            c.connectTimeout = 6000
            c.readTimeout = 6000
            c.doOutput = true
            c.setRequestProperty("Content-Type", "application/json")
            c.outputStream.use { it.write(body.toString().toByteArray()) }
            val resp = c.inputStream.bufferedReader().readText()
            (JSONObject(resp).optJSONArray("matches")?.length() ?: 0) > 0
        } catch (e: Exception) {
            false
        }
    }

    private fun checkNewApp(pkg: String) {
        val risk = DeviceAuditor(this).assessPackage(pkg) ?: return
        if (risk.optInt("score") < 50) return
        val label = risk.optString("label", pkg)
        val now = System.currentTimeMillis()
        val pet = NativeStore.config(this).optString("petName", "Pip")
        val args = mapOf("app" to label, "pet" to pet)
        val t = JSONObject()
            .put("id", "app_${now}_$pkg")
            .put("time", now)
            .put("kind", "app")
            .put("app", "Android")
            .put("chat", label)
            .put("text", risk.optJSONArray("reasons")?.join(", ")?.replace("\"", "") ?: "")
            .put("url", pkg)
            .put("score", risk.optInt("score"))
        Alerts.raise(
            this, t,
            NativeStore.text(this, "txt_app_title", "⚠️ Risky app installed", args),
            NativeStore.text(this, "txt_app_body", "\"{app}\" has dangerous powers. Tap to review.", args),
            NativeStore.text(this, "txt_speak_app", "Warning! A risky app was just installed.", args),
        )
    }
}
