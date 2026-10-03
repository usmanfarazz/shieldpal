package app.shieldpal.shieldpal

import java.net.URI
import java.util.Locale

/**
 * Kotlin twin of the Dart UrlAnalyzer / ScamEngine rules. It runs inside the
 * background notification service, where the Flutter engine is not running,
 * so threats are caught even when ShieldPal is closed.
 */
object ScamHeuristics {

    private val urlRegex = Regex(
        """((?:https?://|www\.)[^\s<>"'()]+|\b[a-z0-9][a-z0-9-]{1,62}(?:\.[a-z0-9-]{2,63})*\.(?:com|net|org|xyz|top|site|online|club|live|info|link|click|shop|store|app|io|me|ly|gl|cc|tk|ml|ga|cf|gq|pk|in|co|ru|cn|icu|buzz|rest|cfd|sbs|vip|win|bid|loan|work|fun|space|website|pw|su)(?:/[^\s<>"'()]*)?)""",
        RegexOption.IGNORE_CASE
    )

    private val brands: Map<String, List<String>> = mapOf(
        "garena" to listOf("garena.com"), "freefire" to listOf("garena.com"),
        "pubg" to listOf("pubgmobile.com", "pubg.com", "midasbuy.com"), "midasbuy" to listOf("midasbuy.com"),
        "roblox" to listOf("roblox.com"), "robux" to listOf("roblox.com"),
        "fortnite" to listOf("fortnite.com", "epicgames.com"), "steam" to listOf("steampowered.com", "steamcommunity.com"),
        "tiktok" to listOf("tiktok.com"), "instagram" to listOf("instagram.com"),
        "facebook" to listOf("facebook.com", "fb.com", "fb.me"), "whatsapp" to listOf("whatsapp.com", "wa.me", "whatsapp.net"),
        "telegram" to listOf("telegram.org", "t.me"), "google" to listOf("google.com", "goo.gl", "google.com.pk"),
        "gmail" to listOf("google.com", "gmail.com"), "youtube" to listOf("youtube.com", "youtu.be"),
        "microsoft" to listOf("microsoft.com", "live.com", "office.com"), "apple" to listOf("apple.com", "icloud.com"),
        "icloud" to listOf("icloud.com", "apple.com"), "netflix" to listOf("netflix.com"),
        "amazon" to listOf("amazon.com", "amazon.in", "amazon.ae"), "paypal" to listOf("paypal.com"),
        "binance" to listOf("binance.com"), "easypaisa" to listOf("easypaisa.com.pk"),
        "jazzcash" to listOf("jazzcash.com.pk"), "telenor" to listOf("telenor.com.pk", "telenor.com"),
        "meezan" to listOf("meezanbank.com"), "bisp" to listOf("bisp.gov.pk"), "ehsaas" to listOf("pass.gov.pk", "bisp.gov.pk"),
        "nadra" to listOf("nadra.gov.pk"), "paytm" to listOf("paytm.com"), "phonepe" to listOf("phonepe.com"),
        "fedex" to listOf("fedex.com"), "daraz" to listOf("daraz.pk"), "aliexpress" to listOf("aliexpress.com"),
    )

    private val riskyTlds = setOf(
        "xyz", "top", "tk", "ml", "ga", "cf", "gq", "icu", "buzz", "rest", "cfd", "sbs", "click", "link", "live",
        "online", "site", "club", "vip", "win", "bid", "loan", "work", "fun", "space", "website", "pw", "su",
        "monster", "cyou", "quest", "bar", "zip", "mov"
    )

    private val shorteners = setOf(
        "bit.ly", "tinyurl.com", "t.co", "goo.gl", "is.gd", "cutt.ly", "rb.gy", "ow.ly", "shorturl.at", "tiny.cc",
        "rebrand.ly", "v.gd", "s.id", "t.ly", "surl.li"
    )

    private val trusted = setOf(
        "google.com", "youtube.com", "youtu.be", "wikipedia.org", "facebook.com", "instagram.com", "whatsapp.com",
        "wa.me", "microsoft.com", "apple.com", "amazon.com", "github.com", "linkedin.com", "x.com", "twitter.com",
        "reddit.com", "tiktok.com", "netflix.com", "garena.com", "roblox.com", "daraz.pk", "paypal.com",
        "telegram.org", "t.me", "zoom.us", "spotify.com", "dawn.com", "bbc.com"
    )

    private val baitWords = listOf(
        "free", "diamond", "diamonds", "robux", "skin", "gift", "giveaway", "reward", "prize", "winner", "bonus",
        "claim", "verify", "login", "signin", "account", "secure", "update", "unlock", "suspend", "blocked",
        "confirm", "wallet", "airdrop", "otp", "kyc", "refund", "inaam", "lucky", "hack", "generator", "unlimited"
    )

    fun extractUrls(text: String): List<String> =
        urlRegex.findAll(text).map { it.value.trimEnd('.', ',', '!', '?', ';', ':') }
            .filter { !(it.contains("@") && !it.contains("/")) }
            .distinct().toList()

    private fun hostIs(host: String, domain: String) = host == domain || host.endsWith(".$domain")

    private fun brandsIn(host: String): List<String> {
        val compact = host.replace(Regex("[.\\-_]"), "")
        return brands.keys.filter { compact.contains(it) }.sortedByDescending { it.length }
    }

    fun hostOf(raw: String): String? = try {
        val s = if (Regex("^[a-z][a-z0-9+.-]*://", RegexOption.IGNORE_CASE).containsMatchIn(raw)) raw else "http://$raw"
        URI(s).host?.lowercase(Locale.ROOT)
    } catch (e: Exception) {
        null
    }

    /** 0..100 risk for a link. */
    fun scoreUrl(raw: String): Int {
        val host = hostOf(raw) ?: return 30
        val lower = raw.lowercase(Locale.ROOT)
        var score = 0
        if (Regex("^\\d{1,3}(\\.\\d{1,3}){3}$").matches(host)) score += 35
        if (host.contains("xn--")) score += 40
        if (Regex("^[a-z]+://[^/]*@", RegexOption.IGNORE_CASE).containsMatchIn(raw)) score += 45
        if (lower.startsWith("http://")) score += 10
        if (riskyTlds.contains(host.substringAfterLast('.'))) score += 20
        val matched = brandsIn(host)
        if (matched.isNotEmpty() && matched.none { b -> brands[b]!!.any { hostIs(host, it) } }) score += 50
        if (matched.isEmpty()) {
            val deDigit = host.replace('0', 'o').replace('1', 'l').replace('3', 'e').replace('5', 's')
            if (deDigit != host && brandsIn(deDigit).isNotEmpty()) score += 50
        }
        if (shorteners.contains(host)) score += 15
        if (host.count { it == '.' } >= 4) score += 15
        val hits = baitWords.count { Regex("(^|[^a-z])$it([^a-z]|$)").containsMatchIn(lower) }
        if (hits > 0) score += (hits * 8).coerceIn(8, 30)
        if (Regex("\\.(apk|exe|scr|bat|msi|xapk|apks|jar)(\\?|$)").containsMatchIn(lower)) score += 40
        val isTrusted = trusted.any { hostIs(host, it) } || host.endsWith(".gov.pk") || host.endsWith(".gov")
        if (isTrusted && score <= 18) score = 0
        return score.coerceIn(0, 100)
    }

    private val groups: Map<String, Pair<Int, List<String>>> = mapOf(
        "otp" to (18 to listOf("otp", "login code", "the code", "woh code", "pin", "cvv", "password", "verification code",
            "کوڈ", "او ٹی پی", "ओटीपी", "رمز", "código", "kode", "şifre", "senha", "contraseña")),
        "urgent" to (12 to listOf("urgent", "immediately", "today", "within 24 hours", "expire", "last chance", "foran",
            "abhi", "jaldi", "aaj raat", "turant", "فوراً", "جلدی", "तुरंत", "عاجل", "urgente", "segera", "hemen")),
        "threat" to (14 to listOf("blocked", "suspended", "deleted", "banned", "locked", "disabled", "arrest", "block",
            "band ho", "band kar", "giraftari", "police", "بند", "बंद", "إيقاف", "bloqueada", "diblokir", "askıya")),
        "prize" to (14 to listOf("won", "winner", "prize", "lottery", "congratulations", "lucky", "reward", "free gift",
            "giveaway", "inaam", "mubarak ho", "jeeto", "انعام", "इनाम", "लॉटरी", "مبروك", "premio", "hadiah", "diamonds", "robux")),
        "money" to (14 to listOf("send money", "transfer", "fee", "deposit", "pay", "payment", "paise bhejo", "paise bhej",
            "raqam", "jama karwa", "bitcoin", "usdt", "پیسے بھیج", "رقم", "पैसे भेज", "फीस")),
        "creds" to (18 to listOf("login", "sign in", "verify your account", "confirm your identity", "enter your password",
            "cnic", "card number", "bank details", "id aur password", "شناختی کارڈ")),
        "imp" to (12 to listOf("bank se", "from bank", "customer care", "support team", "official", "fia", "pta", "bisp",
            "garena", "mera naya number", "my new number", "main musibat", "in trouble", "kisi ko mat batana",
            "do not tell anyone", "کسی کو مت بتانا")),
        "codeback" to (30 to listOf("by mistake", "galti se", "send it back", "wapas bhej", "mujhe bhej dein")),
    )

    private val safeOtp = Regex(
        "(do not share|don't share|never share|share na karein|kisi ko na batayein|کسی کو نہ بتائیں|किसी के साथ साझा न करें|لا تشارك)",
        RegexOption.IGNORE_CASE
    )

    private fun hasWord(hay: String, k: String): Boolean =
        if (Regex("^[a-z0-9 ]+$").matches(k)) Regex("(^|[^a-z0-9])${Regex.escape(k)}([^a-z0-9]|$)").containsMatchIn(hay)
        else hay.contains(k)

    /** 0..100 risk for a message text (without the link part). */
    fun scoreText(text: String): Int {
        val lower = text.lowercase(Locale.ROOT)
        var score = 0
        var groupsHit = 0
        val isSafeOtp = safeOtp.containsMatchIn(text)
        for ((name, pair) in groups) {
            if (name == "otp" && isSafeOtp) continue
            if (pair.second.any { hasWord(lower, it) }) {
                score += pair.first
                groupsHit++
            }
        }
        // Several different tricks together are much stronger evidence.
        if (groupsHit >= 3) score += 15
        if (isSafeOtp) score = score.coerceAtMost(20)
        return score.coerceIn(0, 100)
    }
}
