package app.shieldpal.shieldpal

import android.Manifest
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Bridge between the Flutter UI and Android. FlutterFragmentActivity is
 * required for fingerprint unlock (local_auth).
 */
class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL = "shieldpal/device"
        private const val REQ_VPN = 4101
        private const val REQ_NOTIF = 4102
        private const val REQ_CONTACTS = 4103
        private const val REQ_WG = 4104
        private var channel: MethodChannel? = null
        private val main = Handler(Looper.getMainLooper())

        /** Live threat from a background service -> Flutter UI (if open). */
        fun sendThreat(json: String) {
            main.post { channel?.invokeMethod("onThreat", json) }
        }
    }

    private val io = Executors.newSingleThreadExecutor()
    private var pendingShared: String? = null
    private var vpnResult: MethodChannel.Result? = null
    private var contactsResult: MethodChannel.Result? = null
    private var wgResult: MethodChannel.Result? = null
    private var wgConfig: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingShared = sharedFrom(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val s = sharedFrom(intent) ?: return
        channel?.invokeMethod("onSharedText", s) ?: run { pendingShared = s }
    }

    /** Text shared from another app (Share → ShieldPal) or a tapped link (Safe Link Gate). */
    private fun sharedFrom(i: Intent?): String? = when (i?.action) {
        Intent.ACTION_SEND -> i.getStringExtra(Intent.EXTRA_TEXT)
        Intent.ACTION_VIEW -> i.dataString?.takeIf { it.startsWith("http") }?.let { "gate:$it" }
        else -> null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "runAudit" -> io.execute {
                    val json = try {
                        DeviceAuditor(this).run().toString()
                    } catch (e: Exception) {
                        null
                    }
                    main.post { if (json != null) result.success(json) else result.error("audit", "failed", null) }
                }
                "getThreats" -> result.success(NativeStore.threats(this).toString())
                "clearThreats" -> {
                    NativeStore.clearThreats(this)
                    result.success(null)
                }
                "isNotificationAccessGranted" ->
                    result.success(NotificationManagerCompat.getEnabledListenerPackages(this).contains(packageName))
                "openNotificationAccess" -> {
                    openSettings(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "notificationsAllowed" -> result.success(NotificationManagerCompat.from(this).areNotificationsEnabled())
                "requestNotifications" -> {
                    if (Build.VERSION.SDK_INT >= 33 &&
                        ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                    ) {
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIF)
                    }
                    result.success(null)
                }
                "uninstall" -> {
                    val pkg = call.arguments as String
                    openSettings(Intent(Intent.ACTION_DELETE, Uri.parse("package:$pkg")))
                    result.success(null)
                }
                "openAppDetails" -> {
                    val pkg = call.arguments as String
                    openSettings(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg")))
                    result.success(null)
                }
                "fix" -> {
                    DeviceAuditor(this).fixIntent(call.arguments as String)?.let { openSettings(it) }
                    result.success(null)
                }
                "getInitialShared" -> {
                    result.success(pendingShared)
                    pendingShared = null
                }
                "openInBrowser" -> result.success(openInBrowser(call.arguments as String))
                "openLink" -> result.success(openLink(call.arguments as String))
                "wipeNative" -> {
                    NativeStore.wipe(this)
                    result.success(null)
                }
                "contactsAllowed" ->
                    result.success(ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED)
                "requestContacts" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else {
                        contactsResult = result
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_CONTACTS), REQ_CONTACTS)
                    }
                }
                "lookupContact" -> {
                    val number = call.arguments as String
                    io.execute {
                        val name = contactName(number)
                        main.post { result.success(name) }
                    }
                }
                "setConfig" -> {
                    NativeStore.setConfig(this, call.arguments as String)
                    Alerts.resetVoice()
                    result.success(null)
                }
                "startVpn" -> {
                    val prep = VpnService.prepare(this)
                    if (prep == null) {
                        startVpnService()
                        result.success(true)
                    } else {
                        vpnResult = result
                        @Suppress("DEPRECATION")
                        startActivityForResult(prep, REQ_VPN)
                    }
                }
                "wgStart" -> {
                    val cfg = call.arguments as String
                    val prep = VpnService.prepare(this)
                    if (prep == null) {
                        startWg(cfg, result)
                    } else {
                        wgResult = result
                        wgConfig = cfg
                        @Suppress("DEPRECATION")
                        startActivityForResult(prep, REQ_WG)
                    }
                }
                "wgStop" -> io.execute {
                    WgManager.down(this)
                    main.post { result.success(null) }
                }
                "wgIsUp" -> io.execute {
                    val up = WgManager.isUp(this)
                    main.post { result.success(up) }
                }
                "stopVpn" -> {
                    startService(Intent(this, ShieldVpnService::class.java).setAction(ShieldVpnService.ACTION_STOP))
                    result.success(null)
                }
                "isVpnRunning" -> result.success(ShieldVpnService.running)
                "vpnBlockedCount" -> result.success(NativeStore.blocked(this))
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    @Deprecated("Needed for the VPN permission dialog")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_WG) {
            val r = wgResult
            val cfg = wgConfig
            wgResult = null
            wgConfig = null
            if (resultCode == RESULT_OK && r != null && cfg != null) startWg(cfg, r) else r?.success("permission")
            return
        }
        if (requestCode == REQ_VPN) {
            val ok = resultCode == RESULT_OK
            if (ok) startVpnService()
            vpnResult?.success(ok)
            vpnResult = null
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_CONTACTS) {
            contactsResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            contactsResult = null
        }
    }

    /** Name saved in the user's own contacts for this number (looked up on the phone only). */
    private fun contactName(number: String): String? {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) return null
        return try {
            val uri = Uri.withAppendedPath(android.provider.ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(number))
            contentResolver.query(uri, arrayOf(android.provider.ContactsContract.PhoneLookup.DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst()) it.getString(0) else null
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun startVpnService() {
        // Only one VPN can run: switch the remote WireGuard VPN off first.
        io.execute {
            WgManager.down(this)
            main.post { startService(Intent(this, ShieldVpnService::class.java)) }
        }
    }

    /** Remote VPN on: stop Shield (local filter) first, then bring the WireGuard tunnel up. */
    private fun startWg(config: String, result: MethodChannel.Result) {
        startService(Intent(this, ShieldVpnService::class.java).setAction(ShieldVpnService.ACTION_STOP))
        io.execute {
            Thread.sleep(600)
            val err = WgManager.up(this, config)
            main.post { result.success(err) }
        }
    }

    private fun openSettings(i: Intent) {
        try {
            startActivity(i)
        } catch (e: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_SETTINGS))
            } catch (_: Exception) {
            }
        }
    }

    /**
     * Opens a link in the app that owns it (YouTube, Instagram, Maps...) when
     * one is installed, otherwise in a normal browser. Never in ShieldPal.
     */
    private fun openLink(url: String): Boolean {
        val view = Intent(Intent.ACTION_VIEW, Uri.parse(url)).addCategory(Intent.CATEGORY_BROWSABLE)
        fun handlers(i: Intent): List<String> {
            val l = if (Build.VERSION.SDK_INT >= 33) {
                packageManager.queryIntentActivities(i, PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_ALL.toLong()))
            } else {
                @Suppress("DEPRECATION") packageManager.queryIntentActivities(i, PackageManager.MATCH_ALL)
            }
            return l.map { it.activityInfo.packageName }.filter { it != packageName }.distinct()
        }
        val generic = Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com/")).addCategory(Intent.CATEGORY_BROWSABLE)
        val browsers = handlers(generic).toSet()
        val specific = handlers(view).filter { it !in browsers }
        val pkg = specific.firstOrNull() ?: return openInBrowser(url)
        return try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).setPackage(pkg))
            true
        } catch (e: Exception) {
            openInBrowser(url)
        }
    }

    /**
     * Opens a link in a real browser - never in ShieldPal itself, even if the
     * user made ShieldPal the default "browser" for the Safe Link Gate.
     */
    private fun openInBrowser(url: String): Boolean {
        val view = Intent(Intent.ACTION_VIEW, Uri.parse(url)).addCategory(Intent.CATEGORY_BROWSABLE)
        val candidates = if (Build.VERSION.SDK_INT >= 33) {
            packageManager.queryIntentActivities(view, PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_ALL.toLong()))
        } else {
            @Suppress("DEPRECATION") packageManager.queryIntentActivities(view, PackageManager.MATCH_ALL)
        }.filter { it.activityInfo.packageName != packageName }
        if (candidates.isEmpty()) return false
        val preferred = listOf("com.android.chrome", "org.mozilla.firefox", "com.sec.android.app.sbrowser", "com.brave.browser",
            "com.microsoft.emmx", "com.opera.browser", "com.duckduckgo.mobile.android")
        val pick = candidates.firstOrNull { it.activityInfo.packageName in preferred } ?: candidates.first()
        return try {
            startActivity(view.setComponent(ComponentName(pick.activityInfo.packageName, pick.activityInfo.name))
                )
            true
        } catch (e: Exception) {
            false
        }
    }
}
