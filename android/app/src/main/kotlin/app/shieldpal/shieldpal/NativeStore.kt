package app.shieldpal.shieldpal

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Settings pushed from Flutter + threats caught while the app was closed. */
object NativeStore {
    private const val PREFS = "shieldpal_native"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun setConfig(ctx: Context, json: String) = prefs(ctx).edit().putString("config", json).apply()

    fun config(ctx: Context): JSONObject = try {
        JSONObject(prefs(ctx).getString("config", "{}") ?: "{}")
    } catch (e: Exception) {
        JSONObject()
    }

    /** Translated text from the config with {placeholders} filled in. */
    fun text(ctx: Context, key: String, fallback: String, args: Map<String, String> = emptyMap()): String {
        var s = config(ctx).optString(key, "").ifEmpty { fallback }
        for ((k, v) in args) s = s.replace("{$k}", v)
        return s
    }

    @Synchronized
    fun addThreat(ctx: Context, threat: JSONObject) {
        val arr = threats(ctx)
        val out = JSONArray().put(threat)
        for (i in 0 until minOf(arr.length(), 99)) out.put(arr.get(i))
        prefs(ctx).edit().putString("threats", out.toString()).apply()
    }

    fun threats(ctx: Context): JSONArray = try {
        JSONArray(prefs(ctx).getString("threats", "[]") ?: "[]")
    } catch (e: Exception) {
        JSONArray()
    }

    fun wipe(ctx: Context) = prefs(ctx).edit().clear().apply()

    fun clearThreats(ctx: Context) = prefs(ctx).edit().putString("threats", "[]").apply()

    fun incBlocked(ctx: Context) {
        val p = prefs(ctx)
        p.edit().putInt("vpn_blocked", p.getInt("vpn_blocked", 0) + 1).apply()
    }

    fun blocked(ctx: Context) = prefs(ctx).getInt("vpn_blocked", 0)

    /** Remembers recently seen notifications so one message alerts only once. */
    private val seen = LinkedHashSet<String>()

    @Synchronized
    fun firstTime(key: String): Boolean {
        if (seen.contains(key)) return false
        seen.add(key)
        if (seen.size > 300) seen.remove(seen.first())
        return true
    }
}
