package app.shieldpal.shieldpal

import android.Manifest
import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiInfo
import android.os.Build
import android.provider.Settings
import com.google.android.gms.safetynet.SafetyNet
import com.google.android.gms.tasks.Tasks
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit

/**
 * The Deep Scan. Looks at everything an app is allowed to look at on Android:
 * lock screen strength, updates, risky settings, apps with spying powers
 * (accessibility, device admin, notification access, SMS, hidden icon,
 * installed from outside the store) and Google Play Protect's verdict.
 */
class DeviceAuditor(private val ctx: Context) {
    private val pm = ctx.packageManager
    private val cr = ctx.contentResolver

    private val trustedInstallers = setOf(
        "com.android.vending", "com.google.android.feedback", "com.sec.android.app.samsungapps",
        "com.huawei.appmarket", "com.xiaomi.market", "com.xiaomi.mipicks", "com.oppo.market", "com.heytap.market",
        "com.vivo.appstore", "com.amazon.venezia", "com.transsion.phoenix", "com.android.packageinstaller.store",
    )
    private val trustedKeyboards = listOf(
        "com.google.android.inputmethod", "com.samsung.android.honeyboard", "com.sec.android.inputmethod",
        "com.touchtype.swiftkey", "com.microsoft.swiftkey", "com.baidu.input_mi", "com.miui", "com.huawei.ohos.inputmethod",
        "com.android.inputmethod", "com.oppo", "com.coloros", "com.vivo", "com.google.android.apps.inputmethod",
    )

    private fun label(pkg: String) = try {
        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
    } catch (e: Exception) {
        pkg
    }

    private fun isSystem(ai: ApplicationInfo) =
        ai.flags and (ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0

    /** A store we know, or any installer that is itself part of the phone's system image. */
    private fun isTrustedInstaller(inst: String): Boolean {
        if (inst in trustedInstallers) return true
        return try {
            (pm.getApplicationInfo(inst, 0).flags and ApplicationInfo.FLAG_SYSTEM) != 0
        } catch (e: Exception) {
            false
        }
    }

    private fun installer(pkg: String): String? = try {
        if (Build.VERSION.SDK_INT >= 30) pm.getInstallSourceInfo(pkg).installingPackageName
        else @Suppress("DEPRECATION") pm.getInstallerPackageName(pkg)
    } catch (e: Exception) {
        null
    }

    private fun appOpAllowed(op: String, uid: Int, pkg: String): Boolean = try {
        val ao = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= 29) ao.unsafeCheckOpNoThrow(op, uid, pkg)
        else @Suppress("DEPRECATION") ao.checkOpNoThrow(op, uid, pkg)
        mode == AppOpsManager.MODE_ALLOWED
    } catch (e: Exception) {
        false
    }

    private fun splitComponents(value: String?): Set<String> =
        value.orEmpty().split(':').mapNotNull { it.substringBefore('/').takeIf { p -> p.isNotBlank() } }.toSet()

    private val accessibilityPkgs by lazy {
        splitComponents(Settings.Secure.getString(cr, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES))
    }
    private val listenerPkgs by lazy {
        splitComponents(Settings.Secure.getString(cr, "enabled_notification_listeners")) - ctx.packageName
    }
    private val adminPkgs by lazy {
        val dpm = ctx.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        dpm.activeAdmins.orEmpty().map { it.packageName }.toSet()
    }

    private fun packages(): List<PackageInfo> =
        if (Build.VERSION.SDK_INT >= 33) {
            pm.getInstalledPackages(PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong()))
        } else {
            @Suppress("DEPRECATION") pm.getInstalledPackages(PackageManager.GET_PERMISSIONS)
        }

    private fun packageInfo(pkg: String): PackageInfo? = try {
        if (Build.VERSION.SDK_INT >= 33) {
            pm.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong()))
        } else {
            @Suppress("DEPRECATION") pm.getPackageInfo(pkg, PackageManager.GET_PERMISSIONS)
        }
    } catch (e: Exception) {
        null
    }

    /** Risk of one installed app, or null if it looks fine / is a system app. */
    fun assessPackage(pkg: String, harmful: Set<String> = emptySet()): JSONObject? {
        val info = packageInfo(pkg) ?: return null
        return assess(info, harmful)
    }

    private fun assess(info: PackageInfo, harmful: Set<String>): JSONObject? {
        val ai = info.applicationInfo ?: return null
        val pkg = info.packageName
        if (pkg == ctx.packageName) return null
        val inGoogleList = pkg in harmful
        if (isSystem(ai) && !inGoogleList) return null

        val granted = HashSet<String>()
        val req = info.requestedPermissions
        val flags = info.requestedPermissionsFlags
        if (req != null && flags != null) {
            for (i in req.indices) {
                if (flags[i] and PackageInfo.REQUESTED_PERMISSION_GRANTED != 0) granted.add(req[i])
            }
        }
        val requested = req?.toSet().orEmpty()
        val reasons = JSONArray()
        var score = 0
        fun add(reason: String, w: Int) {
            reasons.put(reason)
            score += w
        }

        val inst = installer(pkg)
        // Phone-maker pre-installs (e.g. Instagram put there by the Facebook system installer) are normal.
        val isSystemApp = (ai.flags and (ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP)) != 0
        val sideloaded = !isSystemApp && (inst == null || !isTrustedInstaller(inst))
        if (inGoogleList) add("r_google_harmful", 80)
        if (sideloaded) add("r_sideloaded", 20)
        if (pkg in accessibilityPkgs) add("r_accessibility", 35)
        if (pkg in adminPkgs) add("r_admin", 30)
        if (pkg in listenerPkgs) add("r_notif", 20)
        if (Manifest.permission.READ_SMS in granted || Manifest.permission.RECEIVE_SMS in granted) add("r_sms", 20)
        if (Manifest.permission.READ_CALL_LOG in granted) add("r_calls", 10)
        if (Manifest.permission.RECORD_AUDIO in granted) add("r_mic", 8)
        if (Manifest.permission.CAMERA in granted) add("r_camera", 4)
        if (Manifest.permission.ACCESS_FINE_LOCATION in granted || Manifest.permission.ACCESS_BACKGROUND_LOCATION in granted) {
            add("r_location", 6)
        }
        if (Manifest.permission.READ_CONTACTS in granted) add("r_contacts", 4)
        if (Manifest.permission.SYSTEM_ALERT_WINDOW in requested &&
            appOpAllowed("android:system_alert_window", ai.uid, pkg)
        ) add("r_overlay", 10)
        if (Manifest.permission.REQUEST_INSTALL_PACKAGES in requested &&
            appOpAllowed("android:request_install_packages", ai.uid, pkg)
        ) add("r_install_apps", 8)
        val hidden = pm.getLaunchIntentForPackage(pkg) == null
        if (hidden && score >= 20) add("r_hidden_icon", 25)
        if (System.currentTimeMillis() - info.firstInstallTime < TimeUnit.DAYS.toMillis(2) && score >= 30) {
            add("r_new_install", 5)
        }
        // Store apps with many permissions are usually normal (e.g. WhatsApp) -
        // only report them when they also hold the strongest spying powers.
        if (!sideloaded && !inGoogleList) {
            val strong = pkg in accessibilityPkgs || pkg in adminPkgs
            if (!strong) return null
            score = (score * 0.6).toInt()
        }
        score = score.coerceAtMost(100)
        if (score < 35) return null
        return JSONObject()
            .put("package", pkg)
            .put("label", label(pkg))
            .put("score", score)
            .put("reasons", reasons)
            .put("sideloaded", sideloaded)
            .put("admin", pkg in adminPkgs)
    }

    private fun check(id: String, status: String, detail: String = "", fix: String? = null) =
        JSONObject().put("id", id).put("status", status).put("detail", detail).apply { if (fix != null) put("fix", fix) }

    fun run(): JSONObject {
        val checks = JSONArray()

        // --- Lock screen ---
        val km = ctx.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val secure = km.isDeviceSecure
        checks.put(check("screen_lock", if (secure) "ok" else "bad", "", "set_new_password"))
        if (secure && Build.VERSION.SDK_INT >= 29) {
            try {
                val dpm = ctx.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                val (st, name) = when (dpm.passwordComplexity) {
                    DevicePolicyManager.PASSWORD_COMPLEXITY_HIGH -> "ok" to "high"
                    DevicePolicyManager.PASSWORD_COMPLEXITY_MEDIUM -> "warn" to "medium"
                    DevicePolicyManager.PASSWORD_COMPLEXITY_LOW -> "bad" to "pattern / simple PIN"
                    else -> "bad" to "none"
                }
                checks.put(check("lock_strength", st, name, "set_new_password"))
            } catch (e: Exception) {
            }
        }

        // --- System ---
        val patch = Build.VERSION.SECURITY_PATCH
        try {
            val d = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(patch)
            if (d != null) {
                val months = ((Date().time - d.time) / TimeUnit.DAYS.toMillis(30)).toInt()
                val st = if (months <= 3) "ok" else if (months <= 12) "warn" else "bad"
                checks.put(check("patch", st, patch, "system_update"))
            }
        } catch (e: Exception) {
        }
        val sdk = Build.VERSION.SDK_INT
        checks.put(
            check(
                "os_version", if (sdk >= 31) "ok" else if (sdk >= 29) "warn" else "bad",
                "Android ${Build.VERSION.RELEASE}", "system_update"
            )
        )
        val dev = Settings.Global.getInt(cr, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) == 1
        checks.put(check("dev_options", if (dev) "warn" else "ok", "", "developer"))
        val adb = Settings.Global.getInt(cr, Settings.Global.ADB_ENABLED, 0) == 1
        checks.put(check("usb_debug", if (adb) "bad" else "ok", "", "developer"))
        checks.put(check("root", if (isRooted()) "bad" else "ok"))

        // --- Hidden powers ---
        val accNames = accessibilityPkgs.filter { p ->
            try {
                !isSystem(pm.getApplicationInfo(p, 0))
            } catch (e: Exception) {
                true
            }
        }.map { label(it) }
        checks.put(check("accessibility", if (accNames.isEmpty()) "ok" else "warn", accNames.joinToString(), "accessibility"))
        val admins = adminPkgs.filter { p ->
            try {
                !isSystem(pm.getApplicationInfo(p, 0))
            } catch (e: Exception) {
                true
            }
        }.map { label(it) }
        checks.put(check("device_admin", if (admins.isEmpty()) "ok" else "warn", admins.joinToString(), "device_admin"))
        val listeners = listenerPkgs.filter { p ->
            try {
                !isSystem(pm.getApplicationInfo(p, 0))
            } catch (e: Exception) {
                true
            }
        }.map { label(it) }
        checks.put(check("notif_listeners", if (listeners.isEmpty()) "ok" else "warn", listeners.joinToString(), "notification_listeners"))
        val ime = Settings.Secure.getString(cr, Settings.Secure.DEFAULT_INPUT_METHOD).orEmpty().substringBefore('/')
        if (ime.isNotEmpty()) {
            val ok = trustedKeyboards.any { ime.startsWith(it) }
            checks.put(check("keyboard", if (ok) "ok" else "warn", label(ime), "keyboard"))
        }

        // --- Play Protect (Google's malware scanner) ---
        val harmful = HashSet<String>()
        try {
            val client = SafetyNet.getClient(ctx)
            val enabled = Tasks.await(client.isVerifyAppsEnabled, 8, TimeUnit.SECONDS).isVerifyAppsEnabled
            checks.put(check("play_protect", if (enabled) "ok" else "bad", "", "play_protect"))
            if (enabled) {
                val list = Tasks.await(client.listHarmfulApps(), 10, TimeUnit.SECONDS).harmfulAppsList
                list?.forEach { harmful.add(it.apkPackageName) }
            }
        } catch (e: Exception) {
            // Google Play services missing or busy - skip.
        }

        // --- Apps ---
        val apps = JSONArray()
        var scanned = 0
        val installers = ArrayList<String>()
        for (p in packages()) {
            scanned++
            val r = assess(p, harmful)
            if (r != null) apps.put(r)
            val ai = p.applicationInfo ?: continue
            if (!isSystem(ai) && p.requestedPermissions?.contains(Manifest.permission.REQUEST_INSTALL_PACKAGES) == true &&
                appOpAllowed("android:request_install_packages", ai.uid, p.packageName)
            ) installers.add(label(p.packageName))
        }
        checks.put(check("unknown_sources", if (installers.isEmpty()) "ok" else "warn", installers.joinToString(), "unknown_sources"))

        // --- Network ---
        try {
            val cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val caps = cm.getNetworkCapabilities(cm.activeNetwork)
            if (caps != null) {
                if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN) && !ShieldVpnService.running) {
                    checks.put(check("vpn_other", "warn", "", "vpn_settings"))
                } else {
                    checks.put(check("vpn_other", "ok"))
                }
                if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) && Build.VERSION.SDK_INT >= 31) {
                    val wi = caps.transportInfo as? WifiInfo
                    if (wi != null) {
                        val open = wi.currentSecurityType == WifiInfo.SECURITY_TYPE_OPEN
                        checks.put(check("wifi", if (open) "bad" else "ok", "", "wifi"))
                    }
                }
            }
        } catch (e: Exception) {
        }

        // Sort apps by risk.
        val sorted = (0 until apps.length()).map { apps.getJSONObject(it) }.sortedByDescending { it.optInt("score") }
        return JSONObject()
            .put("checks", checks)
            .put("apps", JSONArray(sorted))
            .put("scanned", scanned)
            .put("harmful", JSONArray(harmful.toList()))
    }

    private fun isRooted(): Boolean {
        if (Build.TAGS?.contains("test-keys") == true) return true
        val paths = listOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su", "/system/app/Superuser.apk", "/data/local/xbin/su",
            "/data/local/bin/su", "/system/sd/xbin/su", "/data/adb/magisk", "/system/bin/.ext/su"
        )
        return paths.any { File(it).exists() }
    }

    /** Opens the Android settings page that fixes a problem. */
    fun fixIntent(action: String): Intent? {
        val i = when (action) {
            "set_new_password" -> Intent(DevicePolicyManager.ACTION_SET_NEW_PASSWORD)
            "security_settings" -> Intent(Settings.ACTION_SECURITY_SETTINGS)
            "system_update" -> Intent("android.settings.SYSTEM_UPDATE_SETTINGS")
            "developer" -> Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
            "accessibility" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            "device_admin" -> Intent().setClassName("com.android.settings", "com.android.settings.DeviceAdminSettings")
            "notification_listeners" -> Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            "keyboard" -> Intent(Settings.ACTION_INPUT_METHOD_SETTINGS)
            "unknown_sources" -> Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
            "play_protect" -> Intent("com.google.android.gms.settings.VERIFY_APPS_SETTINGS")
            "vpn_settings" -> Intent(Settings.ACTION_VPN_SETTINGS)
            "wifi" -> Intent(Settings.ACTION_WIFI_SETTINGS)
            "default_apps" -> Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
            else -> null
        } ?: return null
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return if (i.resolveActivity(pm) != null) i else Intent(Settings.ACTION_SECURITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
}
